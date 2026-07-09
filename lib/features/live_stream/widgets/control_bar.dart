import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// One circular icon button + label, used in the bottom control row.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isDisabled;
  final Color? activeColor;
  final Color labelColor;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDisabled = false,
    this.activeColor,
    this.labelColor = AppColors.textGrey,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDisabled
        ? AppColors.textGrey.withOpacity(0.35)
        : isActive
            ? (activeColor ?? AppColors.orange)
            : AppColors.textDark;

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
                  ? AppColors.cardWhite.withOpacity(0.5)
                  : AppColors.cardWhite,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDisabled
                    ? AppColors.border.withOpacity(0.4)
                    : AppColors.border,
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
                ? labelColor.withOpacity(0.35)
                : labelColor,
          ),
        ),
      ],
    );
  }
}

/// Bottom row: Mute mic / Mute video / Flip cam / Torch / Disconnect.
class ControlBar extends StatelessWidget {
  final bool isMicMuted;
  final bool isVideoMuted;
  final bool isTorchOn;

  /// Whether the currently active camera reports a flash unit.
  /// When false the torch button is rendered in a disabled/greyed state.
  final bool isTorchSupported;

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
            icon: isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
            label: 'Torch',
            isActive: isTorchOn,
            isDisabled: !isTorchSupported,
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
