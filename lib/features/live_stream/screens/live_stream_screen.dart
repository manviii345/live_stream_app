import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/setup/models/janus_config.dart';
import '../providers/live_stream_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/stream_button.dart';
import '../widgets/view_finder.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  final JanusConfig? config;
  const LiveStreamScreen({super.key, this.config});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off camera + mic permission request as soon as screen loads.
    Future.microtask(() => ref.read(liveStreamProvider.notifier).initializeCamera());
  }

  @override
  void dispose() {
    ref.read(liveStreamProvider.notifier).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveStreamProvider);
    final notifier = ref.read(liveStreamProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('Logo', style: TextStyle(color: AppColors.textDark)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Text(
                  state.isLive ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: state.isLive ? AppColors.liveRed : AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('|', style: TextStyle(color: AppColors.border)),
                const SizedBox(width: 6),
                const Icon(Icons.settings_outlined, size: 20, color: AppColors.textDark),
                const SizedBox(width: 4),
                const Text('Settings', style: TextStyle(color: AppColors.textDark)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive padding: tighter on small phones, roomier on tablets.
            final horizontalPadding = constraints.maxWidth > 600 ? 32.0 : 16.0;

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
              child: Column(
                children: [
                  // View finder takes most of the available space.
                  Expanded(
                    child: ViewFinderWidget(
                      controller: state.controller,
                      isInitialized: state.isInitialized,
                      isVideoMuted: state.isVideoMuted,
                      errorMessage: state.errorMessage,
                    ),
                  ),
                  const SizedBox(height: 20),
                  StreamButton(
                    isLive: state.isLive,
                    onPressed: notifier.toggleStreaming,
                  ),
                  const SizedBox(height: 16),
                  ControlBar(
                    isMicMuted: state.isMicMuted,
                    isVideoMuted: state.isVideoMuted,
                    isTorchOn: state.isTorchOn,
                    isTorchSupported: state.isTorchSupported,
                    onMicTap: notifier.toggleMic,
                    onVideoTap: notifier.toggleVideo,
                    onFlipTap: notifier.flipCamera,
                    onTorchTap: notifier.toggleTorch,
                    onDisconnectTap: () => _confirmDisconnect(context, notifier),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, LiveStreamNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('This will stop the stream and release the camera.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.disconnect();
            },
            child: const Text('Disconnect', style: TextStyle(color: AppColors.disconnectRed)),
          ),
        ],
      ),
    );
  }
}
