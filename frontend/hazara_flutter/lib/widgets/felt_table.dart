/// Oval felt play-table: wood rim, radial gradient, seats on the arc.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';
import 'avatar_picker.dart';
import 'card_back.dart';

/// One seat around the table, already rotated so index 0 is "you" (bottom).
class TableSeatInfo {
  const TableSeatInfo({
    required this.name,
    this.detail = '',
    this.you = false,
    this.remainingSets = 0,
    this.reconnecting = false,
    this.dealer = false,
    this.host = false,
    this.winner = false,
    this.avatarIndex,
  });

  final String name;
  final String detail;
  final bool you;
  final int remainingSets;
  final bool reconnecting;
  final bool dealer;
  final bool host;
  final bool winner;
  final int? avatarIndex;

  int get avatar => avatarIndex ?? (name.hashCode.abs() % kAvatarCount);
}

/// Relative ring order: you, left, across, right.
List<TableSeatInfo> relativeSeats(List<TableSeatInfo> absolute, int youSeat) {
  if (absolute.isEmpty) return absolute;
  return [
    for (var step = 0; step < absolute.length; step++)
      absolute[(youSeat + step) % absolute.length],
  ];
}

/// Alignment on the oval for a relative seat (0=you/bottom … clockwise).
Alignment seatAlignment(int relativeIndex, {int count = 4}) {
  // Bottom, then clockwise: left, top, right.
  const four = [
    Alignment(0, 0.92),
    Alignment(-0.92, 0.05),
    Alignment(0, -0.92),
    Alignment(0.92, 0.05),
  ];
  if (count == 4 && relativeIndex < 4) return four[relativeIndex];
  final t = (relativeIndex / count) * 2 * math.pi + math.pi / 2;
  return Alignment(math.cos(t), math.sin(t));
}

class FeltOvalPainter extends CustomPainter {
  const FeltOvalPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.92,
      height: size.height * 0.88,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0xFF2E7D32),
          Color(0xFF1B5E20),
          HazaraColors.feltDeep,
        ],
        stops: const [0.0, 0.55, 1.0],
        radius: 0.9,
      ).createShader(rect);
    canvas.drawOval(rect, paint);

    final rim = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawOval(rect, rim);

    final inner = Paint()
      ..color = HazaraColors.gold.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawOval(rect.deflate(5), inner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full play-table used during reveal (and optionally arrangement).
class PlayTable extends StatelessWidget {
  const PlayTable({
    super.key,
    required this.seats,
    this.center,
    this.aspectRatio = 1.35,
    this.compact = false,
  });

  /// Relative order: index 0 is the viewer (bottom).
  final List<TableSeatInfo> seats;
  final Widget? center;
  final double aspectRatio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 80 : 160),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: CustomPaint(
          painter: const FeltOvalPainter(),
          child: Stack(
            children: [
              Center(
                child: center ??
                    Text(
                      'HAZARA',
                      style: TextStyle(
                        fontSize: compact ? 12 : 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        color: HazaraColors.gold.withAlpha(110),
                      ),
                    ),
              ),
              for (var i = 0; i < seats.length; i++)
                Align(
                  alignment: seatAlignment(i, count: seats.length),
                  child: _ArcSeat(info: seats[i], compact: compact),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcSeat extends StatelessWidget {
  const _ArcSeat({required this.info, required this.compact});

  final TableSeatInfo info;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 48.0;
    return Padding(
      padding: EdgeInsets.all(compact ? 2 : 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: info.reconnecting ? 0.45 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (info.winner)
                        BoxShadow(
                          color: HazaraColors.gold.withAlpha(180),
                          blurRadius: 16,
                        ),
                      if (info.you)
                        BoxShadow(
                          color: HazaraColors.you.withAlpha(90),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: AvatarChip(index: info.avatar, size: size),
                ),
              ),
              if (info.dealer)
                const Positioned(
                  right: -4,
                  top: -4,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: HazaraColors.gold,
                    child: Text(
                      'D',
                      style: TextStyle(
                        fontSize: 10,
                        color: HazaraColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (info.host)
                const Positioned(
                  left: -6,
                  top: -8,
                  child: Text('♔', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(120),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  info.you ? '${info.name} (you)' : info.name,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w700,
                    color: info.you ? HazaraColors.you : HazaraColors.cream,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (info.detail.isNotEmpty)
                  Text(
                    info.detail,
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      color: HazaraColors.creamMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (info.remainingSets > 0 && !compact) ...[
            const SizedBox(height: 4),
            CardBackStack(
              count: info.remainingSets,
              cardWidth: 20,
              cardHeight: 30,
              spread: 5,
            ),
          ],
        ],
      ),
    );
  }
}
