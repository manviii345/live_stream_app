// ─── Resolution enum ──────────────────────────────────────────────────────────

enum StreamResolution {
  sd(label: 'SD (640×480)', width: 640, height: 480),
  hd(label: 'HD (1280×720)', width: 1280, height: 720),
  fullHd(label: 'Full HD (1920×1080)', width: 1920, height: 1080);

  final String label;
  final int width;
  final int height;

  const StreamResolution({
    required this.label,
    required this.width,
    required this.height,
  });
}

// ─── Stream config model ──────────────────────────────────────────────────────

/// Immutable value object that holds all user-configurable stream parameters.
class StreamConfig {
  final StreamResolution resolution;

  /// Frames per second — either 30 or 60.
  final int fps;

  /// Target bitrate in kbps (300–4000).
  final int bitrateKbps;

  const StreamConfig({
    this.resolution = StreamResolution.hd,
    this.fps = 30,
    this.bitrateKbps = 1500,
  });

  StreamConfig copyWith({
    StreamResolution? resolution,
    int? fps,
    int? bitrateKbps,
  }) {
    return StreamConfig(
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamConfig &&
          runtimeType == other.runtimeType &&
          resolution == other.resolution &&
          fps == other.fps &&
          bitrateKbps == other.bitrateKbps;

  @override
  int get hashCode => Object.hash(resolution, fps, bitrateKbps);

  @override
  String toString() =>
      'StreamConfig(resolution: ${resolution.label}, fps: $fps, bitrate: ${bitrateKbps}kbps)';
}
