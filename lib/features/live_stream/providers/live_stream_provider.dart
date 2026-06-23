import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';

/// Immutable state for the live stream screen.
class LiveStreamState {
  final bool isLive;
  final bool isMicMuted;
  final bool isVideoMuted;
  final bool isTorchOn;
  final bool isFrontCamera;
  final bool isInitialized;
  final String? errorMessage;
  final CameraController? controller;

  const LiveStreamState({
    this.isLive = false,
    this.isMicMuted = false,
    this.isVideoMuted = false,
    this.isTorchOn = false,
    this.isFrontCamera = false,
    this.isInitialized = false,
    this.errorMessage,
    this.controller,
  });

  LiveStreamState copyWith({
    bool? isLive,
    bool? isMicMuted,
    bool? isVideoMuted,
    bool? isTorchOn,
    bool? isFrontCamera,
    bool? isInitialized,
    String? errorMessage,
    CameraController? controller,
  }) {
    return LiveStreamState(
      isLive: isLive ?? this.isLive,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: errorMessage,
      controller: controller ?? this.controller,
    );
  }
}

/// Notifier handling all hardware interactions: camera, mic, torch.
class LiveStreamNotifier extends StateNotifier<LiveStreamState> {
  LiveStreamNotifier() : super(const LiveStreamState());

  List<CameraDescription> _cameras = [];

  /// Step 1: Request permissions, then initialize the camera controller.
  Future<void> initializeCamera() async {
    try {
      // Request camera + mic permissions together.
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (!cameraGranted || !micGranted) {
        state = state.copyWith(
          errorMessage: 'Camera and microphone permissions are required.',
        );
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        state = state.copyWith(errorMessage: 'No camera found on this device.');
        return;
      }

      await _startController(_cameras.first);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Camera init failed: $e');
    }
  }

  Future<void> _startController(CameraDescription description) async {
    // Dispose old controller before creating a new one (e.g. on flip).
    await state.controller?.dispose();

    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: !state.isMicMuted,
    );

    await controller.initialize();

    state = state.copyWith(
      controller: controller,
      isInitialized: true,
      errorMessage: null,
    );
  }

  /// Toggle Start/Stop streaming button.
  void toggleStreaming() {
    if (!state.isInitialized) return;
    state = state.copyWith(isLive: !state.isLive);
    // TODO: hook actual RTMP/streaming SDK start/stop here.
  }

  /// Mute/unmute microphone. Re-creates controller with new audio flag
  /// since `enableAudio` can't be toggled live on most platforms.
  Future<void> toggleMic() async {
    final newMuted = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMuted);
    if (state.controller != null) {
      await _startController(state.controller!.description);
    }
  }

  /// Mute/unmute video preview (pause/resume the image stream).
  Future<void> toggleVideo() async {
    final controller = state.controller;
    if (controller == null) return;

    final newMuted = !state.isVideoMuted;
    state = state.copyWith(isVideoMuted: newMuted);

    if (newMuted) {
      await controller.pausePreview();
    } else {
      await controller.resumePreview();
    }
  }

  /// Flip between front and back camera.
  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;
    final newIsFront = !state.isFrontCamera;
    final newDescription = _cameras.firstWhere(
      (c) => newIsFront
          ? c.lensDirection == CameraLensDirection.front
          : c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    state = state.copyWith(isFrontCamera: newIsFront);
    await _startController(newDescription);
  }

  /// Toggle torch (flashlight). Only works on back camera on most devices.
  Future<void> toggleTorch() async {
    try {
      if (state.isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      state = state.copyWith(isTorchOn: !state.isTorchOn);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Torch error: $e');
    }
  }

  Future<void> disconnect() async {
    await TorchLight.disableTorch().catchError((_) {});
    await state.controller?.dispose();
    state = const LiveStreamState();
  }

  @override
  void dispose() {
    state.controller?.dispose();
    super.dispose();
  }
}

final liveStreamProvider =
    StateNotifierProvider<LiveStreamNotifier, LiveStreamState>(
  (ref) => LiveStreamNotifier(),
);
