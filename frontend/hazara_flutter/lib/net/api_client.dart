import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class RoomPreview {
  RoomPreview({
    required this.hostName,
    required this.seatsTaken,
    required this.seatsTotal,
    required this.matchLength,
    required this.inProgress,
  });
  final String hostName;
  final int seatsTaken;
  final int seatsTotal;
  final String matchLength;
  final bool inProgress;

  factory RoomPreview.fromJson(Map<String, dynamic> json) {
    return RoomPreview(
      hostName: json['host_name'] as String? ?? 'Someone',
      seatsTaken: json['seats_taken'] as int? ?? 0,
      seatsTotal: json['seats_total'] as int? ?? 4,
      matchLength: json['match_length'] as String? ?? 'short',
      inProgress: json['in_progress'] == true,
    );
  }
}

class GuestSession {
  GuestSession({
    required this.token,
    required this.playerId,
    required this.name,
  });

  final String token;
  final String playerId;
  final String name;
}

class RoomSeat {
  RoomSeat({required this.name, required this.you});

  final String? name;
  final bool you;
}

class RoomView {
  RoomView({
    required this.code,
    required this.matchLength,
    required this.youAreHost,
    required this.canStart,
    required this.matchId,
    required this.seats,
  });

  final String code;
  final String matchLength;
  final bool youAreHost;
  final bool canStart;
  final String? matchId;
  final List<RoomSeat> seats;

  factory RoomView.fromJson(Map<String, dynamic> json) {
    final rawSeats = json['seats'] as List<dynamic>? ?? const [];
    return RoomView(
      code: json['code'] as String,
      matchLength: json['match_length'] as String? ?? 'short',
      youAreHost: json['you_are_host'] == true,
      canStart: json['can_start'] == true,
      matchId: json['match_id'] as String?,
      seats: [
        for (final seat in rawSeats)
          RoomSeat(
            name: (seat as Map<String, dynamic>)['name'] as String?,
            you: seat['you'] == true,
          ),
      ],
    );
  }
}

class HazaraApi {
  HazaraApi({String? base})
    : base =
          base ??
          const String.fromEnvironment(
            'API_BASE',
            defaultValue: 'http://127.0.0.1:8080',
          );

  final String base;
  GuestSession? session;

  Future<GuestSession> signIn(String name) async {
    final json = await _send('POST', '/api/v1/guest-sessions', {'name': name});
    session = GuestSession(
      token: json['token'] as String,
      playerId: json['player_id'] as String,
      name: json['name'] as String,
    );
    return session!;
  }

  Future<RoomView> createRoom(String matchLength) async {
    final json = await _send('POST', '/api/v1/rooms', {
      'match_length': matchLength,
    });
    return RoomView.fromJson(json);
  }

  Future<RoomView> joinRoom(String code) async {
    final json = await _send('POST', '/api/v1/rooms/join', {'code': code});
    return RoomView.fromJson(json);
  }

  Future<RoomView> fetchRoom(String code) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final json = await _send('GET', '/api/v1/rooms/$code?t=$stamp');
    return RoomView.fromJson(json);
  }

  Future<String> startRoom(String code) async {
    final json = await _send('POST', '/api/v1/rooms/$code/start');
    return json['match_id'] as String;
  }

  Future<RoomPreview?> fetchPreview(String code) async {
    try {
      final json = await _send('GET', '/api/v1/rooms/$code/preview');
      return RoomPreview.fromJson(json);
    } on ApiException {
      return null;
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$base$path');
    late http.Response response;
    try {
      final headers = {
        'content-type': 'application/json',
        'cache-control': 'no-store',
        if (session != null) 'authorization': 'Bearer ${session!.token}',
      };
      switch (method) {
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
        default:
          response = await http.get(uri, headers: headers);
      }
    } catch (_) {
      throw ApiException(
        'Can’t reach the table server at $base. Start it on this computer, then try again.',
      );
    }
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    }
    if (response.statusCode >= 400) {
      throw ApiException(
        json['error'] as String? ?? 'The table could not do that.',
      );
    }
    return json;
  }
}

String lengthLabel(String raw) {
  switch (raw) {
    case 'one_deal':
      return 'One deal';
    case 'short':
      return 'Short · 3 deals';
    case 'full':
      return 'Full · first to 1000';
    default:
      return raw;
  }
}
