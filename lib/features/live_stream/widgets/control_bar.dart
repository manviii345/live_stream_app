import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDisabled;
  final Color? activeColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDisabled = false,
    this.activeColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLabelColor = labelColor ?? AppColors.textGrey(context);
    final iconColor = isDisabled
        ? AppColors.textGrey(context).withValues(alpha: 0.35)
        : isActive
            ? (activeColor ?? AppColors.orange)
            : AppColors.textDark(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDisabled
                  ? AppColors.cardWhite(context).withValues(alpha: 0.5)
                  : AppColors.cardWhite(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDisabled
                    ? AppColors.border(context).withValues(alpha: 0.4)
                    : AppColors.border(context),
              ),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDisabled
                ? effectiveLabelColor.withValues(alpha: 0.35)
                : effectiveLabelColor,
          ),
        ),
      ],
    );
  }
}

class ControlBar extends StatelessWidget {
  final bool isStreaming;
  final bool isMicMuted;
  final bool isVideoMuted;
  final bool isTorchOn;
  final bool isTorchSupported;

  final VoidCallback onMicTap;
  final VoidCallback onVideoTap;
  final VoidCallback onFlipTap;
  final VoidCallback onTorchTap;
  final VoidCallback onDisconnectTap;

  const ControlBar({
    super.key,
    required this.isStreaming,
    required this.isMicMuted,
    required this.isVideoMuted,
    required this.isTorchOn,
    required this.isTorchSupported,
    required this.onMicTap,
    required this.onVideoTap,
    required this.onFlipTap,
    required this.onTorchTap,
    required this.onDisconnectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: isMicMuted ? Icons.mic_off : Icons.mic,
                    label: 'Mute mic',
                    isActive: isMicMuted,
                    isDisabled: !isStreaming,
                    onTap: onMicTap,
                  ),
                  _ControlButton(
                    icon: isVideoMuted ? Icons.videocam_off : Icons.videocam,
                    label: 'Mute video',
                    isActive: isVideoMuted,
                    isDisabled: !isStreaming,
                    onTap: onVideoTap,
                  ),
                  _ControlButton(
                    icon: Icons.cameraswitch,
                    label: 'Flip Cam',
                    isDisabled: !isStreaming,
                    onTap: onFlipTap,
                  ),
                  _ControlButton(
                    icon: isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                    label: 'Torch',
                    isActive: isTorchOn,
                    isDisabled: !isStreaming || !isTorchSupported,
                    onTap: onTorchTap,
                  ),
                  _ControlButton(
                    icon: Icons.cancel,
                    label: 'Disconnect',
                    isActive: true,
                    activeColor: AppColors.disconnectRed,
                    labelColor: AppColors.disconnectRed,
                    onTap: onDisconnectTap,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
