import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../models/stream_config.dart';
import '../../../services/janus_service.dart';

enum StreamingPhase { idle, connected, streaming }

class LiveStreamState {
  final StreamingPhase phase;
  final bool isMicMuted;
  final bool isVideoMuted;
  final bool isTorchOn;
  final bool isTorchSupported;
  final bool isFrontCamera;
  final bool permissionsGranted;
  final String? errorMessage;

  const LiveStreamState({
    this.phase = StreamingPhase.idle,
    this.isMicMuted = false,
    this.isVideoMuted = false,
    this.isTorchOn = false,
    this.isTorchSupported = false,
    this.isFrontCamera = false,
    this.permissionsGranted = false,
    this.errorMessage,
  });

  bool get isConnected => phase == StreamingPhase.connected;
  bool get isStreaming => phase == StreamingPhase.streaming;

  LiveStreamState copyWith({
    StreamingPhase? phase,
    bool? isMicMuted,
    bool? isVideoMuted,
    bool? isTorchOn,
    bool? isTorchSupported,
    bool? isFrontCamera,
    bool? permissionsGranted,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LiveStreamState(
      phase: phase ?? this.phase,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isTorchSupported: isTorchSupported ?? this.isTorchSupported,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      permissionsGranted: permissionsGranted ?? this.permissionsGranted,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LiveStreamNotifier extends StateNotifier<LiveStreamState> {
  final Ref _ref;
  late final JanusService _janus;

  RTCVideoRenderer? _renderer;
  RTCVideoRenderer? get renderer => _renderer;

  LiveStreamNotifier(this._ref) : super(const LiveStreamState()) {
    _janus = _ref.read(janusServiceProvider);

    state = state.copyWith(phase: _phaseFrom(_janus.phase));

    _janus.onPhaseChange = (p) {
      if (!mounted) return;
      state = state.copyWith(phase: _phaseFrom(p));
    };

    _janus.onError = (msg) {
      if (mounted) state = state.copyWith(errorMessage: msg);
    };
  }

  static StreamingPhase _phaseFrom(JanusPhase p) {
    switch (p) {
      case JanusPhase.publishing:
        return StreamingPhase.streaming;
      case JanusPhase.joined:
        return StreamingPhase.connected;
      default:
        return StreamingPhase.idle;
    }
  }

  Future<void> requestPermissions() async {
    try {
      final statuses = await [Permission.camera, Permission.microphone].request();
      final granted =
          (statuses[Permission.camera]?.isGranted ?? false) &&
          (statuses[Permission.microphone]?.isGranted ?? false);

      if (!granted) {
        state = state.copyWith(
          errorMessage: 'Camera and microphone permissions are required.',
        );
        return;
      }

      state = state.copyWith(permissionsGranted: true, clearError: true);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Permission request failed: $e');
    }
  }

  Future<void> startStreaming() async {
    if (!state.isConnected) return;

    try {
      await _janus.startPublishing(state.isFrontCamera);

      _renderer = RTCVideoRenderer();
      await _renderer!.initialize();
      _renderer!.srcObject = _janus.localStream;

      final stream = _janus.localStream;
      if (stream != null) {
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          final hasTorch = await track.hasTorch();
          state = state.copyWith(isTorchSupported: hasTorch);
          if (state.isTorchOn && hasTorch) {
            await track.setTorch(true);
          }
        }
      }

      if (state.isMicMuted) {
        _setAudioEnabled(false);
      }
      if (state.isVideoMuted) {
        _setVideoEnabled(false);
      }
    } catch (_) {
      await _disposeRenderer();
    }
  }

  Future<void> stopStreaming() async {
    if (!state.isStreaming) return;
    await _janus.stopPublishing();
    await _disposeRenderer();
  }

  Future<void> flipCamera() async {
    final newIsFront = !state.isFrontCamera;
    state = state.copyWith(isFrontCamera: newIsFront);

    if (!state.isStreaming) return;

    try {
      final stream = _janus.localStream;
      if (stream != null) {
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final track = videoTracks.first;
          await Helper.switchCamera(track);

          final hasTorch = await track.hasTorch();
          state = state.copyWith(isTorchSupported: hasTorch);

          if (state.isTorchOn) {
            if (hasTorch) {
              await track.setTorch(true);
            }
          }
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Camera flip failed: $e');
    }
  }

  Future<void> toggleMic() async {
    final newMuted = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMuted);
    if (state.isStreaming) _setAudioEnabled(!newMuted);
  }

  Future<void> toggleVideo() async {
    final newMuted = !state.isVideoMuted;
    state = state.copyWith(isVideoMuted: newMuted);
    if (state.isStreaming) _setVideoEnabled(!newMuted);
  }

  Future<void> toggleTorch() async {
    if (!state.isStreaming) return;
    final stream = _janus.localStream;
    if (stream == null) return;
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) return;
    final track = videoTracks.first;

    final newTorchState = !state.isTorchOn;
    state = state.copyWith(isTorchOn: newTorchState);

    final canTorch = await track.hasTorch();
    if (canTorch) {
      await track.setTorch(newTorchState);
    }
  }

  Future<void> applyStreamConfig(StreamConfig newConfig) async {
    await _janus.applyStreamConfig(newConfig);
  }

  Future<void> disconnect() async {
    await _janus.dispose();
    await _disposeRenderer();
    state = state.copyWith(phase: StreamingPhase.idle, clearError: true);
  }

  void markConnected() {
    state = state.copyWith(phase: StreamingPhase.connected, clearError: true);
  }

  void _setAudioEnabled(bool enabled) {
    final stream = _janus.localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  void _setVideoEnabled(bool enabled) {
    final stream = _janus.localStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> _disposeRenderer() async {
    await _renderer?.dispose();
    _renderer = null;
  }

  @override
  void dispose() {
    _janus.onPhaseChange = null;
    _janus.onError = null;
    _renderer?.dispose();
    super.dispose();
  }
}

final liveStreamProvider =
    StateNotifierProvider<LiveStreamNotifier, LiveStreamState>(
  (ref) => LiveStreamNotifier(ref),
);
