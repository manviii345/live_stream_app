import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';
import '../../stream_config/screens/stream_config_screen.dart';
import '../providers/live_stream_provider.dart';
import '../widgets/control_bar.dart';
import '../widgets/stream_button.dart';
import '../widgets/view_finder.dart';

class LiveStreamScreen extends ConsumerStatefulWidget {
  const LiveStreamScreen({super.key});

  @override
  ConsumerState<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends ConsumerState<LiveStreamScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(liveStreamProvider.notifier).requestPermissions());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveStreamProvider);
    final notifier = ref.read(liveStreamProvider.notifier);
    final renderer = notifier.renderer;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        titleSpacing: 16,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardWhite(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Text(
            'Logo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark(context),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: AppColors.textDark(context),
                      size: 20,
                    ),
                    tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
                    onPressed: () =>
                        ref.read(themeModeProvider.notifier).toggleTheme(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _statusLabel(state.phase),
                    style: TextStyle(
                      color: _statusColor(state.phase),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('|', style: TextStyle(color: AppColors.border(context))),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StreamConfigScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.settings_outlined,
                            size: 20, color: AppColors.textDark(context)),
                        const SizedBox(width: 4),
                        Text('Settings',
                            style: TextStyle(color: AppColors.textDark(context))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            final horizontalPadding = isLandscape
                ? 16.0
                : (constraints.maxWidth > 600 ? 32.0 : 16.0);

            if (isLandscape) {
              final sideWidth = math.min(constraints.maxWidth * 0.4, 340.0);
              return Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ViewFinderWidget(
                        renderer: renderer,
                        phase: state.phase,
                        isFrontCamera: state.isFrontCamera,
                        isVideoMuted: state.isVideoMuted,
                        errorMessage: state.errorMessage,
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      width: sideWidth,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StreamButton(
                              isConnected: state.isConnected,
                              isStreaming: state.isStreaming,
                              onStartStreaming: notifier.startStreaming,
                              onStopStreaming: notifier.stopStreaming,
                            ),
                            const SizedBox(height: 12),
                            ControlBar(
                              isStreaming: state.isStreaming,
                              isMicMuted: state.isMicMuted,
                              isVideoMuted: state.isVideoMuted,
                              isTorchOn: state.isTorchOn,
                              isTorchSupported: state.isTorchSupported,
                              onMicTap: notifier.toggleMic,
                              onVideoTap: notifier.toggleVideo,
                              onFlipTap: notifier.flipCamera,
                              onTorchTap: notifier.toggleTorch,
                              onDisconnectTap: () =>
                                  _confirmDisconnect(context, notifier),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 12),
              child: Column(
                children: [
                  Expanded(
                    child: ViewFinderWidget(
                      renderer: renderer,
                      phase: state.phase,
                      isFrontCamera: state.isFrontCamera,
                      isVideoMuted: state.isVideoMuted,
                      errorMessage: state.errorMessage,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamButton(
                          isConnected: state.isConnected,
                          isStreaming: state.isStreaming,
                          onStartStreaming: notifier.startStreaming,
                          onStopStreaming: notifier.stopStreaming,
                        ),
                        const SizedBox(height: 12),
                        ControlBar(
                          isStreaming: state.isStreaming,
                          isMicMuted: state.isMicMuted,
                          isVideoMuted: state.isVideoMuted,
                          isTorchOn: state.isTorchOn,
                          isTorchSupported: state.isTorchSupported,
                          onMicTap: notifier.toggleMic,
                          onVideoTap: notifier.toggleVideo,
                          onFlipTap: notifier.flipCamera,
                          onTorchTap: notifier.toggleTorch,
                          onDisconnectTap: () =>
                              _confirmDisconnect(context, notifier),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(StreamingPhase phase) {
    switch (phase) {
      case StreamingPhase.idle:
        return 'OFFLINE';
      case StreamingPhase.connected:
        return 'CONNECTED';
      case StreamingPhase.streaming:
        return 'LIVE';
    }
  }

  Color _statusColor(StreamingPhase phase) {
    switch (phase) {
      case StreamingPhase.idle:
        return AppColors.textGreyLight;
      case StreamingPhase.connected:
        return const Color(0xFF3B6FF5);
      case StreamingPhase.streaming:
        return AppColors.liveRed;
    }
  }

  void _confirmDisconnect(
      BuildContext context, LiveStreamNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
            'This will stop the stream and close the server connection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              notifier.disconnect();
              Navigator.of(context).pop();
            },
            child: const Text('Disconnect',
                style: TextStyle(color: AppColors.disconnectRed)),
          ),
        ],
      ),
    );
  }
}
