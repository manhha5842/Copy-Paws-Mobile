import 'package:flutter/material.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/hub_info.dart';
import '../../../../core/services/connection_manager.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/logger.dart';

/// QR Code scanning screen for pairing with desktop hub
class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  String? _errorMessage;
  bool _hasScanned = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview area
          Expanded(flex: 3, child: _buildCameraPreview()),

          // Bottom info section
          Expanded(flex: 2, child: _buildBottomSection()),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(128), width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleQRDetected,
          ),

          // QR scan overlay
          CustomPaint(painter: _QROverlayPainter(), size: Size.infinite),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Instructions
          const Icon(Icons.qr_code_2, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Scan the QR code displayed on your desktop',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Open CopyPaws on your desktop and go to\nSettings → Show QR Code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.error),
                    onPressed: _resetScanner,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Manual input button
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Will trigger manual connect dialog in home screen
            },
            icon: const Icon(Icons.edit),
            label: const Text('Enter IP manually instead'),
          ),
        ],
      ),
    );
  }

  void _handleQRDetected(BarcodeCapture capture) async {
    if (_isProcessing || _hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final qrData = barcode.rawValue;

    if (qrData == null || qrData.isEmpty) return;

    AppLogger.info(
      'QR code detected: ${qrData.substring(0, qrData.length.clamp(0, 50))}...',
    );

    _hasScanned = true;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Parse QR data
      final hub = HubInfo.fromQRData(qrData);
      AppLogger.info('Parsed hub: ${hub.name} at ${hub.endpoint}');

      // Extract shared secret from QR data
      final uri = Uri.parse(qrData);
      final sharedSecret =
          uri.queryParameters['secret'] ?? uri.queryParameters['token'] ?? '';

      if (sharedSecret.isEmpty) {
        throw Exception('No shared secret in QR code');
      }

      // Save pairing token if present
      final pairingToken = uri.queryParameters['token'];
      if (pairingToken != null) {
        await StorageService.instance.savePairingToken(pairingToken);
      }

      // Pair with hub
      final success = await ConnectionManager.instance.pairWithHub(
        hub,
        sharedSecret,
      );

      if (success && mounted) {
        // Success - navigate back
        Navigator.pop(context, hub);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${hub.name}'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        throw Exception('Failed to connect to hub');
      }
    } catch (e) {
      AppLogger.error('QR processing failed', error: e);
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      _hasScanned = false;
    }
  }

  void _resetScanner() {
    setState(() {
      _hasScanned = false;
      _isProcessing = false;
      _errorMessage = null;
    });
  }
}

/// Custom painter for QR scanner overlay
class _QROverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 40.0;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final scanAreaSize = size.width * 0.7;
    final left = centerX - scanAreaSize / 2;
    final top = centerY - scanAreaSize / 2;
    final right = centerX + scanAreaSize / 2;
    final bottom = centerY + scanAreaSize / 2;

    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);

    // Top-right corner
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      paint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      paint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      paint,
    );

    // Semi-transparent overlay outside scan area
    final overlayPaint = Paint()
      ..color = Colors.black.withAlpha(128)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTRB(left, top, right, bottom))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
