import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
  web.MediaStream? _stream;
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];
  DateTime? _started;
  String _mime = 'audio/webm';
  Completer<void>? _stopped;

  bool get recording => _started != null;

  Future<void> start() async {
    await cancel();
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart;
    _stream = stream;
    _mime = _pickMime();
    _chunks.clear();
    final recorder = web.MediaRecorder(
      stream,
      web.MediaRecorderOptions(mimeType: _mime, audioBitsPerSecond: 24000),
    );
    _recorder = recorder;
    recorder.addEventListener(
      'dataavailable',
      (web.Event event) {
        final data = (event as web.BlobEvent).data;
        if (data.size > 0) _chunks.add(data);
      }.toJS,
    );
    recorder.addEventListener(
      'stop',
      (web.Event _) {
        _stopped?.complete();
        _stopped = null;
      }.toJS,
    );
    recorder.start(250);
    _started = DateTime.now();
  }

  String _pickMime() {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
    ];
    for (final mime in candidates) {
      if (web.MediaRecorder.isTypeSupported(mime)) return mime;
    }
    return 'audio/webm';
  }

  Future<VoiceClip?> stop() async {
    final started = _started;
    final recorder = _recorder;
    _started = null;
    if (started == null || recorder == null) {
      await cancel();
      return null;
    }
    var durationMs = DateTime.now().difference(started).inMilliseconds;
    if (durationMs > 6000) durationMs = 6000;
    if (recorder.state == 'recording' || recorder.state == 'paused') {
      _stopped = Completer<void>();
      recorder.stop();
      await _stopped!.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    await _releaseStream();
    if (_chunks.isEmpty || durationMs < 400) return null;
    final blob = web.Blob(_chunks.toJS, web.BlobPropertyBag(type: _mime));
    final buffer = await blob.arrayBuffer().toDart;
    final bytes = Uint8List.view(buffer.toDart);
    if (bytes.length > 28000) return null;
    return VoiceClip(
      mime: _mime,
      durationMs: durationMs,
      audioB64: base64Encode(bytes),
    );
  }

  Future<void> cancel() async {
    final recorder = _recorder;
    _started = null;
    _recorder = null;
    if (recorder != null &&
        (recorder.state == 'recording' || recorder.state == 'paused')) {
      recorder.stop();
    }
    _chunks.clear();
    await _releaseStream();
  }

  Future<void> _releaseStream() async {
    final stream = _stream;
    _stream = null;
    if (stream == null) return;
    for (final track in stream.getAudioTracks().toDart) {
      track.stop();
    }
  }
}
