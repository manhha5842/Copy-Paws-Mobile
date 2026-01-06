import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Large push button for sending clipboard content to hub
class PushButton extends StatelessWidget {
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPressed;

  const PushButton({
    super.key,
    this.isEnabled = true,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final active = isEnabled && !isLoading;

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: active ? AppColors.primaryGradient : null,
        color: active ? null : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(20),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(102),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          child: Center(
            child: isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'PUSHING...',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_rounded,
                        size: 32,
                        color: active ? Colors.white : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PUSH TO HUB',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: active ? Colors.white : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
