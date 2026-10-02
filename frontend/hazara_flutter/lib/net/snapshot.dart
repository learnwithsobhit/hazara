import '../model/playing_card.dart';

class SeatView {
  SeatView({
    required this.seat,
    required this.name,
    required this.status,
    required this.you,
    this.host = false,
  });

  final int seat;
  final String name;
  final String status;
  final bool you;
  final bool host;

  factory SeatView.fromJson(Map<String, dynamic> json) {
    return SeatView(
      seat: json['seat'] as int? ?? 0,
      name: json['name'] as String? ?? 'Player',
      status: json['status'] as String? ?? 'arranging',
      you: json['you'] == true,
      host: json['host'] == true,
    );
  }
}

class BeatRow {
  BeatRow({
    required this.name,
    required this.label,
    required this.cards,
    required this.spareId,
  });

  final String name;
  final String label;
  final List<PlayingCard> cards;
  final String? spareId;
}

class BeatView {
  BeatView({
    required this.winner,
    required this.points,
    required this.tied,
    required this.rows,
  });

  final String winner;
  final int points;
  final bool tied;
  final List<BeatRow> rows;

  factory BeatView.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] as List<dynamic>? ?? const [];
    return BeatView(
      winner: json['winner'] as String? ?? '',
      points: json['points'] as int? ?? 0,
      tied: json['tied'] == true,
      rows: [
        for (final row in raw)
          BeatRow(
            name: (row as Map<String, dynamic>)['name'] as String? ?? '',
            label: row['label'] as String? ?? '',
            cards: [
              for (final id in row['cards'] as List<dynamic>? ?? const [])
                PlayingCard.parse(id as String),
            ],
            spareId: row['spare'] as String?,
          ),
      ],
    );
  }
}

class TableSnapshot {
  TableSnapshot({
    required this.phase,
    required this.matchLength,
    required this.you,
    required this.dealNo,
    required this.matchOver,
    required this.youAreHost,
    required this.locked,
    required this.hand,
    required this.seats,
    required this.scores,
    required this.beats,
    required this.note,
    required this.arrangeDeadlineMs,
    required this.revealIndex,
    required this.revealUntilMs,
    required this.serverNow,
    required this.protocol,
    required this.autoLocked,
    required this.sealed,
    required this.dealer,
  });

  final String phase;
  final String matchLength;
  final int you;
  final int dealNo;
  final bool matchOver;
  final bool youAreHost;
  final bool locked;
  final List<PlayingCard> hand;
  final List<SeatView> seats;
  final List<int> scores;
  final List<BeatView> beats;
  final String? note;
  final int arrangeDeadlineMs;
  final int revealIndex;
  final int revealUntilMs;
  final int serverNow;
  final int protocol;
  final bool autoLocked;
  final List<List<String>> sealed;
  final int dealer;

  bool get arranging => phase == 'arranging';
  bool get revealing => phase == 'reveal';

  factory TableSnapshot.fromJson(Map<String, dynamic> json) {
    final rawHand = json['hand'] as List<dynamic>? ?? const [];
    final rawSeats = json['seats'] as List<dynamic>? ?? const [];
    final rawScores = json['scores'] as List<dynamic>? ?? const [];
    final rawBeats = json['beats'] as List<dynamic>? ?? const [];
    return TableSnapshot(
      phase: json['phase'] as String? ?? 'arranging',
      matchLength: json['match_length'] as String? ?? 'short',
      you: json['you'] as int? ?? 0,
      dealNo: json['deal_no'] as int? ?? 1,
      matchOver: json['match_over'] == true,
      youAreHost: json['you_are_host'] == true,
      locked: json['locked'] == true,
      hand: [for (final id in rawHand) PlayingCard.parse(id as String)],
      seats: [
        for (final seat in rawSeats)
          SeatView.fromJson(seat as Map<String, dynamic>),
      ],
      scores: [for (final score in rawScores) (score as num).toInt()],
      beats: [
        for (final beat in rawBeats)
          BeatView.fromJson(beat as Map<String, dynamic>),
      ],
      note: json['note'] as String?,
      arrangeDeadlineMs: json['arrange_deadline_ms'] as int? ?? 0,
      revealIndex: json['reveal_index'] as int? ?? 0,
      revealUntilMs: json['reveal_until_ms'] as int? ?? 0,
      serverNow: json['server_now'] as int? ?? 0,
      protocol: json['protocol'] as int? ?? 1,
      autoLocked: json['auto_locked'] == true,
      sealed: [
        for (final group in json['sealed'] as List<dynamic>? ?? const [])
          [for (final id in group as List<dynamic>) id as String],
      ],
      dealer: json['dealer'] as int? ?? 0,
    );
  }
}

String statusWord(String raw) {
  switch (raw) {
    case 'arranging':
      return 'Arranging';
    case 'ready':
      return 'Ready';
    case 'reconnecting':
      return 'Reconnecting';
    case 'auto':
      return 'Locked';
    default:
      return raw;
  }
}

/// A record of one completed deal — used in deal-by-deal history view.
class DealRecord {
  const DealRecord({
    required this.dealNo,
    required this.playerNames,
    required this.scoresBefore,
    required this.scoresAfter,
    required this.beats,
  });

  final int dealNo;
  final List<String> playerNames;
  final List<int> scoresBefore;
  final List<int> scoresAfter;
  final List<BeatView> beats;

  /// Points each player earned in THIS deal only.
  List<int> get dealDeltas {
    if (scoresBefore.length != scoresAfter.length) {
      return List.filled(scoresAfter.length, 0);
    }
    return [
      for (var i = 0; i < scoresAfter.length; i++)
        scoresAfter[i] - (i < scoresBefore.length ? scoresBefore[i] : 0),
    ];
  }
}
