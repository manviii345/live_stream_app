import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Big orange pill button: "Start/Stop Streaming".
class StreamButton extends StatelessWidget {
  final bool isLive;
  final VoidCallback onPressed;

  const StreamButton({
    super.key,
    required this.isLive,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Text(
          isLive ? 'Stop Streaming' : 'Start/Stop Streaming',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
