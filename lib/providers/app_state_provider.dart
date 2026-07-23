import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/janus_config.dart';
import '../models/stream_config.dart';

// ─── State ────────────────────────────────────────────────────────────────────

/// Single source of truth shared across all three screens.
///
/// Holds:
///  • Connection parameters (serverUrl, roomId, pin, displayName)
///  • Stream configuration (resolution, fps, bitrate)
///  • Ephemeral UI flags (isConnecting, errorMessage, saveAsDefault)
class AppState {
  final String serverUrl;
  final String roomId;
  final String pin;
  final String displayName;
  final StreamConfig streamConfig;
  final bool saveAsDefault;
  final bool isConnecting;
  final String? errorMessage;

  const AppState({
    this.serverUrl = '',
    this.roomId = '',
    this.pin = '',
    this.displayName = '',
    this.streamConfig = const StreamConfig(),
    this.saveAsDefault = false,
    this.isConnecting = false,
    this.errorMessage,
  });

  AppState copyWith({
    String? serverUrl,
    String? roomId,
    String? pin,
    String? displayName,
    StreamConfig? streamConfig,
    bool? saveAsDefault,
    bool? isConnecting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppState(
      serverUrl: serverUrl ?? this.serverUrl,
      roomId: roomId ?? this.roomId,
      pin: pin ?? this.pin,
      displayName: displayName ?? this.displayName,
      streamConfig: streamConfig ?? this.streamConfig,
      saveAsDefault: saveAsDefault ?? this.saveAsDefault,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Returns a validated [JanusConfig] from the current state.
  JanusConfig? get validatedConfig {
    if (serverUrl.trim().isEmpty) return null;
    if (roomId.trim().isEmpty) return null;
    if (displayName.trim().isEmpty) return null;
    return JanusConfig(
      serverUrl: serverUrl.trim(),
      roomId: roomId.trim(),
      pin: pin.trim(),
      displayName: displayName.trim(),
    );
  }

  String? get validationError {
    final url = serverUrl.trim();
    if (url.isEmpty) return 'Janus Server URL is required.';
    if (!url.startsWith('http://') &&
        !url.startsWith('https://') &&
        !url.startsWith('ws://') &&
        !url.startsWith('wss://')) {
      return 'URL must start with http, https, ws, or wss';
    }
    if (roomId.trim().isEmpty) return 'Room ID is required.';
    if (displayName.trim().isEmpty) return 'Display Name is required.';
    return null;
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState()) {
    _loadSavedProfile();
  }

  static const _keyServer = 'janus_server';
  static const _keyRoom = 'janus_room';
  static const _keyPin = 'janus_pin';
  static const _keyName = 'janus_name';
  static const _keyResolution = 'stream_resolution';
  static const _keyFps = 'stream_fps';
  static const _keyBitrate = 'stream_bitrate';

  void setServerUrl(String v) =>
      state = state.copyWith(serverUrl: v, clearError: true);
  void setRoomId(String v) =>
      state = state.copyWith(roomId: v, clearError: true);
  void setPin(String v) => state = state.copyWith(pin: v, clearError: true);
  void setDisplayName(String v) =>
      state = state.copyWith(displayName: v, clearError: true);
  void setSaveAsDefault(bool v) => state = state.copyWith(saveAsDefault: v);

  void applyJanusConfig(JanusConfig config) {
    state = state.copyWith(
      serverUrl: config.serverUrl,
      roomId: config.roomId,
      pin: config.pin,
      displayName: config.displayName,
      clearError: true,
    );
  }

  Future<void> applyStreamConfig(StreamConfig config) async {
    state = state.copyWith(streamConfig: config);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyResolution, config.resolution.name);
    await prefs.setInt(_keyFps, config.fps);
    await prefs.setInt(_keyBitrate, config.bitrateKbps);
  }

  Future<JanusConfig?> connect() async {
    final error = state.validationError;
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return null;
    }

    state = state.copyWith(isConnecting: true, clearError: true);

    try {
      final config = state.validatedConfig!;
      if (state.saveAsDefault) {
        await _saveProfile(config);
      } else {
        await _clearSavedProfile();
      }
      return config;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: 'Failed to save profile: $e',
      );
      return null;
    }
  }

  void clearConnecting() =>
      state = state.copyWith(isConnecting: false, clearError: true);

  void setError(String message) =>
      state = state.copyWith(isConnecting: false, errorMessage: message);

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString(_keyServer);

    final resName = prefs.getString(_keyResolution);
    final savedRes = resName != null
        ? StreamResolution.values.firstWhere(
            (r) => r.name == resName,
            orElse: () => StreamResolution.hd,
          )
        : StreamResolution.hd;
    final savedFps = prefs.getInt(_keyFps) ?? 30;
    final savedBitrate = prefs.getInt(_keyBitrate) ?? 1500;

    final loadedConfig = StreamConfig(
      resolution: savedRes,
      fps: savedFps,
      bitrateKbps: savedBitrate,
    );

    if (server == null) {
      // Still apply persisted stream config even if no saved profile.
      state = state.copyWith(streamConfig: loadedConfig);
      return;
    }

    state = state.copyWith(
      serverUrl: server,
      roomId: prefs.getString(_keyRoom) ?? '',
      pin: prefs.getString(_keyPin) ?? '',
      displayName: prefs.getString(_keyName) ?? '',
      streamConfig: loadedConfig,
    );
  }

  Future<void> _saveProfile(JanusConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServer, config.serverUrl);
    await prefs.setString(_keyRoom, config.roomId);
    await prefs.setString(_keyPin, config.pin);
    await prefs.setString(_keyName, config.displayName);
  }

  Future<void> _clearSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServer);
    await prefs.remove(_keyRoom);
    await prefs.remove(_keyPin);
    await prefs.remove(_keyName);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>(
  (ref) => AppStateNotifier(),
);
