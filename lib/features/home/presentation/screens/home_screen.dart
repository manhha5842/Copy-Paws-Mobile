import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/connection_state.dart' as app;
import '../../../../core/models/clipboard_item.dart';
import '../../../../core/models/hub_info.dart';
import '../../../../core/services/connection_manager.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/widget_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/logger.dart';
import '../../widgets/connection_status_card.dart';
import '../../widgets/push_button.dart';
import '../../widgets/incoming_clips_list.dart';
import '../../widgets/quick_actions_row.dart';
import 'package:home_widget/home_widget.dart';

/// Home screen - main dashboard of the app
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Services
  final _connectionManager = ConnectionManager.instance;
  final _syncService = SyncService.instance;
  final _storageService = StorageService.instance;
  final _widgetService = WidgetService.instance;

  // State
  app.ConnectionState _connectionState = app.ConnectionState.disconnected;
  HubInfo? _connectedHub;
  List<ClipboardItem> _incomingClips = [];
  bool _isPushing = false;

  // Subscriptions
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _hubSubscription;
  StreamSubscription? _clipsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionStateSubscription?.cancel();
    _hubSubscription?.cancel();
    _clipsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect when app resumes
      if (!_connectionManager.isConnected && _connectedHub != null) {
        _connectionManager.autoConnect();
      }
      // Request latest clips
      if (_connectionManager.isConnected) {
        _syncService.requestLatest();
      }
    }
  }

  Future<void> _initialize() async {
    AppLogger.info('Initializing home screen');

    // Initialize services
    await _storageService.initialize();
    await _connectionManager.initialize();
    await _syncService.initialize();
    await _widgetService.initialize();

    // Register widget callback to handle deep link actions from Android
    await _widgetService.registerBackgroundCallback(_handleWidgetAction);

    // Get initial state
    _connectedHub = _connectionManager.currentHub;
    _connectionState = _connectionManager.connectionState;
    _incomingClips = _syncService.incomingClips;

    // Subscribe to streams
    _connectionStateSubscription = _connectionManager.connectionStateStream
        .listen((state) {
          if (mounted) {
            setState(() => _connectionState = state);
          }
        });

    _hubSubscription = _connectionManager.hubChangedStream.listen((hub) {
      if (mounted) {
        setState(() => _connectedHub = hub);
      }
    });

    _clipsSubscription = _syncService.incomingClipsStream.listen((clips) {
      if (mounted) {
        setState(() => _incomingClips = clips);
      }
    });

    // Auto-connect if hub is saved
    await _connectionManager.autoConnect();

    // Check if launched from widget
    final widgetLaunchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (widgetLaunchUri != null) {
      _handleWidgetAction(widgetLaunchUri);
    }

    // Listen for widget clicks while app is running
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetAction(uri);
      }
    });

    if (mounted) setState(() {});
  }

  void _handleWidgetAction(Uri? uri) {
    if (uri == null) return;

    AppLogger.info('Widget action received: $uri');

    final action = uri.host;

    switch (action) {
      case 'push':
        AppLogger.info('Widget: Handling push action');
        _handlePushToHub();
        break;
      case 'pull':
        AppLogger.info('Widget: Handling pull action');
        _handleRefresh();
        break;
      case 'open':
        AppLogger.info('Widget: Handling open action');
        // App is already opened by the deep link, just log it
        break;
      default:
        AppLogger.warning('Widget: Unknown action: $action');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CopyPaws'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
            tooltip: 'History',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Status Card
                ConnectionStatusCard(
                  connectionState: _connectionState,
                  hubName: _connectedHub?.name,
                  onTap: _handleConnectionTap,
                ),
                const SizedBox(height: 24),

                // Push to Hub Button
                PushButton(
                  isEnabled: _connectionState.isActive && !_isPushing,
                  isLoading: _isPushing,
                  onPressed: _handlePushToHub,
                ),
                const SizedBox(height: 24),

                // Quick Actions
                QuickActionsRow(
                  onScanQR: () async {
                    final result = await Navigator.pushNamed(context, '/scan');
                    if (result != null && result is HubInfo) {
                      setState(() => _connectedHub = result);
                    }
                  },
                  onManualConnect: _showManualConnectDialog,
                  isConnected: _connectionState.isActive,
                ),
                const SizedBox(height: 24),

                // Incoming Clips Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Incoming Clips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_incomingClips.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/history'),
                        child: const Text('See All'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Incoming clips list
                IncomingClipsList(
                  clips: _incomingClips.take(5).toList(),
                  onCopy: _handleCopyClip,
                  onDelete: _handleDeleteClip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    if (_connectionManager.isConnected) {
      await _syncService.requestLatest();
    } else if (_connectedHub != null) {
      await _connectionManager.reconnect();
    }
  }

  void _handleConnectionTap() {
    if (_connectionState.isActive) {
      _showDisconnectDialog();
    } else {
      Navigator.pushNamed(context, '/scan');
    }
  }

  Future<void> _handlePushToHub() async {
    setState(() => _isPushing = true);

    final success = await _syncService.pushClipboard();

    setState(() => _isPushing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Pushed to hub!' : 'Failed to push clipboard',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleCopyClip(String clipId) async {
    final clip = _incomingClips.firstWhere(
      (c) => c.id == clipId,
      orElse: () =>
          ClipboardItem(id: '', content: '', timestamp: DateTime.now()),
    );

    if (clip.content.isEmpty) return;

    final success = await _syncService.copyToClipboard(clip);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Copied to clipboard' : 'Failed to copy'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _handleDeleteClip(String clipId) {
    _syncService.deleteClip(clipId);
  }

  void _showManualConnectDialog() {
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '9876');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Connect'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9876',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Text(
              'Note: Manual connection requires the shared secret to be set up via QR code first.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ip = ipController.text.trim();
              final port = int.tryParse(portController.text.trim()) ?? 9876;

              if (ip.isEmpty) return;

              Navigator.pop(context);

              final hub = HubInfo(
                id: 'manual_${ip}_$port',
                name: 'Manual Hub ($ip)',
                endpoint: 'ws://$ip:$port',
                ip: ip,
                port: port,
              );

              final success = await _connectionManager.connect(hub);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Connected!' : 'Failed to connect'),
                    backgroundColor: success
                        ? AppColors.success
                        : AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from the hub?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _connectionManager.disconnect();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
