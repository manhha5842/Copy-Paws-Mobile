import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/connection_state.dart';
import '../../../../core/services/background_permission_service.dart';
import '../../../../core/services/background_service.dart';
import '../../../../core/services/connection_manager.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/helpers.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final _connectionManager = ConnectionManager.instance;
  final _backgroundPermissionService = BackgroundPermissionService.instance;
  final _notificationService = NotificationService.instance;
  final _storageService = StorageService.instance;

  bool _notificationsEnabled = true;
  bool _autoConnect = true;
  bool _syncEnabled = true;
  bool _autoCopyIncomingForeground = false;
  bool _backgroundServiceRunning = false;
  bool _notificationPermissionGranted = true;
  bool _batteryOptimizationIgnored = true;
  bool _showPreview = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBackgroundStatus();
    }
  }

  Future<void> _loadSettings() async {
    _notificationsEnabled = _storageService.notificationsEnabled;
    _autoConnect = _storageService.autoConnect;
    _syncEnabled = _storageService.syncEnabled;
    _autoCopyIncomingForeground = _storageService.autoCopyIncomingForeground;
    _showPreview = _storageService.showPreview;

    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';

    await _notificationService.initialize();
    await _refreshBackgroundStatus();

    if (mounted) setState(() {});
  }

  Future<void> _refreshBackgroundStatus() async {
    if (!Helpers.isAndroid) {
      if (!mounted) return;

      setState(() {
        _backgroundServiceRunning = false;
        _notificationPermissionGranted = true;
        _batteryOptimizationIgnored = true;
      });
      return;
    }

    final serviceRunning = await BackgroundService.isRunning();
    final notificationGranted = await _notificationService.hasPermission();
    final batteryOptimizationIgnored = await _backgroundPermissionService
        .isIgnoringBatteryOptimizations();

    if (!mounted) return;

    setState(() {
      _backgroundServiceRunning = serviceRunning;
      _notificationPermissionGranted = notificationGranted;
      _batteryOptimizationIgnored = batteryOptimizationIgnored;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = _connectionManager.currentHub;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Connection'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.link,
              title: 'Connected Hub',
              subtitle: hub?.name ?? 'Not connected',
              trailing: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: () => Navigator.pushNamed(context, '/scan'),
              ),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.autorenew,
              title: 'Auto Connect',
              subtitle: 'Automatically connect to last hub',
              trailing: Switch(
                value: _autoConnect,
                onChanged: (value) async {
                  await _storageService.setAutoConnect(value);
                  if (mounted) setState(() => _autoConnect = value);
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.sync,
              title: 'Sync Enabled',
              subtitle: 'Enable clipboard synchronization',
              trailing: Switch(
                value: _syncEnabled,
                onChanged: (value) async {
                  await _storageService.setSyncEnabled(value);
                  if (mounted) setState(() => _syncEnabled = value);
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          _buildSectionHeader('Notifications'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Notify when new clips arrive',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: _toggleNotifications,
              ),
            ),
          ]),

          const SizedBox(height: 24),

          if (Helpers.isAndroid) ...[
            _buildSectionHeader('Background'),
            _buildSettingsCard([
              _SettingsTile(
                icon: Icons.memory,
                title: 'Background Service',
                subtitle: _backgroundServiceRunning
                    ? 'Running. Sync can keep listening after you leave the app'
                    : 'Not running. Start it once to keep sync alive',
                trailing: _backgroundServiceRunning
                    ? Icon(Icons.check_circle, color: AppColors.success)
                    : TextButton(
                        onPressed: _ensureBackgroundServiceRunning,
                        child: const Text('Start'),
                      ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.notifications_active,
                title: 'Notification Permission',
                subtitle: _notificationPermissionGranted
                    ? 'Granted. Android can show foreground-service notifications'
                    : 'Required on Android 13+ so the background service can stay visible',
                trailing: _notificationPermissionGranted
                    ? Icon(Icons.check_circle, color: AppColors.success)
                    : TextButton(
                        onPressed: _requestNotificationPermission,
                        child: const Text('Allow'),
                      ),
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.battery_saver,
                title: 'Battery Optimization',
                subtitle: _batteryOptimizationIgnored
                    ? 'Disabled for CopyPaws. Android is less likely to kill sync'
                    : 'Turn this off so silent copy and socket sync survive in background',
                trailing: _batteryOptimizationIgnored
                    ? Icon(Icons.check_circle, color: AppColors.success)
                    : TextButton(
                        onPressed: _requestBatteryOptimizationExemption,
                        child: const Text('Allow'),
                      ),
              ),
              const Divider(height: 1),
              const _SettingsTile(
                icon: Icons.info_outline,
                title: 'OEM Note',
                subtitle:
                    'Some phones still need manual Auto-start permission in system settings',
              ),
            ]),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader('Privacy'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.visibility,
              title: 'Show Preview',
              subtitle: 'Show clip content in notifications',
              trailing: Switch(
                value: _showPreview,
                onChanged: (value) async {
                  await _storageService.setShowPreview(value);
                  if (mounted) setState(() => _showPreview = value);
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.content_paste,
              title: 'Silent Copy Incoming',
              subtitle: 'Best effort on Android, even while using another app',
              trailing: Switch(
                value: _autoCopyIncomingForeground,
                onChanged: (value) async {
                  await _storageService.setAutoCopyIncomingForeground(value);
                  if (mounted) {
                    setState(() => _autoCopyIncomingForeground = value);
                  }
                },
              ),
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.delete_sweep,
              title: 'Clear History',
              subtitle: 'Delete all local clipboard history',
              onTap: _showClearHistoryDialog,
            ),
            if (_connectionManager.isPaired) ...[
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.link_off,
                title: 'Unpair Device',
                subtitle: 'Remove connection to desktop hub',
                onTap: _showUnpairDialog,
                textColor: AppColors.error,
              ),
            ],
          ]),

          const SizedBox(height: 24),

          _buildSectionHeader('About'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.info,
              title: 'Version',
              subtitle: _appVersion.isNotEmpty ? _appVersion : 'Loading...',
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.code,
              title: 'Open Source Licenses',
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'CopyPaws',
                  applicationVersion: _appVersion,
                );
              },
            ),
            const Divider(height: 1),
            _SettingsTile(
              icon: Icons.bug_report,
              title: 'Debug Info',
              onTap: _showDebugInfo,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Card(child: Column(children: children));
  }

  Future<void> _toggleNotifications(bool value) async {
    var nextValue = value;

    if (value) {
      nextValue = await _notificationService.requestPermission();
      if (!nextValue && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification permission not granted'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
    }

    await _storageService.setNotificationsEnabled(nextValue);
    await _refreshBackgroundStatus();

    if (mounted) setState(() => _notificationsEnabled = nextValue);
  }

  Future<void> _ensureBackgroundServiceRunning() async {
    final started = await BackgroundService.ensureRunning();
    await _refreshBackgroundStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? 'Background service is running'
              : 'Could not start background service',
        ),
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await _notificationService.requestPermission();
    await _refreshBackgroundStatus();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? 'Notification permission granted'
              : 'Please allow notifications in Android settings',
        ),
        action: granted
            ? null
            : SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
      ),
    );
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    final launched = await _backgroundPermissionService
        .requestIgnoreBatteryOptimizations();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          launched
              ? 'Android settings opened. Allow CopyPaws to run without battery optimization'
              : 'Could not open battery optimization settings',
        ),
        action: launched
            ? SnackBarAction(
                label: 'More',
                onPressed: () {
                  _backgroundPermissionService
                      .openBatteryOptimizationSettings();
                },
              )
            : null,
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'This will delete all local clipboard history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storageService.clearClipHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showUnpairDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unpair Device'),
        content: const Text(
          'This will remove the connection to your desktop hub. You will need to scan QR code again to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _connectionManager.unpair();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device unpaired')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Unpair'),
          ),
        ],
      ),
    );
  }

  void _showDebugInfo() {
    final hub = _connectionManager.currentHub;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDebugRow('Device ID', _connectionManager.deviceId ?? 'N/A'),
            _buildDebugRow(
              'Device Name',
              _connectionManager.deviceName ?? 'N/A',
            ),
            _buildDebugRow('Hub Endpoint', hub?.endpoint ?? 'Not connected'),
            _buildDebugRow(
              'Connection State',
              _connectionManager.connectionState.displayName,
            ),
            _buildDebugRow('Is Paired', _connectionManager.isPaired.toString()),
            _buildDebugRow(
              'Background Service',
              _backgroundServiceRunning ? 'Running' : 'Stopped',
            ),
            _buildDebugRow(
              'Notifications',
              _notificationPermissionGranted ? 'Granted' : 'Not granted',
            ),
            _buildDebugRow(
              'Battery Optimization',
              _batteryOptimizationIgnored ? 'Ignored' : 'Active',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: textColor?.withAlpha(178) ?? Colors.grey.shade500,
              ),
            )
          : null,
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
