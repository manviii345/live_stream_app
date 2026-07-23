import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/live_stream_provider.dart';

class ViewFinderWidget extends StatelessWidget {
  final RTCVideoRenderer? renderer;
  final StreamingPhase phase;
  final bool isFrontCamera;
  final bool isVideoMuted;
  final String? errorMessage;

  const ViewFinderWidget({
    super.key,
    required this.renderer,
    required this.phase,
    required this.isFrontCamera,
    required this.isVideoMuted,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardWhite(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44, color: AppColors.liveRed),
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.liveRed, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (phase == StreamingPhase.idle) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded, size: 48, color: AppColors.textGrey(context)),
            const SizedBox(height: 16),
            Text(
              'Disconnected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: AppColors.textDark(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Session has ended. Reconnect to start streaming.',
              style: TextStyle(color: AppColors.textGrey(context), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (isVideoMuted) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 40, color: AppColors.textGrey(context)),
            const SizedBox(height: 12),
            Text('Video paused', style: TextStyle(color: AppColors.textGrey(context))),
          ],
        ),
      );
    }

    if (phase == StreamingPhase.streaming && renderer != null) {
      return RTCVideoView(
        renderer!,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: isFrontCamera,
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_off_outlined, size: 48, color: AppColors.textGrey(context)),
          const SizedBox(height: 16),
          Text(
            'Connected',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textDark(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Press Start Streaming to begin',
            style: TextStyle(color: AppColors.textGrey(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
