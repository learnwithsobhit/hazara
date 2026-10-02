import 'package:flutter/material.dart';

import '../model/playing_card.dart';
import '../net/snapshot.dart';
import '../theme/hazara_theme.dart';

const kTallySetNames = ['Strongest', 'Second', 'Third', 'Spare'];

int handPoints(List<PlayingCard> cards) =>
    cards.fold(0, (sum, card) => sum + card.points);

/// "10 + 10 + 5" from the cards in one hand.
String pointRun(List<PlayingCard> cards) =>
    cards.map((card) => '${card.points}').join(' + ');

int capturedBy(List<BeatView> beats, String name) => beats
    .where((beat) => beat.winner == name)
    .fold(0, (sum, beat) => sum + beat.points);

/// Readable addition for the set on the table, plus the deal counted so far.
class SetScorePanel extends StatelessWidget {
  const SetScorePanel({
    super.key,
    required this.beat,
    required this.revealed,
    required this.revealIndex,
  });

  final BeatView beat;
  final List<BeatView> revealed;
  final int revealIndex;

  @override
  Widget build(BuildContext context) {
    final hands = [for (final row in beat.rows) handPoints(row.cards)];
    final visible = hands.fold(0, (sum, points) => sum + points);
    final counted = revealed.fold(0, (sum, item) => sum + item.points);
    final names = revealed.isEmpty
        ? const <String>[]
        : [for (final row in revealed.first.rows) row.name];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: HazaraColors.feltRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HazaraColors.gold.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Check the points',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 2),
          const Text(
            'Ace, king, queen, jack, and 10 are 10. Every other card is 5.',
            style: TextStyle(color: HazaraColors.creamMuted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          for (final row in beat.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _HandLine(row: row, winner: row.name == beat.winner),
            ),
          if (visible == beat.points && hands.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${hands.join(' + ')} = ${beat.points}',
              style: const TextStyle(
                color: HazaraColors.gold,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
          Text(
            beat.tied
                ? '${beat.winner} captures ${beat.points} (later seat)'
                : '${beat.winner} captures ${beat.points}',
            style: const TextStyle(
              color: HazaraColors.cream,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This deal so far · $counted of 360',
            style: const TextStyle(
              color: HazaraColors.creamMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < revealed.length; i++)
                Text(
                  '${i < kTallySetNames.length ? kTallySetNames[i] : 'Set ${i + 1}'} ${revealed[i].points}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == revealIndex
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: i == revealIndex
                        ? HazaraColors.gold
                        : HazaraColors.creamMuted,
                  ),
                ),
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              children: [
                for (final name in names)
                  Text(
                    '$name +${capturedBy(revealed, name)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HandLine extends StatelessWidget {
  const _HandLine({required this.row, required this.winner});

  final BeatRow row;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    final points = handPoints(row.cards);
    final run = pointRun(row.cards);
    return Text(
      '${row.name}  $run = $points',
      style: TextStyle(
        fontSize: 13,
        fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
        color: winner ? HazaraColors.gold : HazaraColors.cream,
      ),
    );
  }
}

/// One line of the deal ledger on the summary.
class DealLedger extends StatelessWidget {
  const DealLedger({super.key, required this.snap});

  final TableSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final names = [for (final seat in snap.seats) seat.name];
    final dealTotal = snap.beats.fold<int>(0, (sum, beat) => sum + beat.points);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: HazaraColors.feltRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HazaraColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dealTotal == 360
                ? 'This deal adds up to 360'
                : 'This deal · $dealTotal points',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final name in names)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(_playerLine(name)),
            ),
        ],
      ),
    );
  }

  String _playerLine(String name) {
    final parts = [
      for (final beat in snap.beats)
        if (beat.winner == name) beat.points,
    ];
    final deal = parts.fold(0, (sum, points) => sum + points);
    final added = parts.isEmpty ? '0' : parts.join(' + ');
    final seat = snap.seats.where((seat) => seat.name == name).firstOrNull;
    final total = seat != null && seat.seat < snap.scores.length
        ? snap.scores[seat.seat]
        : deal;
    final you = seat?.you == true ? ' (you)' : '';
    if (parts.length <= 1) {
      return '$name$you   +$deal this deal    $total total';
    }
    return '$name$you   $added = $deal    $total total';
  }
}
