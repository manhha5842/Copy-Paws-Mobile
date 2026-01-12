import 'dart:async';

import 'package:bonsoir/bonsoir.dart';

import '../models/hub_info.dart';
import '../utils/logger.dart';

/// mDNS discovery service for finding desktop hubs on local network
class DiscoveryService {
  DiscoveryService._();
  static final DiscoveryService instance = DiscoveryService._();

  static const String serviceType = '_clipboardhub._tcp';

  // Bonsoir discovery instance
  BonsoirDiscovery? _discovery;
  StreamSubscription? _subscription;

  // Discovered hubs
  final List<HubInfo> _discoveredHubs = [];
  bool _isDiscovering = false;

  // Stream controller
  final _hubsController = StreamController<List<HubInfo>>.broadcast();

  // Getters
  List<HubInfo> get discoveredHubs => List.unmodifiable(_discoveredHubs);
  Stream<List<HubInfo>> get hubsStream => _hubsController.stream;
  bool get isDiscovering => _isDiscovering;

  /// Start mDNS discovery
  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      AppLogger.info('Discovery already in progress');
      return;
    }

    AppLogger.info('Starting mDNS discovery for $serviceType');
    _isDiscovering = true;
    _discoveredHubs.clear();
    _hubsController.add([]);

    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.initialize();

      _subscription = _discovery!.eventStream?.listen((event) {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          AppLogger.info('Service found: ${event.service.name}');
          // Need to resolve to get IP and port
          event.service.resolve(_discovery!.serviceResolver);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          AppLogger.info('Service resolved: ${event.service.name}');
          _addResolvedService(event.service);
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          AppLogger.info('Service lost: ${event.service.name}');
          _removeService(event.service);
        }
      });

      await _discovery!.start();
    } catch (e) {
      AppLogger.error('Failed to start discovery', error: e);
      _isDiscovering = false;
    }
  }

  void _addResolvedService(BonsoirService? service) {
    if (service == null) return;

    // In bonsoir 6.x, once a service is resolved, host and port are available.
    final ip = service.toJson()['host'] as String?;
    final port = service.toJson()['port'] as int?;
    final name = service.name;

    if (ip == null || ip.isEmpty) {
      AppLogger.warning('Resolved service has no IP');
      return;
    }

    // Parse TXT records
    final attributes = service.attributes;
    final serverId = attributes['server_id'];

    // Use server_id if available, otherwise fallback to constructed ID
    final hubId = serverId ?? '${name}_${ip}_$port';

    final hub = HubInfo(
      id: hubId,
      name: name,
      endpoint: 'ws://$ip:$port',
      ip: ip,
      port: port,
    );

    // Check if already exists
    final existingIndex = _discoveredHubs.indexWhere(
      (h) => h.endpoint == hub.endpoint,
    );
    if (existingIndex >= 0) {
      _discoveredHubs[existingIndex] = hub;
    } else {
      _discoveredHubs.add(hub);
    }

    _hubsController.add(List.from(_discoveredHubs));
    AppLogger.info('Hub discovered: ${hub.name} at ${hub.endpoint}');
  }

  void _removeService(BonsoirService? service) {
    if (service == null) return;

    _discoveredHubs.removeWhere((hub) => hub.name == service.name);
    _hubsController.add(List.from(_discoveredHubs));
    AppLogger.info('Hub removed: ${service.name}');
  }

  /// Stop mDNS discovery
  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    AppLogger.info('Stopping mDNS discovery');

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _discovery?.stop();
    } catch (e) {
      AppLogger.error('Error stopping discovery', error: e);
    }

    _discovery = null;
    _isDiscovering = false;
  }

  /// Manually add hub (for testing or manual input)
  void addHubManually(String ip, int port, {String? name}) {
    final hub = HubInfo(
      id: 'manual_${ip}_$port',
      name: name ?? 'Manual Hub ($ip)',
      endpoint: 'ws://$ip:$port',
      ip: ip,
      port: port,
    );

    if (!_discoveredHubs.any((h) => h.endpoint == hub.endpoint)) {
      _discoveredHubs.add(hub);
      _hubsController.add(List.from(_discoveredHubs));
      AppLogger.info('Hub added manually: ${hub.name}');
    }
  }

  /// Parse hub from QR code data
  HubInfo? parseQRCode(String qrData) {
    try {
      return HubInfo.fromQRData(qrData);
    } catch (e) {
      AppLogger.error('Failed to parse QR code', error: e);
      return null;
    }
  }

  /// Clear discovered hubs
  void clear() {
    _discoveredHubs.clear();
    _hubsController.add([]);
  }

  /// Dispose resources
  void dispose() {
    stopDiscovery();
    _hubsController.close();
  }
}
