/// Browser microphone prompt. No-op off the web (tests and desktop VM).
library;

export 'mic_permission_stub.dart'
    if (dart.library.js_interop) 'mic_permission_web.dart';
