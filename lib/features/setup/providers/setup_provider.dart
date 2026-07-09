import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/janus_config.dart';
// State

class SetupState {
  final String serverUrl;
  final String roomId;
  final String pin;
  final String displayName;
  final bool saveAsDefault;
  final bool isConnecting;
  final String? errorMessage;

  const SetupState({
    this.serverUrl = '',
    this.roomId = '',
    this.pin = '',
    this.displayName = '',
    this.saveAsDefault = false,
    this.isConnecting = false,
    this.errorMessage,
  });

  SetupState copyWith({
    String? serverUrl,
    String? roomId,
    String? pin,
    String? displayName,
    bool? saveAsDefault,
    bool? isConnecting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SetupState(
      serverUrl: serverUrl ?? this.serverUrl,
      roomId: roomId ?? this.roomId,
      pin: pin ?? this.pin,
      displayName: displayName ?? this.displayName,
      saveAsDefault: saveAsDefault ?? this.saveAsDefault,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Returns a validated [JanusConfig] or null with an error message.
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
    if (serverUrl.trim().isEmpty) return 'Janus Server URL is required.';
    if (roomId.trim().isEmpty) return 'Room ID is required.';
    if (displayName.trim().isEmpty) return 'Display Name is required.';
    return null;
  }
}
// Notifier

class SetupNotifier extends StateNotifier<SetupState> {
  SetupNotifier() : super(const SetupState()) {
    _loadSavedProfile();
  }

  static const _keyServer = 'janus_server';
  static const _keyRoom = 'janus_room';
  static const _keyPin = 'janus_pin';
  static const _keyName = 'janus_name';
  // Field setters

  void setServerUrl(String v) =>
      state = state.copyWith(serverUrl: v, clearError: true);
  void setRoomId(String v) =>
      state = state.copyWith(roomId: v, clearError: true);
  void setPin(String v) => state = state.copyWith(pin: v, clearError: true);
  void setDisplayName(String v) =>
      state = state.copyWith(displayName: v, clearError: true);
  void setSaveAsDefault(bool v) => state = state.copyWith(saveAsDefault: v);

  /// Fill all fields at once (used when a QR code is scanned).
  void applyConfig(JanusConfig config) {
    state = state.copyWith(
      serverUrl: config.serverUrl,
      roomId: config.roomId,
      pin: config.pin,
      displayName: config.displayName,
      clearError: true,
    );
  }
  // Persistence

  Future<void> _loadSavedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString(_keyServer);
    if (server == null) return; // nothing saved
    state = state.copyWith(
      serverUrl: server,
      roomId: prefs.getString(_keyRoom) ?? '',
      pin: prefs.getString(_keyPin) ?? '',
      displayName: prefs.getString(_keyName) ?? '',
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
  // Connect

  /// Validates fields, optionally persists, then returns the [JanusConfig]
  /// on success. Returns null if validation fails (error set in state).
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

      await Future.delayed(const Duration(milliseconds: 800));

      state = state.copyWith(isConnecting: false);
      return config;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        errorMessage: 'Connection failed: $e',
      );
      return null;
    }
  }
}
// Provider

final setupProvider = StateNotifierProvider<SetupNotifier, SetupState>(
  (ref) => SetupNotifier(),
);
