import 'package:flutter/material.dart';

import '../../../../core/constants/connection_state.dart' as app;
import '../../../../core/theme/app_colors.dart';

/// Connection status card widget showing hub connection state
class ConnectionStatusCard extends StatelessWidget {
  final app.ConnectionState connectionState;
  final String? hubName;
  final VoidCallback? onTap;

  const ConnectionStatusCard({
    super.key,
    required this.connectionState,
    this.hubName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _statusColor.withAlpha(51),
                ),
                child: Center(
                  child: connectionState.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _statusColor,
                          ),
                        )
                      : Icon(_statusIcon, color: _statusColor, size: 24),
                ),
              ),
              const SizedBox(width: 16),

              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connectionState.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                    if (hubName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        hubName!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(178),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action icon
              Icon(
                connectionState.isActive
                    ? Icons.link_off
                    : Icons.qr_code_scanner,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (connectionState) {
      case app.ConnectionState.connected:
        return AppColors.connected;
      case app.ConnectionState.discovering:
      case app.ConnectionState.connecting:
      case app.ConnectionState.authenticating:
        return AppColors.connecting;
      case app.ConnectionState.disconnected:
      case app.ConnectionState.paused:
        return AppColors.darkTextSecondary;
      case app.ConnectionState.error:
        return AppColors.disconnected;
    }
  }

  IconData get _statusIcon {
    switch (connectionState) {
      case app.ConnectionState.connected:
        return Icons.check_circle;
      case app.ConnectionState.disconnected:
        return Icons.cloud_off;
      case app.ConnectionState.paused:
        return Icons.pause_circle;
      case app.ConnectionState.error:
        return Icons.error;
      default:
        return Icons.sync;
    }
  }
}
