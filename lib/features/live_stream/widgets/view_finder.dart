import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// The rounded white card that shows the live camera preview,
/// matching "(View Finder)" placeholder in the design.
class ViewFinderWidget extends StatelessWidget {
  final CameraController? controller;
  final bool isInitialized;
  final bool isVideoMuted;
  final String? errorMessage;

  const ViewFinderWidget({
    super.key,
    required this.controller,
    required this.isInitialized,
    required this.isVideoMuted,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Error state
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.liveRed, fontSize: 14),
          ),
        ),
      );
    }

    // Loading state — camera not ready yet
    if (!isInitialized || controller == null || !controller!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.orange),
            SizedBox(height: 16),
            Text(
              '(View Finder)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Initializing camera...',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Video muted — show placeholder instead of frozen frame
    if (isVideoMuted) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 40, color: AppColors.textGrey),
            SizedBox(height: 12),
            Text('Video paused', style: TextStyle(color: AppColors.textGrey)),
          ],
        ),
      );
    }

    // Live camera preview, full screen within the card.
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller!.value.previewSize?.height ?? 1,
        height: controller!.value.previewSize?.width ?? 1,
        child: CameraPreview(controller!),
      ),
    );
  }
}
