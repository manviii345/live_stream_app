import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One circular icon button + label, used in the bottom control row.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    this.labelColor = AppColors.textGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isActive ? (activeColor ?? AppColors.orange) : AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
      ],
    );
  }
}

/// Bottom row: Mute mic / Mute video / Flip cam / Torch / Disconnect.
class ControlBar extends StatelessWidget {
  final bool isMicMuted;
  final bool isVideoMuted;
  final bool isTorchOn;
  final VoidCallback onMicTap;
  final VoidCallback onVideoTap;
  final VoidCallback onFlipTap;
  final VoidCallback onTorchTap;
  final VoidCallback onDisconnectTap;

  const ControlBar({
    super.key,
    required this.isMicMuted,
    required this.isVideoMuted,
    required this.isTorchOn,
    required this.onMicTap,
    required this.onVideoTap,
    required this.onFlipTap,
    required this.onTorchTap,
    required this.onDisconnectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: isMicMuted ? Icons.mic_off : Icons.mic,
            label: 'Mute mic',
            isActive: isMicMuted,
            onTap: onMicTap,
          ),
          _ControlButton(
            icon: isVideoMuted ? Icons.videocam_off : Icons.videocam,
            label: 'Mute video',
            isActive: isVideoMuted,
            onTap: onVideoTap,
          ),
          _ControlButton(
            icon: Icons.cameraswitch,
            label: 'Flip Cam',
            onTap: onFlipTap,
          ),
          _ControlButton(
            icon: Icons.flashlight_on,
            label: 'Torch',
            isActive: isTorchOn,
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
    );
  }
}
