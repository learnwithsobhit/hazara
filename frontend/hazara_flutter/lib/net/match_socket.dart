import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'snapshot.dart';

class MatchSocket {
  MatchSocket({required this.base, required this.matchId, required this.token});

  final String base;
  final String matchId;
  final String token;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _keepAlive;
  bool closed = false;

  void connect({
    required void Function(TableSnapshot snapshot) onSnapshot,
    required void Function(String message) onError,
    required void Function() onDone,
    required void Function(Map<String, dynamic> talk) onTalk,
  }) {
    final wsBase = base.replaceFirst(RegExp(r'^http'), 'ws');
    final uri = Uri.parse('$wsBase/api/v1/matches/$matchId/ws?token=$token');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 10), (_) {
      _send({'type': 'ping'});
    });
    _sub = channel.stream.listen(
      (event) {
        final decoded = jsonDecode(event as String);
        if (decoded is! Map<String, dynamic>) return;
        switch (decoded['type']) {
          case 'snapshot':
            final raw = decoded['snapshot'];
            if (raw is Map<String, dynamic>) {
              onSnapshot(TableSnapshot.fromJson(raw));
            }
          case 'error':
            onError(
              decoded['message'] as String? ?? 'The table could not do that.',
            );
          case 'ping':
            _send({'type': 'pong'});
          case 'pong':
            break;
          case 'talk':
            onTalk(decoded);
          default:
            break;
        }
      },
      onError: (_) {
        if (!closed) onDone();
      },
      onDone: () {
        if (!closed) onDone();
      },
    );
  }

  void saveDraft(List<List<String>> sets) {
    _send({'type': 'save_draft', 'sets': sets});
  }

  void ready(String actionId, List<List<String>> sets) {
    _send({'type': 'ready', 'action_id': actionId, 'sets': sets});
  }

  void nextDeal() {
    _send({'type': 'next_deal'});
  }

  void rematch() {
    _send({'type': 'rematch'});
  }

  void nudge(String targetName) {
    _send({'type': 'nudge', 'target': targetName});
  }

  void forceEnd() {
    _send({'type': 'force_end'});
  }

  void reaction(String emoji) {
    _send({'type': 'reaction', 'emoji': emoji});
  }

  void talkText(String text) {
    _send({'type': 'talk_text', 'text': text});
  }

  void sound(String id) {
    _send({'type': 'sound', 'sound': id});
  }

  void voice({
    required String mime,
    required int durationMs,
    required String audioB64,
  }) {
    _send({
      'type': 'voice',
      'mime': mime,
      'duration_ms': durationMs,
      'audio_b64': audioB64,
    });
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    closed = true;
    _keepAlive?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
  }
}
