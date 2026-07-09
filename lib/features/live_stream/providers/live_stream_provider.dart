import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
// State

/// Immutable state for the live stream screen.
class LiveStreamState {
  final bool isLive;
  final bool isMicMuted;
  final bool isVideoMuted;

  /// Whether the user *wants* the torch ON. Survives camera flips.
  final bool isTorchOn;

  /// Whether the current camera physically has a flash unit.
  /// False while no camera is bound, or when the active lens has no flash.
  final bool isTorchSupported;

  final bool isFrontCamera;
  final bool isInitialized;
  final String? errorMessage;
  final CameraController? controller;

  const LiveStreamState({
    this.isLive = false,
    this.isMicMuted = false,
    this.isVideoMuted = false,
    this.isTorchOn = false,
    this.isTorchSupported = false,
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
    bool? isTorchSupported,
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
      isTorchSupported: isTorchSupported ?? this.isTorchSupported,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isInitialized: isInitialized ?? this.isInitialized,
      errorMessage: errorMessage,
      controller: controller ?? this.controller,
    );
  }
}
// Notifier

/// Notifier handling all hardware interactions: camera, mic, torch.
///
/// ## Torch design
/// The `torch_light` package is intentionally NOT used. It opens a second
/// independent camera session, which conflicts with the CameraX session that
/// the `camera` Flutter plugin already holds.  Using two sessions in parallel
/// triggers "Camera in use" / `ERROR_CAMERA_IN_USE` on Android.
///
/// Instead we use [CameraController.setFlashMode] exclusively — this drives the
/// flash on the *already-bound* CameraX Camera object, satisfying:
///   • No second camera instance.
///   • Works for both lenses (back = hardware LED; front = screen-flash if
///     the OEM supports [FlashMode.torch] on the front sensor).
///   • `isTorchOn` is a *user preference* that survives flips; the actual
///     hardware is (re-)applied after the new controller is fully initialised.
class LiveStreamNotifier extends StateNotifier<LiveStreamState> {
  LiveStreamNotifier() : super(const LiveStreamState());

  List<CameraDescription> _cameras = [];
  // Initialization

  /// Request permissions, discover cameras, bind the first (back) camera.
  Future<void> initializeCamera() async {
    try {
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
  // Internal helpers

  /// Creates, initialises and binds a new [CameraController].
  ///
  /// Steps (order matters for correctness):
  ///  1. Gracefully turn off flash on the *outgoing* controller before dispose
  ///     so the hardware LED is left in a clean state.
  ///  2. Dispose the old controller — releases the CameraX session.
  ///  3. Create + initialise the new controller — opens a fresh CameraX session.
  ///  4. Probe flash support via a silent try/catch.
  ///  5. If the user preference `isTorchOn` is true AND the new lens supports
  ///     flash, re-enable it on the new session.
  ///
  /// Doing step 5 *after* initialisation avoids any race condition: the camera
  /// is fully bound before we touch the flash.
  Future<void> _startController(CameraDescription description) async {
    // ── 1. Turn off flash on the outgoing camera before releasing it.
    final outgoing = state.controller;
    if (outgoing != null && outgoing.value.isInitialized) {
      await _setFlashOff(outgoing);
    }

    // ── 2. Release the old CameraX session.
    await outgoing?.dispose();

    // ── 3. Bind a new CameraX session.
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: !state.isMicMuted,
      // imageFormatGroup omitted — default is fine for preview + streaming.
    );

    await controller.initialize();

    // ── 4. Probe whether this lens has a flash unit.
    //      We attempt a no-op setFlashMode; a CameraException means no flash.
    final supported = await _probeFlashSupport(controller);

    // Publish the new controller and flash-support flag immediately so the UI
    // stops showing a spinner.
    state = state.copyWith(
      controller: controller,
      isInitialized: true,
      isTorchSupported: supported,
      errorMessage: null,
    );

    // ── 5. Reapply user's torch preference on the newly bound camera.
    //      This is the key fix: torch state survives camera flips.
    if (state.isTorchOn && supported) {
      await _setFlashMode(controller, FlashMode.torch);
    }
  }

  /// Silently probes whether [controller]'s camera has a flash unit by
  /// attempting to set [FlashMode.torch] then restoring [FlashMode.off].
  ///
  /// Returns `true` if the camera supports torch mode.
  Future<bool> _probeFlashSupport(CameraController controller) async {
    try {
      await controller.setFlashMode(FlashMode.torch);
      // If we got here it's supported — restore to off immediately.
      await controller.setFlashMode(FlashMode.off);
      return true;
    } on CameraException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Sets flash mode on [controller], silently ignoring any [CameraException].
  Future<void> _setFlashMode(
      CameraController controller, FlashMode mode) async {
    try {
      await controller.setFlashMode(mode);
    } on CameraException {
      // Camera doesn't support this flash mode — fail gracefully.
    } catch (_) {
      // Any other low-level error — ignore.
    }
  }

  /// Convenience wrapper to turn flash off silently.
  Future<void> _setFlashOff(CameraController controller) =>
      _setFlashMode(controller, FlashMode.off);

  void toggleStreaming() {
    if (!state.isInitialized) return;
    state = state.copyWith(isLive: !state.isLive);
  }

  /// Mute/unmute microphone.
  /// Re-creates the controller because [enableAudio] can't be toggled live on
  /// most platforms.  [_startController] will preserve torch state.
  Future<void> toggleMic() async {
    final newMuted = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMuted);
    if (state.controller != null) {
      await _startController(state.controller!.description);
    }
  }

  /// Mute/unmute the camera preview.
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

  /// Flip between front and back camera while preserving the user's torch
  /// preference (`isTorchOn`).
  ///
  /// Flow:
  ///  • [_startController] turns off the outgoing flash (step 1) before
  ///    dispose, then re-enables it on the incoming camera (step 5) if
  ///    supported.  No extra logic is needed here.
  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;

    final newIsFront = !state.isFrontCamera;
    final newDescription = _cameras.firstWhere(
      (c) => newIsFront
          ? c.lensDirection == CameraLensDirection.front
          : c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    // Update lens-direction flag before _startController so that the UI
    // reflects the correct camera immediately.
    state = state.copyWith(isFrontCamera: newIsFront);

    // _startController handles:
    //   • turning off outgoing torch (step 1)
    //   • probing new camera's flash support (step 4)
    //   • re-enabling torch if user had it on AND new lens supports it (step 5)
    await _startController(newDescription);
  }

  /// Toggle torch on/off.
  ///
  /// Updates [isTorchOn] (user preference) and drives the hardware.
  /// If the current camera doesn't support flash, the toggle is a no-op but
  /// the preference is still stored — so if the user later flips to a lens
  /// that *does* have flash it will be auto-enabled.
  Future<void> toggleTorch() async {
    final controller = state.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final newOn = !state.isTorchOn;

    // Persist the user's intention regardless of hardware support.
    state = state.copyWith(isTorchOn: newOn);

    // Drive the hardware only if the current camera supports it.
    if (state.isTorchSupported) {
      await _setFlashMode(
        controller,
        newOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  /// Disconnect: turn off flash, release camera, reset state.
  Future<void> disconnect() async {
    final controller = state.controller;
    if (controller != null && controller.value.isInitialized) {
      await _setFlashOff(controller);
    }
    await controller?.dispose();
    state = const LiveStreamState();
  }

  @override
  void dispose() {
    // Dispose without awaiting — this is called synchronously by the framework.
    state.controller?.dispose();
    super.dispose();
  }
}
// Provider

final liveStreamProvider =
    StateNotifierProvider<LiveStreamNotifier, LiveStreamState>(
  (ref) => LiveStreamNotifier(),
);
