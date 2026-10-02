/// Victory / podium screen shown when a match ends.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../net/snapshot.dart';
import '../net/api_client.dart' show lengthLabel;
import '../theme/hazara_theme.dart';
import '../theme/layout.dart';
import '../widgets/share_sheet.dart';

class VictoryScreen extends StatefulWidget {
  const VictoryScreen({
    super.key,
    required this.snap,
    required this.onRematch,
    required this.onHome,
    this.dealHistory = const [],
  });

  final TableSnapshot snap;
  final VoidCallback onRematch;
  final VoidCallback onHome;
  final List<DealRecord> dealHistory;

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();

  final _rng = math.Random(42);
  late final List<_Particle> _particles = List.generate(48, (_) {
    return _Particle(
      x: _rng.nextDouble(),
      delay: _rng.nextDouble() * 0.5,
      speed: 0.3 + _rng.nextDouble() * 0.6,
      size: 5 + _rng.nextDouble() * 9,
      color: [
        HazaraColors.gold,
        const Color(0xFFFF6B6B),
        const Color(0xFF4ECDC4),
        const Color(0xFFFFE66D),
        const Color(0xFF95E1D3),
        Colors.white,
      ][_rng.nextInt(6)],
      spin: (_rng.nextDouble() - 0.5) * 10,
    );
  });

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked(widget.snap);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Confetti burst (if animations enabled)
          if (!reduceMotion)
            AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(
                  t: _confetti.value,
                  particles: _particles,
                ),
              ),
            ),
          // Main content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tableMaxWidth(context)),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HAZARA',
                          style: TextStyle(
                            fontSize: 20,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Match finished · ${lengthLabel(widget.snap.matchLength)}',
                          style: const TextStyle(
                            color: HazaraColors.creamMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          label:
                              '${ranked.first.name} wins with ${ranked.first.score} points',
                          child: Text(
                            '${ranked.first.name} wins!',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: HazaraColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Podium
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _Podium(ranked: ranked),
                  ),
                  const SizedBox(height: 24),

                  // Score list + deal history
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        for (var i = 0; i < ranked.length; i++)
                          Semantics(
                            label:
                                '${_medalLabel(i)} ${ranked[i].name}: ${ranked[i].score} points',
                            child: _ScoreRow(
                              rank: i + 1,
                              entry: ranked[i],
                              you: ranked[i].you,
                            ),
                          ),
                        if (widget.dealHistory.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _DealHistorySection(
                            dealHistory: widget.dealHistory,
                            playerNames: [
                              for (final s in widget.snap.seats) s.name
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.snap.youAreHost)
                          Semantics(
                            button: true,
                            label: 'Play again',
                            child: FilledButton(
                              key: const ValueKey('rematch'),
                              style: FilledButton.styleFrom(
                                backgroundColor: HazaraColors.gold,
                                foregroundColor: HazaraColors.ink,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              onPressed: widget.onRematch,
                              child: const Text('Play again'),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Waiting for the host to play again.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Semantics(
                          button: true,
                          label: 'Share result',
                          child: OutlinedButton(
                            key: const ValueKey('share-result'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HazaraColors.gold,
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: HazaraColors.gold),
                            ),
                            onPressed: () {
                              final lines = [
                                for (final e in ranked)
                                  '${e.name} ${e.score}',
                              ].join(' · ');
                              showHazaraShareSheet(
                                context: context,
                                customText:
                                    '${ranked.first.name} won HAZARA — $lines',
                              );
                            },
                            child: const Text('Share result'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          button: true,
                          label: 'Go to home',
                          child: OutlinedButton(
                            key: const ValueKey('match-home'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HazaraColors.cream,
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: HazaraColors.line),
                            ),
                            onPressed: widget.onHome,
                            child: const Text('Home'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),        // closes inner SafeArea
    ],          // closes Stack children
  ),            // closes Stack (body)
);              // closes Scaffold
  }
}

/// Sort seats by score descending (ties broken by seat order).
List<_RankEntry> _ranked(TableSnapshot snap) {
  final entries = [
    for (var i = 0; i < snap.seats.length; i++)
      _RankEntry(
        name: snap.seats[i].name,
        score: snap.scores[i],
        you: snap.seats[i].you,
        seat: i,
      ),
  ]..sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      return cmp != 0 ? cmp : a.seat.compareTo(b.seat);
    });
  return entries;
}

String _medalLabel(int rank) {
  switch (rank) {
    case 0:
      return '🥇 1st';
    case 1:
      return '🥈 2nd';
    case 2:
      return '🥉 3rd';
    default:
      return '${rank + 1}th';
  }
}

class _RankEntry {
  const _RankEntry({
    required this.name,
    required this.score,
    required this.you,
    required this.seat,
  });
  final String name;
  final int score;
  final bool you;
  final int seat;
}

class _Podium extends StatelessWidget {
  const _Podium({required this.ranked});
  final List<_RankEntry> ranked;

  @override
  Widget build(BuildContext context) {
    // Podium order: 2nd (left), 1st (centre, tallest), 3rd (right).
    final positions = ranked.length >= 3
        ? [ranked[1], ranked[0], ranked[2]]
        : [null, ranked.first, null];
    final heights = [64.0, 96.0, 48.0]; // 2nd, 1st, 3rd
    final labels = ['🥈', '🥇', '🥉'];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          final entry = positions[i];
          if (entry == null) return const Expanded(child: SizedBox());
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  entry.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        entry.you ? FontWeight.w700 : FontWeight.normal,
                    color:
                        entry.you ? HazaraColors.gold : HazaraColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                _WinnerBounce(
                  active: i == 1,
                  child: Text(
                    labels[i],
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(height: 4),
                _WinnerBounce(
                  active: i == 1,
                  child: Container(
                    height: heights[i],
                    decoration: BoxDecoration(
                      color: i == 1
                          ? HazaraColors.gold.withAlpha(50)
                          : HazaraColors.feltRaised,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      border: i == 1
                          ? Border.all(
                              color: HazaraColors.gold.withAlpha(120),
                            )
                          : Border.all(color: HazaraColors.line),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.score}',
                      style: TextStyle(
                        fontSize: i == 1 ? 20 : 16,
                        fontWeight: FontWeight.w700,
                        color: i == 1 ? HazaraColors.gold : HazaraColors.cream,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WinnerBounce extends StatelessWidget {
  const _WinnerBounce({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active || MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: child,
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.rank,
    required this.entry,
    required this.you,
  });

  final int rank;
  final _RankEntry entry;
  final bool you;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              _medalLabel(rank - 1),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              you ? '${entry.name} (you)' : entry.name,
              style: TextStyle(
                color: you ? HazaraColors.you : HazaraColors.cream,
                fontWeight: you ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${entry.score} pts',
            style: const TextStyle(
              color: HazaraColors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Deal History ─────────────────────────────────────────────────────────────

class _DealHistorySection extends StatefulWidget {
  const _DealHistorySection({
    required this.dealHistory,
    required this.playerNames,
  });

  final List<DealRecord> dealHistory;
  final List<String> playerNames;

  @override
  State<_DealHistorySection> createState() => _DealHistorySectionState();
}

class _DealHistorySectionState extends State<_DealHistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                const Text(
                  'Deal-by-deal breakdown',
                  style: TextStyle(
                    color: HazaraColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: HazaraColors.gold,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.dealHistory.map(
            (record) => _DealCard(
              record: record,
              playerNames: widget.playerNames,
            ),
          ),
      ],
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.record, required this.playerNames});

  final DealRecord record;
  final List<String> playerNames;

  @override
  Widget build(BuildContext context) {
    final deltas = record.dealDeltas;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: HazaraColors.feltDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HazaraColors.gold.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deal header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              'Deal ${record.dealNo}',
              style: const TextStyle(
                color: HazaraColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          // Player scores for this deal
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < record.playerNames.length; i++)
                  _ScoreChip(
                    name: record.playerNames[i],
                    delta: i < deltas.length ? deltas[i] : 0,
                  ),
              ],
            ),
          ),
          // Beat list
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          for (final beat in record.beats) _BeatLine(beat: beat),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.name, required this.delta});

  final String name;
  final int delta;

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: positive
            ? HazaraColors.gold.withAlpha(30)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: positive
              ? HazaraColors.gold.withAlpha(80)
              : Colors.white.withAlpha(30),
        ),
      ),
      child: Text(
        '$name  ${positive ? '+' : ''}$delta',
        style: TextStyle(
          fontSize: 12,
          color: positive ? HazaraColors.gold : HazaraColors.creamMuted,
          fontWeight: positive ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }
}

class _BeatLine extends StatelessWidget {
  const _BeatLine({required this.beat});

  final BeatView beat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              beat.winner,
              style: const TextStyle(
                color: HazaraColors.cream,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            beat.tied ? '${beat.points} pts (tied)' : '+${beat.points} pts',
            style: TextStyle(
              color: beat.tied ? HazaraColors.creamMuted : HazaraColors.gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (beat.rows.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              beat.rows.map((r) => r.label).where((l) => l.isNotEmpty).join(', '),
              style: const TextStyle(
                color: HazaraColors.creamMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Confetti ────────────────────────────────────────────────────────────────

class _Particle {
  _Particle({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
  });
  final double x;
  final double delay;
  final double speed;
  final double size;
  final Color color;
  final double spin;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.t, required this.particles});
  final double t;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final localT = ((t - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (localT <= 0) continue;
      final fallT = localT * p.speed;
      final y = fallT * size.height * 1.3 - size.height * 0.15;
      final dx = p.x * size.width +
          math.sin(localT * 6 + p.x * 3) * 30;
      final opacity = (1.0 - localT * 0.9).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withAlpha((opacity * 255).round());
      canvas.save();
      canvas.translate(dx, y);
      canvas.rotate(localT * p.spin);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
