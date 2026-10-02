/// Avatar picker — 40 illustrated character faces (CC0 Notionists pack).
library;

import 'package:flutter/material.dart';

import '../theme/hazara_theme.dart';

const kAvatarCount = 40;

/// Fallback palette if a face asset fails to load.
const _symbols = ['♠', '♥', '♦', '♣', '★'];
const _colors = [
  Color(0xFF4E7A6C),
  Color(0xFF7B5EA7),
  Color(0xFFB05E3E),
  Color(0xFF4A7BAF),
  Color(0xFF9B7B3E),
  Color(0xFF6B3E7B),
];

Color avatarColor(int index) =>
    _colors[(index ~/ _symbols.length) % _colors.length];
String avatarSymbol(int index) => _symbols[index % _symbols.length];

String avatarAsset(int index) {
  final n = (index % kAvatarCount) + 1;
  final id = n.toString().padLeft(2, '0');
  return 'assets/avatars/face_$id.png';
}

/// Circular avatar chip. [size] is the outer diameter.
class AvatarChip extends StatelessWidget {
  const AvatarChip({
    super.key,
    required this.index,
    this.size = 44,
    this.selected = false,
    this.onTap,
  });

  final int index;
  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(color: HazaraColors.gold, width: 3)
        : Border.all(color: Colors.transparent, width: 3);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipOval(
          child: Image.asset(
            avatarAsset(index),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: avatarColor(index),
              child: Center(
                child: Text(
                  avatarSymbol(index),
                  style: TextStyle(
                    fontSize: size * 0.42,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet avatar grid. Returns the chosen index or null if dismissed.
Future<int?> showAvatarPicker(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: HazaraColors.feltDeep,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AvatarSheet(current: current),
  );
}

class _AvatarSheet extends StatefulWidget {
  const _AvatarSheet({required this.current});
  final int current;

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current % kAvatarCount;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose your avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: HazaraColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: kAvatarCount,
                itemBuilder: (ctx, index) => AvatarChip(
                  index: index,
                  selected: index == _selected,
                  onTap: () {
                    setState(() => _selected = index);
                    Navigator.of(ctx).pop(_selected);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: HazaraColors.creamMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
