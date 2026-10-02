import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Ask for the microphone under the Create / Join tap, then release the tracks.
/// Permission sticks in the browser. A denial does not block the table.
Future<void> requestMicrophonePermission() async {
  try {
    final stream = await web.window.navigator.mediaDevices
        .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
        .toDart
        .timeout(const Duration(seconds: 15));
    for (final track in stream.getAudioTracks().toDart) {
      track.stop();
    }
  } catch (_) {}
}
