import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/hub_info.dart';
import '../utils/logger.dart';
import 'connection_manager.dart';
import 'discovery_service.dart';
import 'storage_service.dart';

/// AutoConnect service that handles automatic reconnection
/// Triggers:
/// - OnInit: Try auto-connect on app launch
/// - OnResume: Try auto-connect when app comes to foreground
/// - ConnectivityChanged: Try auto-connect when WiFi connects
class AutoConnectService {
  AutoConnectService._();
  static final AutoConnectService instance = AutoConnectService._();

  // Services
  final _connectionManager = ConnectionManager.instance;
  final _discoveryService = DiscoveryService.instance;
  final _storageService = StorageService.instance;

  // Connectivity monitoring
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // State
  bool _isInitialized = false;
  bool _isAutoConnecting = false;
  DateTime? _lastAutoConnectAttempt;
  static const _minAutoConnectInterval = Duration(seconds: 5);

  // Stream controllers
  final _autoConnectStatusController =
      StreamController<AutoConnectStatus>.broadcast();

  // Getters
  Stream<AutoConnectStatus> get statusStream =>
      _autoConnectStatusController.stream;
  bool get isAutoConnecting => _isAutoConnecting;

  /// Initialize auto-connect service
  Future<void> initialize() async {
    if (_isInitialized) return;

    AppLogger.info('Initializing AutoConnectService');

    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    _isInitialized = true;
    AppLogger.info('AutoConnectService initialized');
  }

  /// Try auto-connect (called on app launch/resume)
  Future<bool> tryAutoConnect({AutoConnectTrigger? trigger}) async {
    trigger ??= AutoConnectTrigger.manual;
    AppLogger.info('tryAutoConnect triggered: ${trigger.name}');

    // Rate limit auto-connect attempts
    if (_lastAutoConnectAttempt != null) {
      final elapsed = DateTime.now().difference(_lastAutoConnectAttempt!);
      if (elapsed < _minAutoConnectInterval) {
        AppLogger.info(
          'Skipping auto-connect: too soon (${elapsed.inSeconds}s < ${_minAutoConnectInterval.inSeconds}s)',
        );
        return false;
      }
    }

    // Skip if already connecting or connected
    if (_isAutoConnecting) {
      AppLogger.info('Skipping auto-connect: already in progress');
      return false;
    }

    if (_connectionManager.isConnected) {
      AppLogger.info('Skipping auto-connect: already connected');
      return true;
    }

    // Check if we have a saved hub
    final savedHub = _storageService.getHubInfo();
    if (savedHub == null) {
      AppLogger.info('No saved hub found, skipping auto-connect');
      return false;
    }

    // Check if auto-connect is enabled
    if (!_storageService.autoConnect) {
      AppLogger.info('Auto-connect is disabled in settings');
      return false;
    }

    _isAutoConnecting = true;
    _lastAutoConnectAttempt = DateTime.now();
    _autoConnectStatusController.add(
      AutoConnectStatus(
        status: AutoConnectState.connecting,
        trigger: trigger,
        message: 'Connecting to ${savedHub.name}...',
      ),
    );

    try {
      // 1. Try direct connection first (fastest)
      AppLogger.info(
        'Step 1: Trying direct connection to ${savedHub.endpoint}',
      );
      if (await _connectionManager.connect(savedHub)) {
        _autoConnectStatusController.add(
          AutoConnectStatus(
            status: AutoConnectState.connected,
            trigger: trigger,
            message: 'Connected to ${savedHub.name}',
          ),
        );
        _isAutoConnecting = false;
        return true;
      }

      // 2. If direct fails, try mDNS discovery
      AppLogger.info(
        'Step 2: Direct connection failed, starting discovery for server_id: ${savedHub.id}',
      );
      _autoConnectStatusController.add(
        AutoConnectStatus(
          status: AutoConnectState.discovering,
          trigger: trigger,
          message: 'Searching for ${savedHub.name} on network...',
        ),
      );

      await _discoveryService.startDiscovery();

      // Wait for matching hub (timeout after 5 seconds)
      HubInfo? discoveredHub;
      try {
        discoveredHub = await _discoveryService.hubsStream
            .expand((hubs) => hubs)
            .firstWhere((hub) => hub.id == savedHub.id)
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        AppLogger.info('Discovery timeout: hub not found on network');
      }

      await _discoveryService.stopDiscovery();

      if (discoveredHub != null) {
        AppLogger.info(
          'Step 3: Found hub via discovery: ${discoveredHub.endpoint}',
        );

        // Update hub with new endpoint (IP might have changed)
        final updatedHub = savedHub.copyWith(
          endpoint: discoveredHub.endpoint,
          ip: discoveredHub.ip,
          port: discoveredHub.port,
        );

        if (await _connectionManager.connect(updatedHub)) {
          // Save updated hub info
          await _storageService.saveHubInfo(updatedHub);
          _autoConnectStatusController.add(
            AutoConnectStatus(
              status: AutoConnectState.connected,
              trigger: trigger,
              message: 'Connected to ${savedHub.name}',
            ),
          );
          _isAutoConnecting = false;
          return true;
        }
      }

      // Connection failed
      _autoConnectStatusController.add(
        AutoConnectStatus(
          status: AutoConnectState.failed,
          trigger: trigger,
          message: 'Could not connect to ${savedHub.name}',
        ),
      );
      _isAutoConnecting = false;
      return false;
    } catch (e) {
      AppLogger.error('Auto-connect error', error: e);
      _autoConnectStatusController.add(
        AutoConnectStatus(
          status: AutoConnectState.failed,
          trigger: trigger,
          message: 'Connection failed: ${e.toString()}',
        ),
      );
      _isAutoConnecting = false;
      return false;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    AppLogger.info('Connectivity changed: $results');

    // Check if we now have WiFi connectivity
    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasEthernet = results.contains(ConnectivityResult.ethernet);

    if (hasWifi || hasEthernet) {
      AppLogger.info('WiFi/Ethernet connected, triggering auto-connect');
      // Delay slightly to allow network to stabilize
      Future.delayed(const Duration(seconds: 1), () {
        tryAutoConnect(trigger: AutoConnectTrigger.connectivityChanged);
      });
    }
  }

  /// Called when app resumes from background
  Future<void> onAppResume() async {
    AppLogger.info('App resumed, checking connection');
    await tryAutoConnect(trigger: AutoConnectTrigger.appResume);
  }

  /// Called on app launch
  Future<void> onAppLaunch() async {
    AppLogger.info('App launched, checking connection');
    await tryAutoConnect(trigger: AutoConnectTrigger.appLaunch);
  }

  /// Check current network connectivity
  Future<bool> hasNetworkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet) ||
        result.contains(ConnectivityResult.mobile);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoConnectStatusController.close();
  }
}

/// Trigger types for auto-connect
enum AutoConnectTrigger { appLaunch, appResume, connectivityChanged, manual }

/// Auto-connect states
enum AutoConnectState { idle, connecting, discovering, connected, failed }

/// Auto-connect status model
class AutoConnectStatus {
  final AutoConnectState status;
  final AutoConnectTrigger trigger;
  final String message;

  AutoConnectStatus({
    required this.status,
    required this.trigger,
    required this.message,
  });
}
