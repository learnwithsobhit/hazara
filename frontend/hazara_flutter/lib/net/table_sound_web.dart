import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

const _clips = {
  'laugh': 'assets/sounds/laugh.wav',
  'clap': 'assets/sounds/clap.wav',
  'oh_no': 'assets/sounds/oh_no.wav',
  'nice': 'assets/sounds/nice.wav',
  'gg': 'assets/sounds/gg.wav',
  'airhorn': 'assets/sounds/airhorn.wav',
  'facepalm': 'assets/sounds/facepalm.wav',
};

web.HTMLAudioElement? _audio;

web.HTMLAudioElement _element() {
  return _audio ??= web.HTMLAudioElement()
    ..preload = 'auto'
    ..volume = 1;
}

Future<void> unlockTableSound() async {
  final audio = _element();
  audio.muted = true;
  audio.src =
      'data:audio/wav;base64,UklGRigAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQQAAAAAAA==';
  try {
    await audio.play().toDart.timeout(const Duration(milliseconds: 400));
  } catch (_) {}
  audio.pause();
  audio.muted = false;
  audio.volume = 1;
}

Future<void> playSoundId(String id) async {
  final asset = _clips[id];
  if (asset == null) return;
  final data = await rootBundle.load(asset);
  await _play(data.buffer.asUint8List(), 'audio/wav');
}

Future<void> playVoice(Uint8List bytes, String mime) async {
  final blobMime = mime.contains('ogg') ? 'audio/ogg' : 'audio/webm';
  await _play(bytes, blobMime);
}

Future<void> _play(Uint8List bytes, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final audio = _element()..volume = 1;
  audio.src = url;
  try {
    await audio.play().toDart;
  } catch (_) {}
  Future<void>.delayed(const Duration(seconds: 8), () {
    web.URL.revokeObjectURL(url);
  });
}
