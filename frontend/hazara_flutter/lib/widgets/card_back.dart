/// CardBack widget — shows the felt-patterned back of a card.
library;

import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 32, this.height = 48});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Try the bundled back image; fall back to a drawn card-back.
    return SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        'assets/cards/back.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
  errorBuilder: (context, error, stack) => _DrawnBack(width: width, height: height),
      ),
    );
  }
}

class _DrawnBack extends StatelessWidget {
  const _DrawnBack({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HazaraColors.feltDeep,
        borderRadius: BorderRadius.circular(width * 0.1),
        border: Border.all(color: HazaraColors.gold.withAlpha(80), width: 1),
      ),
      child: Center(
        child: Text(
          '♠',
          style: TextStyle(
            fontSize: width * 0.45,
            color: HazaraColors.gold.withAlpha(120),
          ),
        ),
      ),
    );
  }
}

/// A fan/stack of [count] face-down cards used to represent an opponent's hand.
class CardBackStack extends StatelessWidget {
  const CardBackStack({
    super.key,
    required this.count,
    this.cardWidth = 28,
    this.cardHeight = 42,
    this.spread = 6.0,
  });

  final int count;
  final double cardWidth;
  final double cardHeight;
  final double spread;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final visibleCount = count.clamp(1, 7);
    final totalWidth = cardWidth + spread * (visibleCount - 1);
    return SizedBox(
      width: totalWidth,
      height: cardHeight,
      child: Stack(
        children: [
          for (var i = 0; i < visibleCount; i++)
            Positioned(
              left: i * spread,
              child: CardBack(width: cardWidth, height: cardHeight),
            ),
        ],
      ),
    );
  }
}
