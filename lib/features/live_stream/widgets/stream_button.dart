import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class StreamButton extends StatelessWidget {
  final bool isConnected;
  final bool isStreaming;
  final VoidCallback onStartStreaming;
  final VoidCallback onStopStreaming;

  const StreamButton({
    super.key,
    required this.isConnected,
    required this.isStreaming,
    required this.onStartStreaming,
    required this.onStopStreaming,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = isConnected || isStreaming;
    final String label = isStreaming ? 'Stop Streaming' : 'Start Streaming';
    final Color bgColor = isStreaming
        ? AppColors.disconnectRed
        : enabled
            ? AppColors.orange
            : AppColors.orange.withValues(alpha: 0.4);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled
            ? (isStreaming ? onStopStreaming : onStartStreaming)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
