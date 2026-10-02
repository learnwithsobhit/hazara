class VoiceClip {
  VoiceClip({
    required this.mime,
    required this.durationMs,
    required this.audioB64,
  });

  final String mime;
  final int durationMs;
  final String audioB64;
}

class VoiceNote {
  bool get recording => false;

  Future<void> start() async {}

  Future<VoiceClip?> stop() async => null;

  Future<void> cancel() async {}
}
