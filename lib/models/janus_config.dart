class JanusConfig {
  final String serverUrl;
  final String roomId;
  final String pin;
  final String displayName;

  const JanusConfig({
    required this.serverUrl,
    required this.roomId,
    required this.pin,
    required this.displayName,
  });

  /// Parse from a QR-code JSON payload.
  /// Expected format: {"server":"…","room":"…","pin":"…","name":"…"}
  factory JanusConfig.fromQrJson(Map<String, dynamic> json) {
    return JanusConfig(
      serverUrl: (json['server'] as String? ?? '').trim(),
      roomId: (json['room'] as String? ?? '').trim(),
      pin: (json['pin'] as String? ?? '').trim(),
      displayName: (json['name'] as String? ?? '').trim(),
    );
  }

  Map<String, String> toMap() => {
        'server': serverUrl,
        'room': roomId,
        'pin': pin,
        'name': displayName,
      };

  JanusConfig copyWith({
    String? serverUrl,
    String? roomId,
    String? pin,
    String? displayName,
  }) {
    return JanusConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      roomId: roomId ?? this.roomId,
      pin: pin ?? this.pin,
      displayName: displayName ?? this.displayName,
    );
  }
}
