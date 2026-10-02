/// Landing page hero: gold HAZARA wordmark, suit row, and fanned cards.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

/// Face cards in the landing fan — no card back, so every tile shows a rank.
const _fanCards = [
  'assets/cards/king_spades.png',
  'assets/cards/ace_hearts.png',
  'assets/cards/queen_diamonds.png',
  'assets/cards/jack_clubs.png',
  'assets/cards/king_hearts.png',
];

/// Gold suit symbols between wordmark and tagline.
const _suits = '♣  ♦  ♥  ♠';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, this.compact = false});

  /// Invite landing: wordmark only, so Join stays above the fold.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!compact) ...[
          const SizedBox(height: 12),
          const _FanCards(),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 8),
        const Text(
          'HAZARA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 40,
            letterSpacing: 6,
            fontWeight: FontWeight.w900,
            color: HazaraColors.gold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          _suits,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            color: HazaraColors.gold,
            letterSpacing: 2,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 10),
          const Text(
            'Four people. One table. Room code.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: HazaraColors.creamMuted,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pagat Hazari · Bangladesh rules',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: HazaraColors.creamMuted,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FanCards extends StatelessWidget {
  const _FanCards();

  // Ace art is 222×323. Keep that ratio so BoxFit.cover cannot crop faces.
  static const _artW = 222.0;
  static const _artH = 323.0;
  static const _cardW = 80.0;
  static const _cardH = _cardW * _artH / _artW;
  static const _angleStep = 0.15;
  static const _xStep = 38.0;

  @override
  Widget build(BuildContext context) {
    final count = _fanCards.length;
    final mid = (count - 1) / 2;
    final maxAngle = mid * _angleStep;
    final dip = (_cardW / 2) * math.sin(maxAngle) + 18;
    final flare = _cardH * math.sin(maxAngle);
    final width = _cardW + (count - 1) * _xStep + flare + 12;
    final height = _cardH + dip + 12;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.bottomCenter,
        children: List.generate(count, (i) {
          final t = i - mid;
          return Transform.translate(
            offset: Offset(t * _xStep, -dip),
            child: Transform.rotate(
              angle: t * _angleStep,
              alignment: Alignment.bottomCenter,
              child: _CardImage(
                asset: _fanCards[i],
                width: _cardW,
                height: _cardH,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({
    required this.asset,
    required this.width,
    required this.height,
  });

  final String asset;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(160),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: HazaraColors.feltRaised,
          alignment: Alignment.center,
          child: const Text('🃏', style: TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}
