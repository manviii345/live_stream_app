import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/janus_config.dart';

/// Full-screen QR code scanner shown as a modal bottom sheet.
/// Pops with a [JanusConfig] on a successful scan, or null if cancelled.
class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({super.key});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final config = JanusConfig.fromQrJson(json);
      _scanned = true;
      Navigator.of(context).pop(config);
    } catch (_) {
      setState(() => _error = 'Invalid QR code. Expected Janus credentials.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Scanner
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),
                  // Viewfinder overlay
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.orange, width: 2.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Corner accents
                          ..._corners(),
                        ],
                      ),
                    ),
                  ),
                  // Error banner
                  if (_error != null)
                    Positioned(
                      bottom: 32,
                      left: 24,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.liveRed.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _error = null;
                                _scanned = false;
                              }),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Hint text
                  Positioned(
                    bottom: _error != null ? 96 : 32,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Point your camera at the Janus QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds four orange corner tick marks inside the viewfinder box.
  List<Widget> _corners() {
    const len = 22.0;
    const thick = 3.0;
    const c = AppColors.orange;
    return [
      // Top-left
      Positioned(
          top: 0,
          left: 0,
          child: _cornerWidget(top: true, left: true, len: len, thick: thick, color: c)),
      // Top-right
      Positioned(
          top: 0,
          right: 0,
          child: _cornerWidget(top: true, left: false, len: len, thick: thick, color: c)),
      // Bottom-left
      Positioned(
          bottom: 0,
          left: 0,
          child: _cornerWidget(top: false, left: true, len: len, thick: thick, color: c)),
      // Bottom-right
      Positioned(
          bottom: 0,
          right: 0,
          child: _cornerWidget(top: false, left: false, len: len, thick: thick, color: c)),
    ];
  }

  Widget _cornerWidget({
    required bool top,
    required bool left,
    required double len,
    required double thick,
    required Color color,
  }) {
    return SizedBox(
      width: len,
      height: len,
      child: CustomPaint(
        painter: _CornerPainter(
            top: top, left: left, thick: thick, color: color),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool top;
  final bool left;
  final double thick;
  final Color color;

  _CornerPainter(
      {required this.top,
      required this.left,
      required this.thick,
      required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final x = left ? 0.0 : size.width;
    final y = top ? 0.0 : size.height;
    final dx = left ? size.width : -size.width;
    final dy = top ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
