import 'package:flutter/material.dart';

import '../../../../core/constants/connection_state.dart' as app;
import '../../../../core/theme/app_colors.dart';

/// Connection status card widget showing hub connection state
class ConnectionStatusCard extends StatefulWidget {
  final app.ConnectionState connectionState;
  final String? hubName;
  final VoidCallback? onTap;
  final String? statusMessage;

  const ConnectionStatusCard({
    super.key,
    required this.connectionState,
    this.hubName,
    this.onTap,
    this.statusMessage,
  });

  @override
  State<ConnectionStatusCard> createState() => _ConnectionStatusCardState();
}

class _ConnectionStatusCardState extends State<ConnectionStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ConnectionStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.connectionState.isLoading) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: widget.connectionState.isActive ? 4 : 2,
      shadowColor: _statusColor.withAlpha(100),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: widget.connectionState.isActive
            ? BorderSide(color: _statusColor.withAlpha(100), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Status indicator with pulse animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: widget.connectionState.isLoading
                        ? _pulseAnimation.value
                        : 1.0,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor.withAlpha(51),
                        boxShadow: widget.connectionState.isActive
                            ? [
                                BoxShadow(
                                  color: _statusColor.withAlpha(80),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: widget.connectionState.isLoading
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
                  );
                },
              ),
              const SizedBox(width: 16),

              // Status text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                    if (widget.hubName != null &&
                        widget.connectionState.isActive) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.desktop_windows,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(128),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.hubName!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(178),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.statusMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(128),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (_showHint) ...[
                      const SizedBox(height: 4),
                      Text(
                        _hintText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(128),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action icon
              Icon(
                widget.connectionState.isActive
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
    switch (widget.connectionState) {
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
    switch (widget.connectionState) {
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

  String get _displayName {
    switch (widget.connectionState) {
      case app.ConnectionState.connected:
        return 'Connected';
      case app.ConnectionState.discovering:
        return 'Searching...';
      case app.ConnectionState.connecting:
        return 'Connecting...';
      case app.ConnectionState.authenticating:
        return 'Authenticating...';
      case app.ConnectionState.disconnected:
        return 'Offline';
      case app.ConnectionState.paused:
        return 'Paused';
      case app.ConnectionState.error:
        return 'Connection Error';
    }
  }

  bool get _showHint {
    return widget.connectionState == app.ConnectionState.disconnected ||
        widget.connectionState == app.ConnectionState.error;
  }

  String get _hintText {
    if (widget.connectionState == app.ConnectionState.error) {
      return 'Tap to retry or scan QR code';
    }
    return 'Tap to scan QR code to connect';
  }
}
