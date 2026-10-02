import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/arrangement.dart';
import '../engine/classifier.dart';
import '../engine/hindi.dart';
import '../model/playing_card.dart';
import '../theme/hazara_theme.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/card_face.dart';
import '../widgets/felt_table.dart';
import '../widgets/hindi_line.dart';
import 'settings_screen.dart';

class SeatChip {
  const SeatChip({
    required this.name,
    required this.detail,
    this.you = false,
    this.remainingSets = 0,
    this.reconnecting = false,
    this.dealer = false,
    this.host = false,
  });

  final String name;
  final String detail;
  final bool you;
  final int remainingSets;
  final bool reconnecting;
  final bool dealer;
  final bool host;
}

class ArrangementScreen extends StatefulWidget {
  const ArrangementScreen({
    super.key,
    this.showCoach = true,
    this.hand,
    this.live = false,
    this.banner,
    this.seats,
    this.note,
    this.arrangeDeadlineMs,
    this.clockOffsetMs = 0,
    this.serverLocked = false,
    this.autoLocked = false,
    this.sealedSets,
    this.rejectNonce = 0,
    this.rejectMessage,
    this.onDraft,
    this.onLocked,
  });

  final bool showCoach;
  final List<PlayingCard>? hand;
  final bool live;
  final String? banner;
  final List<SeatChip>? seats;
  final String? note;
  final int? arrangeDeadlineMs;
  final int clockOffsetMs;
  final bool serverLocked;
  final bool autoLocked;
  final List<List<PlayingCard>>? sealedSets;
  final int rejectNonce;
  final String? rejectMessage;
  final void Function(List<List<PlayingCard>> sets)? onDraft;
  final void Function(List<List<PlayingCard>> sets)? onLocked;

  @override
  State<ArrangementScreen> createState() => _ArrangementScreenState();
}

class _ArrangementScreenState extends State<ArrangementScreen>
    with SingleTickerProviderStateMixin {
  late final ArrangementModel _model;
  late final AnimationController _lock;
  bool _holding = false;
  bool _tableOpen = false;
  int? _coach;
  Timer? _draftTimer;
  Timer? _clock;
  String? _remaining;
  String? _draftWord;
  int _seenReject = 0;

  static const _coachLines = [
    'Tap cards, then tap a set.',
    'Tap a card, then tap where it should go. Back to hand frees a slot. Drop on a card to swap.',
    'Ready locks the hand.',
  ];

  static const _coachHindi = [
    'पत्ती चुनें, फिर सेट पर टैप करें।',
    'पत्ती चुनें, फिर जगह पर टैप करें। हाथ में वापस से जगह खाली। पत्ती पर छोड़ें तो बदलें।',
    'रेडी दबाने पर हाथ बंद हो जाता है।',
  ];

  @override
  void initState() {
    super.initState();
    _model = ArrangementModel(hand: widget.hand);
    _applyServerLock();
    _coach = widget.showCoach ? 0 : null;
    _lock = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.live) {
      _syncClock();
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(_syncClock);
      });
    }
  }

  @override
  void didUpdateWidget(ArrangementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.serverLocked && !_model.locked) {
      _cancelHold();
      setState(_applyServerLock);
    } else if (widget.serverLocked) {
      _applyServerLock();
    }
    if (widget.rejectNonce != _seenReject && !widget.serverLocked) {
      _seenReject = widget.rejectNonce;
      _cancelHold();
      setState(() {
        _model.unlockPreview();
        _model.lastError = widget.rejectMessage;
      });
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _clock?.cancel();
    _lock.dispose();
    super.dispose();
  }

  String _sealKey = '';

  void _applyServerLock() {
    if (!widget.serverLocked &&
        (widget.sealedSets == null || widget.sealedSets!.isEmpty)) {
      return;
    }
    final placed = widget.sealedSets;
    if (placed == null || placed.isEmpty) {
      if (!_model.locked) _model.seal();
      return;
    }
    final key = placed
        .map((set) => set.map((card) => card.id).join(','))
        .join('|');
    if (key == _sealKey && _model.locked) return;
    _sealKey = key;
    _model.restoreLocked(placed);
  }

  void _syncClock() {
    final deadline = widget.arrangeDeadlineMs;
    if (deadline == null || deadline == 0 || _model.locked) {
      _remaining = null;
      return;
    }
    final leftMs =
        deadline -
        (DateTime.now().millisecondsSinceEpoch + widget.clockOffsetMs);
    if (leftMs <= 0) {
      _remaining = '0:00';
      return;
    }
    final total = (leftMs / 1000).ceil();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    _remaining = '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _scheduleDraft() {
    if (!widget.live || widget.onDraft == null || _model.locked) return;
    _draftTimer?.cancel();
    setState(() => _draftWord = 'Unsaved');
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || _model.locked) return;
      widget.onDraft?.call([
        for (final set in _model.sets) List<PlayingCard>.from(set),
      ]);
      setState(() => _draftWord = 'Saved');
    });
  }

  bool get _busy => _holding || _model.locked;

  void _edit(VoidCallback change) {
    if (_busy) return;
    setState(() {
      change();
      if (_coach == 0 && _model.placedCount > 0) _coach = 1;
    });
    if (TableSettings.haptics.value) {
      HapticFeedback.selectionClick();
    }
    _scheduleDraft();
  }

  void _startHold() {
    if (!_model.isLegal || _busy) return;
    setState(() => _holding = true);
    _lock.forward(from: 0).then((_) {
      if (!mounted || _lock.status != AnimationStatus.completed) return;
      setState(() {
        _model.seal();
        _holding = false;
        _coach = null;
      });
      widget.onLocked?.call([
        for (final set in _model.sets) List<PlayingCard>.from(set),
      ]);
    });
  }

  void _cancelHold() {
    _lock.stop();
    _lock.value = 0;
    if (_holding) setState(() => _holding = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final coachH = _coach == null ? 0.0 : 48.0;
                  final hasSeats =
                      widget.seats != null && widget.seats!.isNotEmpty;
                  final tableH = !hasSeats ? 96.0 : (_tableOpen ? 176.0 : 58.0);
                  final trayBudget =
                      (constraints.maxHeight - 46 - 72 - coachH - tableH - 96)
                          .clamp(64.0, 170.0);
                  final byHeight = (trayBudget - 28) / 2 / 1.45;
                  final byWidth = (constraints.maxWidth - 56) / 7;
                  final raw = byHeight < byWidth ? byHeight : byWidth;
                  final cardW = raw.clamp(26.0, 52.0);
                  return Column(
                    children: [
                      _header(),
                      _score(),
                      if (_coach != null) _coachCard(),
                      Expanded(child: _setList()),
                      _tray(cardW),
                      _dock(reduce),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HazaraColors.felt,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                'Combinations',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8),
              Text(
                'Points are the cards you capture. The combination only decides who captures them.',
              ),
              SizedBox(height: 16),
              Text('Troy — three aces, or any three of a kind. Highest.'),
              SizedBox(height: 8),
              Text('Colour run — A–K–Q of one suit, then A–2–3, then K–Q–J.'),
              SizedBox(height: 8),
              Text('Run — the same sequence in mixed suits.'),
              SizedBox(height: 8),
              Text(
                'Colour — three cards of one suit, not a run. 2–A–K is colour.',
              ),
              SizedBox(height: 8),
              Text('Pair — two of a kind, with one spare card.'),
              SizedBox(height: 8),
              Text('Indi — three cards with no pair, run, or colour.'),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'HAZARA',
              style: TextStyle(
                fontSize: 20,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('combinations'),
            tooltip: 'Combinations',
            onPressed: _openHelp,
            icon: const Icon(Icons.help_outline),
          ),
          if (!widget.live)
            TextButton(
              key: const ValueKey('reset'),
              onPressed: () {
                _cancelHold();
                setState(() {
                  _model.reset();
                  _coach = widget.showCoach ? 0 : null;
                });
              },
              child: const Text('Reset'),
            ),
        ],
      ),
    );
  }

  Widget _score() {
    final seats = widget.seats;
    final hasSeats = seats != null && seats.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.banner ??
                      'On this device · a live table needs four people',
                  style: const TextStyle(
                    color: HazaraColors.creamMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              if (hasSeats)
                TextButton.icon(
                  key: const ValueKey('toggle-table'),
                  onPressed: () => setState(() => _tableOpen = !_tableOpen),
                  icon: Icon(
                    _tableOpen
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                  ),
                  label: Text(_tableOpen ? 'Hide table' : 'Show table'),
                  style: TextButton.styleFrom(
                    foregroundColor: HazaraColors.creamMuted,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (_remaining != null)
            Text(
              '$_remaining left to arrange',
              style: const TextStyle(color: HazaraColors.gold, fontSize: 12),
            ),
          if (_model.locked)
            Text(
              widget.autoLocked ? 'Auto-locked' : 'Locked',
              style: const TextStyle(color: HazaraColors.gold, fontSize: 12),
            )
          else if (_draftWord != null)
            Text(
              _draftWord!,
              style: const TextStyle(color: HazaraColors.gold, fontSize: 12),
            ),
          if (widget.note != null)
            Text(
              widget.note!,
              style: const TextStyle(color: HazaraColors.gold, fontSize: 12),
            ),
          const SizedBox(height: 6),
          if (hasSeats)
            _tableOpen
                ? PlayTable(
                    seats: [
                      for (final seat in seats)
                        TableSeatInfo(
                          name: seat.name,
                          detail: seat.detail,
                          you: seat.you,
                          remainingSets: seat.remainingSets,
                          reconnecting: seat.reconnecting,
                          dealer: seat.dealer,
                          host: seat.host,
                        ),
                    ],
                    compact: true,
                    aspectRatio: 2.85,
                  )
                : _seatStrip(seats)
          else
            Row(
              children: [
                _scorePill('You', '0', highlight: true),
                _scorePill('Left', 'Waiting'),
                _scorePill('Across', 'Waiting'),
                _scorePill('Right', 'Waiting'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _seatStrip(List<SeatChip> seats) {
    return Row(
      children: [
        for (final seat in seats)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  AvatarChip(
                    index: seat.name.hashCode.abs() % kAvatarCount,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seat.you ? 'You' : seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: seat.you ? HazaraColors.you : HazaraColors.cream,
                    ),
                  ),
                  Text(
                    seat.detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      color: HazaraColors.creamMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _scorePill(String name, String detail, {bool highlight = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: highlight ? const Color(0x332E8F7E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlight ? HazaraColors.you : HazaraColors.line,
          ),
        ),
        child: Column(
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: highlight ? HazaraColors.you : HazaraColors.creamMuted,
              ),
            ),
            Text(
              detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coachCard() {
    final step = _coach!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(
          color: HazaraColors.cream,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tip ${step + 1} of 3 · ${_coachLines[step]}',
                    style: const TextStyle(
                      color: HazaraColors.ink,
                      fontSize: 13,
                    ),
                  ),
                  HindiLine(
                    _coachHindi[step],
                    size: 12,
                    color: const Color(0xFF1F4D3F),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('skip-tips'),
              onPressed: () => setState(() => _coach = null),
              child: const Text(
                'Skip',
                style: TextStyle(color: Color(0xFF1F4D3F)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setList({bool scroll = true}) {
    final warning = _model.orderWarning;
    final children = <Widget>[
      if (warning != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: _WarningBanner(
            text: warning,
            hindi: _model.firstInversion == null
                ? null
                : hindiOrderWarning(_model.firstInversion!),
            onSwap: _model.firstInversion == 2 || _busy
                ? null
                : () => _edit(() {
                    _model.swapFirstInversion();
                    if (_coach == 1) _coach = 2;
                  }),
          ),
        ),
      for (var i = 0; i < 4; i++)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: _setRow(i),
        ),
    ];
    if (!scroll) {
      return Column(children: children);
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      children: children,
    );
  }

  Widget _setRow(int index) {
    final cards = _model.sets[index];
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        if (_busy) return false;
        final pile = details.data.pile;
        if (pile != null) return pile != index;
        final card = details.data.card;
        return card != null && !_model.sets[index].contains(card);
      },
      onAcceptWithDetails: (details) {
        final pile = details.data.pile;
        if (pile != null) {
          _edit(() => _model.swapPiles(pile, index));
          return;
        }
        final card = details.data.card;
        if (card == null) return;
        _edit(() => _model.dropCard(card, index));
      },
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          decoration: BoxDecoration(
            color: HazaraColors.feltRaised,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hot ? HazaraColors.gold : HazaraColors.line,
              width: hot ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _setTitle(index),
              if (cards.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final card in cards)
                        _cardTarget(card, 36, dimmed: _isSpare(index, card)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _setTitle(int index) {
    final title = Semantics(
      button: true,
      label: '${kSetNames[index]}. ${_model.setStatus(index)}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('set-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : () => _edit(() => _model.activateSet(index)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  kSetNames[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                HindiLine(kHindiSetNames[index], size: 12),
              ],
            ),
            Text(
              _model.setStatus(index),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: HazaraColors.cream, fontSize: 12),
            ),
            if (_hindiDetail(index) != null)
              HindiLine(_hindiDetail(index)!, size: 11),
          ],
        ),
      ),
    );
    if (_busy || index > 2) {
      return SizedBox(width: double.infinity, child: title);
    }
    return SizedBox(
      width: double.infinity,
      child: Draggable<_DragPayload>(
        data: _DragPayload.pile(index),
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: HazaraColors.feltRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HazaraColors.gold),
            ),
            child: Text(
              kSetNames[index],
              style: const TextStyle(
                color: HazaraColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: title),
        child: title,
      ),
    );
  }

  String? _hindiDetail(int index) {
    final cards = _model.sets[index];
    return hindiSetDetail(
      placed: cards.length,
      size: kSetSizes[index],
      status: _model.setStatus(index),
    );
  }

  bool _isSpare(int index, PlayingCard card) {
    if (index != 3) return false;
    final combo = evaluateSet(_model.sets[3]);
    return combo?.spare == card;
  }

  Widget _cardTarget(PlayingCard card, double width, {bool dimmed = false}) {
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        final moving = details.data.card;
        return !_busy && moving != null && moving != card;
      },
      onAcceptWithDetails: (details) {
        final moving = details.data.card;
        if (moving == null) return;
        _edit(() => _model.swapCards(moving, card));
      },
      builder: (context, candidate, rejected) {
        return _draggable(
          card,
          width,
          dimmed: dimmed,
          hot: candidate.isNotEmpty,
        );
      },
    );
  }

  Widget _tray(double cardW) {
    final cards = _model.tray;
    final canReturn = _model.canReturnSelection;
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        final card = details.data.card;
        return !_busy && card != null && !_model.tray.contains(card);
      },
      onAcceptWithDetails: (details) {
        final card = details.data.card;
        if (card == null) return;
        _edit(() => _model.moveToTray(card));
      },
      builder: (context, candidate, rejected) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          decoration: BoxDecoration(
            color: HazaraColors.feltDeep,
            border: Border(
              top: BorderSide(
                color: hot ? HazaraColors.gold : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _busy || !canReturn
                          ? null
                          : () => _edit(_model.returnSelectedToTray),
                      child: Text(
                        cards.isEmpty
                            ? 'All 13 cards are in sets'
                            : 'Your cards',
                        style: const TextStyle(
                          color: HazaraColors.creamMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (canReturn)
                    TextButton(
                      key: const ValueKey('back-to-hand'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: HazaraColors.gold,
                      ),
                      onPressed: _busy
                          ? null
                          : () => _edit(_model.returnSelectedToTray),
                      child: const Text('Back to hand'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (cards.isNotEmpty)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final card in cards) _cardTarget(card, cardW),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _draggable(
    PlayingCard card,
    double width, {
    bool dimmed = false,
    bool hot = false,
  }) {
    final face = CardFace(
      card: card,
      width: width,
      selected: _model.selected.contains(card),
      dimmed: dimmed,
      cardKey: ValueKey('card-${card.id}'),
      onTap: _busy ? null : () => _edit(() => _model.tapCard(card)),
    );
    final shown = hot
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HazaraColors.gold, width: 2),
            ),
            child: face,
          )
        : face;
    if (_busy) return RepaintBoundary(child: shown);
    return RepaintBoundary(
      child: Draggable<_DragPayload>(
        data: _DragPayload.card(card),
        feedback: Material(
          color: Colors.transparent,
          child: CardFace(card: card, width: width, selected: true),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: IgnorePointer(child: shown),
        ),
        child: shown,
      ),
    );
  }

  Widget _dock(bool reduce) {
    final reason = _model.readyReason;
    final selected = _model.selected.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: HazaraColors.felt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_model.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _model.lastError!,
                style: const TextStyle(color: HazaraColors.gold, fontSize: 13),
              ),
            ),
          if (_model.locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.live
                    ? (widget.autoLocked
                          ? 'Auto-locked. This hand stays as the server saved it.'
                          : 'Hand locked. Waiting for the table.')
                    : 'Hand locked on this device.',
              ),
            ),
          if (!_model.locked)
            Row(
              children: [
                TextButton(
                  key: const ValueKey('undo'),
                  onPressed: _model.canUndo && !_busy
                      ? () {
                          setState(_model.undo);
                          _scheduleDraft();
                        }
                      : null,
                  child: const Text('Undo'),
                ),
                TextButton(
                  key: const ValueKey('sort'),
                  onPressed: _busy
                      ? null
                      : () => _edit(() {
                          _model.sortSets();
                          if (_coach == 1) _coach = 2;
                        }),
                  child: const Text('Sort sets'),
                ),
                const Spacer(),
                if (selected > 0)
                  Text(
                    '$selected selected',
                    style: const TextStyle(
                      fontSize: 12,
                      color: HazaraColors.creamMuted,
                    ),
                  ),
              ],
            ),
          if (!_model.locked && reason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason, style: const TextStyle(fontSize: 13)),
                  if (reason == 'Place all 13 cards')
                    const HindiLine(kHindiPlaceAll, size: 12)
                  else if (_model.firstInversion != null)
                    HindiLine(
                      hindiOrderWarning(_model.firstInversion!),
                      size: 12,
                    ),
                ],
              ),
            ),
          if (_holding && !reduce)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnimatedBuilder(
                animation: _lock,
                builder: (context, _) => LinearProgressIndicator(
                  value: _lock.value,
                  minHeight: 4,
                  color: HazaraColors.gold,
                  backgroundColor: HazaraColors.line,
                ),
              ),
            ),
          if (_model.locked && !widget.live)
            OutlinedButton(
              key: const ValueKey('rearrange'),
              onPressed: () => setState(_model.unlockPreview),
              child: const Text('Rearrange'),
            )
          else if (!_model.locked)
            FilledButton(
              key: const ValueKey('ready'),
              style: FilledButton.styleFrom(
                backgroundColor: _model.isLegal
                    ? HazaraColors.gold
                    : const Color(0xFF2C564A),
                foregroundColor: _model.isLegal
                    ? HazaraColors.ink
                    : HazaraColors.cream,
                disabledBackgroundColor: const Color(0xFF2C564A),
                disabledForegroundColor: HazaraColors.cream,
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: _holding
                  ? _cancelHold
                  : (_model.isLegal ? _startHold : null),
              child: Text(_holding ? 'Undo lock' : 'Ready'),
            ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text, required this.onSwap, this.hindi});

  final String text;
  final String? hindi;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E2B0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF3E2E08),
                    fontSize: 13,
                  ),
                ),
                if (hindi != null)
                  HindiLine(hindi!, size: 12, color: const Color(0xFF3E2E08)),
              ],
            ),
          ),
          if (onSwap != null)
            TextButton(
              key: const ValueKey('swap'),
              onPressed: onSwap,
              child: const Text(
                'Swap sets',
                style: TextStyle(color: Color(0xFF3E2E08)),
              ),
            ),
        ],
      ),
    );
  }
}

class _DragPayload {
  const _DragPayload.card(this.card) : pile = null;
  const _DragPayload.pile(this.pile) : card = null;

  final PlayingCard? card;
  final int? pile;
}
