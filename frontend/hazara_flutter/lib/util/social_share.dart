/// Social sharing utilities for HAZARA — room invite links and platform intents.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum ShareChannel { whatsapp, telegram, x, system, copy }

const String kPublicWebOrigin = String.fromEnvironment(
  'PUBLIC_WEB_ORIGIN',
  defaultValue: 'https://hazara-lws-260731.web.app',
);

/// Build the canonical room URL.
String roomUrl(String code) {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    return '$origin/?room=$code';
  }
  return '$kPublicWebOrigin/?room=$code';
}

/// The share text sent to friends. Copy and chat get the join URL only —
/// extra sentences around the link confuse people who then land on Create.
String inviteText(String hostName, String code) => roomUrl(code);

/// Open the given URL, silently ignoring unsupported platforms.
Future<bool> _launch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

Future<bool> _copyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}

/// Share to the given channel.
/// Returns true if a native intent was launched, false if clipboard was used.
Future<bool> shareToChannel({
  required ShareChannel channel,
  required String text,
  required String url,
}) async {
  switch (channel) {
    case ShareChannel.whatsapp:
      final encoded = Uri.encodeComponent(text);
      final ok = await _launch(Uri.parse('https://wa.me/?text=$encoded'));
      if (!ok) await _copyToClipboard(text);
      return ok;

    case ShareChannel.telegram:
      final tu = Uri.encodeComponent(url);
      final tt = Uri.encodeComponent(text);
      final ok = await _launch(Uri.parse('https://t.me/share/url?url=$tu&text=$tt'));
      if (!ok) await _copyToClipboard(text);
      return ok;

    case ShareChannel.x:
      final encoded = Uri.encodeComponent(text);
      final ok = await _launch(Uri.parse('https://twitter.com/intent/tweet?text=$encoded'));
      if (!ok) await _copyToClipboard(text);
      return ok;

    case ShareChannel.system:
      return _copyToClipboard(url.isNotEmpty ? url : text);

    case ShareChannel.copy:
      return _copyToClipboard(url.isNotEmpty ? url : text);
  }
}
