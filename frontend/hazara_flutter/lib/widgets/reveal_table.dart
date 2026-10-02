/// Reveal board: oval felt, sets fly to centre, flip, winner glows, spare dims.
library;

import 'package:flutter/material.dart';

import '../engine/hindi.dart';
import '../net/snapshot.dart';
import '../theme/hazara_theme.dart';
import '../theme/layout.dart';
import 'avatar_picker.dart';
import 'felt_table.dart';
import 'flip_card.dart';
import 'hindi_line.dart';
import 'score_tally.dart';

const kRevealSetNames = ['Strongest', 'Second', 'Third', 'Spare'];

class RevealTable extends StatelessWidget {
  const RevealTable({super.key, required this.snap, required this.clockLabel});

  final TableSnapshot snap;
  final String clockLabel;

  @override
  Widget build(BuildContext context) {
    final beat = _currentBeat(snap);
    final title = snap.revealIndex < kRevealSetNames.length
        ? kRevealSetNames[snap.revealIndex]
        : 'Set ${snap.revealIndex + 1}';
    final youName = snap.seats
        .where((seat) => seat.you)
        .map((seat) => seat.name)
        .firstOrNull;
    final seats = [
      for (final seat in snap.seats)
        TableSeatInfo(
          name: seat.name,
          detail: '+${capturedBy(snap.beats, seat.name)}',
          you: seat.you,
          reconnecting: seat.status == 'reconnecting',
          dealer: snap.dealer == seat.seat,
          host: seat.host,
          winner: beat != null && beat.winner == seat.name,
        ),
    ];
    final ring = relativeSeats(seats, snap.you);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tableMaxWidth(context)),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Deal ${snap.dealNo} · $title',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (snap.revealIndex < kHindiSetNames.length)
                      HindiLine(kHindiSetNames[snap.revealIndex], size: 13),
                    const SizedBox(height: 4),
                    Text(
                      'Check the cards. $clockLabel left on this set.',
                      style: const TextStyle(color: HazaraColors.creamMuted),
                    ),
                    if (beat != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _outcome(beat, youName),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: HazaraColors.gold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: PlayTable(
                        seats: const [],
                        center: _Centre(
                          key: ValueKey(
                            'reveal-${snap.dealNo}-${snap.revealIndex}',
                          ),
                          beat: beat,
                          seats: ring,
                          reduce: reduce,
                        ),
                      ),
                    ),
                    if (beat != null) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: SingleChildScrollView(
                          child: SetScorePanel(
                            beat: beat,
                            revealed: snap.beats,
                            revealIndex: snap.revealIndex,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _outcome(BeatView beat, String? youName) {
    final label = beat.rows
        .where((row) => row.name == beat.winner)
        .map((row) => row.label)
        .firstOrNull;
    if (beat.tied) {
      return 'Same ${label ?? 'hand'}. The later player takes this set.';
    }
    if (youName != null && beat.winner == youName) {
      return 'Your ${label ?? 'hand'} takes this set.';
    }
    return '${beat.winner} takes this set with ${label ?? 'their hand'}.';
  }
}

BeatView? _currentBeat(TableSnapshot snap) {
  if (snap.beats.isEmpty) return null;
  final index = snap.revealIndex;
  if (index >= 0 && index < snap.beats.length) return snap.beats[index];
  return snap.beats.last;
}

class _Centre extends StatelessWidget {
  const _Centre({
    super.key,
    required this.beat,
    required this.seats,
    required this.reduce,
  });

  final BeatView? beat;
  final List<TableSeatInfo> seats;
  final bool reduce;

  TableSeatInfo? _seat(String name) {
    for (final seat in seats) {
      if (seat.name == name) return seat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final beat = this.beat;
    if (beat == null) {
      return const Text(
        'The set is on its way.',
        textAlign: TextAlign.center,
        style: TextStyle(color: HazaraColors.creamMuted, fontSize: 13),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: Duration(milliseconds: reduce ? 0 : 520),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 28),
            child: child,
          ),
        );
      },
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < beat.rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _RowSet(
                  row: beat.rows[i],
                  seat: _seat(beat.rows[i].name),
                  winner: beat.rows[i].name == beat.winner,
                  delayMs: reduce ? 0 : 80 * i,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowSet extends StatelessWidget {
  const _RowSet({
    required this.row,
    required this.seat,
    required this.winner,
    required this.delayMs,
  });

  final BeatRow row;
  final TableSeatInfo? seat;
  final bool winner;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final who = seat?.you == true ? '${row.name} (you)' : row.name;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SeatMark(seat: seat, name: row.name, winner: winner),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$who · ${row.label}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: winner ? FontWeight.w800 : FontWeight.w600,
                color: winner ? HazaraColors.gold : HazaraColors.creamMuted,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < row.cards.length; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlipRevealCard(
                          card: row.cards[c],
                          width: 36,
                          dimmed: row.spareId == row.cards[c].id,
                          glow: winner && row.spareId != row.cards[c].id,
                          delay: Duration(milliseconds: delayMs + c * 60),
                        ),
                        Text(
                          '${row.cards[c].points}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: row.cards[c].points == 10
                                ? HazaraColors.gold
                                : HazaraColors.creamMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SeatMark extends StatelessWidget {
  const _SeatMark({
    required this.seat,
    required this.name,
    required this.winner,
  });

  final TableSeatInfo? seat;
  final String name;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final index = seat?.avatar ?? (name.hashCode.abs() % kAvatarCount);
    return SizedBox(
      width: 44,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarChip(index: index, size: 32),
              if (seat?.dealer == true)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: HazaraColors.gold,
                    child: Text(
                      'D',
                      style: TextStyle(
                        fontSize: 9,
                        color: HazaraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (seat != null && seat!.detail.isNotEmpty)
            Text(
              seat!.detail,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: winner ? HazaraColors.gold : HazaraColors.creamMuted,
              ),
            ),
        ],
      ),
    );
  }
}
