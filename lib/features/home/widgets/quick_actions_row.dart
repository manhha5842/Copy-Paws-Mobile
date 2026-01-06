import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Quick action buttons row for common operations
class QuickActionsRow extends StatelessWidget {
  final VoidCallback onScanQR;
  final VoidCallback onManualConnect;
  final bool isConnected;

  const QuickActionsRow({
    super.key,
    required this.onScanQR,
    required this.onManualConnect,
    this.isConnected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.qr_code_scanner,
            label: 'Scan QR',
            onTap: onScanQR,
            isHighlighted: !isConnected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.edit,
            label: 'Manual',
            onTap: onManualConnect,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isHighlighted ? AppColors.primary.withAlpha(38) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isHighlighted ? AppColors.primary : null,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isHighlighted ? AppColors.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
