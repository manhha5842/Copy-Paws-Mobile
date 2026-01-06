import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/connection_state.dart' as app;
import '../../../../core/services/connection_manager.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Settings screen for app configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _connectionManager = ConnectionManager.instance;
  final _storageService = StorageService.instance;

  bool _notificationsEnabled = true;
  bool _autoConnect = true;
  bool _syncEnabled = true;
  bool _showPreview = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _notificationsEnabled = _storageService.notificationsEnabled;
    _autoConnect = _storageService.autoConnect;
    _syncEnabled = _storageService.syncEnabled;
    _showPreview = _storageService.showPreview;

    final packageInfo = await PackageInfo.fromPlatform();
    _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hub = _connectionManager.currentHub;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection section
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
                  setState(() => _autoConnect = value);
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
                  setState(() => _syncEnabled = value);
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Notifications section
          _buildSectionHeader('Notifications'),
          _buildSettingsCard([
            _SettingsTile(
              icon: Icons.notifications,
              title: 'Push Notifications',
              subtitle: 'Notify when new clips arrive',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) async {
                  await _storageService.setNotificationsEnabled(value);
                  setState(() => _notificationsEnabled = value);
                },
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // Privacy section
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
                  setState(() => _showPreview = value);
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

          // About section
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
