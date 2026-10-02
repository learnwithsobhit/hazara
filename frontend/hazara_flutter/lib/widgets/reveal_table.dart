/// Reveal board: oval felt, sets fly to centre, flip, winner glows, spare dims.
library;

import 'package:flutter/material.dart';

import '../engine/hindi.dart';
import '../net/snapshot.dart';
import '../theme/hazara_theme.dart';
import '../theme/layout.dart';
import 'felt_table.dart';
import 'flip_card.dart';
import 'hindi_line.dart';

const kRevealSetNames = ['Strongest', 'Second', 'Third', 'Spare'];

class RevealTable extends StatelessWidget {
  const RevealTable({
    super.key,
    required this.snap,
    required this.clockLabel,
  });

  final TableSnapshot snap;
  final String clockLabel;

  @override
  Widget build(BuildContext context) {
    final beat = snap.beats.isEmpty ? null : snap.beats.first;
    final title = snap.revealIndex < kRevealSetNames.length
        ? kRevealSetNames[snap.revealIndex]
        : 'Set ${snap.revealIndex + 1}';
    final youName = snap.seats
        .where((seat) => seat.you)
        .map((seat) => seat.name)
        .firstOrNull;
    final remaining = (3 - snap.revealIndex).clamp(0, 4);
    final seats = [
      for (final seat in snap.seats)
        TableSeatInfo(
          name: seat.name,
          detail: snap.scores.length > seat.seat
              ? '${snap.scores[seat.seat]} pts'
              : '',
          you: seat.you,
          remainingSets: remaining,
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
                      '$clockLabel · the table moves on together',
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
                        seats: ring,
                        center: _Centre(
                          key: ValueKey('reveal-${snap.dealNo}-${snap.revealIndex}'),
                          beat: beat,
                          reduce: reduce,
                        ),
                      ),
                    ),
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

class _Centre extends StatelessWidget {
  const _Centre({
    super.key,
    required this.beat,
    required this.reduce,
  });

  final BeatView? beat;
  final bool reduce;

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < beat.rows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _RowSet(
                    row: beat.rows[i],
                    winner: beat.rows[i].name == beat.winner,
                    delayMs: reduce ? 0 : 80 * i,
                  ),
                ),
              Text(
                beat.tied
                    ? '${beat.winner} captures ${beat.points} (later seat)'
                    : '${beat.winner} captures ${beat.points}',
                style: const TextStyle(
                  color: HazaraColors.cream,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowSet extends StatelessWidget {
  const _RowSet({
    required this.row,
    required this.winner,
    required this.delayMs,
  });

  final BeatRow row;
  final bool winner;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${row.name} · ${row.label}',
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
                child: FlipRevealCard(
                  card: row.cards[c],
                  width: 36,
                  dimmed: row.spareId == row.cards[c].id,
                  glow: winner && row.spareId != row.cards[c].id,
                  delay: Duration(milliseconds: delayMs + c * 60),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
