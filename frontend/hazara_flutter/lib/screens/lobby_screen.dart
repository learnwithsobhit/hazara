/// Lobby screen — seat ring, share sheet, invitee preview, host crown.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../net/api_client.dart';
import '../net/session_store.dart';
import '../theme/hazara_theme.dart';
import '../theme/layout.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/share_sheet.dart';
import 'table_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({
    super.key,
    required this.name,
    this.session,
    this.roomCode,
    this.autoJoin = false,
  });

  final String name;
  final GuestSession? session;
  final String? roomCode;

  /// When true (home Join), skip the create/join chooser and sit the player.
  final bool autoJoin;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  final _api = HazaraApi();
  final _codeCtrl = TextEditingController();
  String _length = 'short';
  RoomView? _room;
  RoomPreview? _preview;
  String? _error;
  bool _busy = false;
  bool _previewLoading = false;
  Timer? _poll;
  bool _opened = false;
  bool _autoOpen = true;
  int _avatar = 0;

  /// Pulse animation for open seats.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _loadAvatar();
    final code = widget.roomCode;
    if (code != null && code.isNotEmpty) {
      _codeCtrl.text = code;
      _loadPreview(code);
      if (widget.autoJoin) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _room == null && !_busy) _join();
        });
      }
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _codeCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final av = await SessionStore().loadAvatar();
    if (mounted) setState(() => _avatar = av);
  }

  Future<void> _loadPreview(String code) async {
    setState(() => _previewLoading = true);
    final preview = await _api.fetchPreview(code.trim().toUpperCase());
    if (mounted) setState(() { _preview = preview; _previewLoading = false; });
  }

  Future<void> _ensureSession() async {
    if (_api.session != null) return;
    final saved = widget.session;
    if (saved != null && saved.name == widget.name) {
      _api.session = saved;
      return;
    }
    final created = await _api.signIn(widget.name);
    await SessionStore().saveGuest(created);
  }

  Future<void> _create() async {
    setState(() { _busy = true; _error = null; });
    try {
      await _ensureSession();
      final room = await _api.createRoom(_length);
      if (!mounted) return;
      setState(() => _room = room);
      _watch(room.code);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) { setState(() => _error = 'Enter the room code.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await _ensureSession();
      final room = await _api.joinRoom(code);
      if (!mounted) return;
      setState(() => _room = room);
      _watch(room.code);
      if (room.matchId != null) _openTable(room.matchId!);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _watch(String code) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final room = await _api.fetchRoom(code);
        if (!mounted) return;
        setState(() => _room = room);
        if (room.matchId != null && _autoOpen) _openTable(room.matchId!);
      } on ApiException catch (e) {
        if (mounted) setState(() => _error = e.message);
      }
    });
  }

  void _openTable(String matchId) {
    if (_opened || _api.session == null) return;
    _opened = true;
    _autoOpen = false;
    _poll?.cancel();
    SessionStore().saveMatch(matchId);
    final code = _room?.code;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TableScreen(
            matchId: matchId,
            token: _api.session!.token,
            base: _api.base,
          ),
        ))
        .then((_) {
          if (!mounted || code == null) return;
          setState(() => _opened = false);
          _watch(code);
        });
  }

  Future<void> _start() async {
    final room = _room;
    if (room == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final matchId = await _api.startRoom(room.code);
      if (!mounted) return;
      _openTable(matchId);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: tableMaxWidth(context)),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: _room == null
                  ? (_busy && _joinOnly
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: HazaraColors.gold,
                          ),
                        )
                      : _chooser())
                  : _waiting(),
            ),
          ),
        ),
      ),
    );
  }

  bool get _joinOnly =>
      widget.roomCode != null && widget.roomCode!.isNotEmpty;

  // ─── Chooser (before joining/creating) ────────────────────────────────────

  Widget _chooser() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                _joinOnly ? 'Join table' : 'Create table',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            GestureDetector(
              onTap: _pickAvatar,
              child: AvatarChip(index: _avatar, size: 40, selected: true),
            ),
          ],
        ),
        Text(
          'Playing as ${widget.name}',
          style: const TextStyle(color: HazaraColors.creamMuted),
        ),
        const SizedBox(height: 20),
        if (_joinOnly) _joinChooser() else _createChooser(),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: HazaraColors.gold)),
        ],
      ],
    );
  }

  Widget _createChooser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Match length'),
        const SizedBox(height: 8),
        _lengthChip('one_deal', 'One deal'),
        _lengthChip('short', 'Short · 3 deals'),
        _lengthChip('full', 'Full · first to 1000 · ~40 min'),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('create-room'),
          style: FilledButton.styleFrom(
            backgroundColor: HazaraColors.gold,
            foregroundColor: HazaraColors.ink,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _busy ? null : _create,
          child: const Text('Create table'),
        ),
      ],
    );
  }

  Widget _joinChooser() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_preview != null) ...[
          _previewCard(_preview!),
          const SizedBox(height: 16),
        ] else if (_previewLoading) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
        TextField(
          key: const ValueKey('room-code'),
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          onChanged: (v) {
            final code = v.trim().toUpperCase();
            if (code.length >= 4) _loadPreview(code);
          },
          decoration: const InputDecoration(
            labelText: 'Room code',
            filled: true,
            fillColor: HazaraColors.feltDeep,
          ),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey('join-room'),
          style: FilledButton.styleFrom(
            backgroundColor: HazaraColors.gold,
            foregroundColor: HazaraColors.ink,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: _busy ? null : _join,
          child: const Text('Join table'),
        ),
      ],
    );
  }

  Widget _previewCard(RoomPreview p) {
    final vacant = p.seatsTotal - p.seatsTaken;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HazaraColors.feltRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HazaraColors.gold.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.hostName}\'s table',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: HazaraColors.cream,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${p.seatsTaken} of ${p.seatsTotal} seated · ${lengthLabel(p.matchLength)}'
            '${p.inProgress ? ' · In progress' : ''}',
            style: const TextStyle(color: HazaraColors.creamMuted, fontSize: 13),
          ),
          if (vacant <= 0 && !p.inProgress)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Table is full.',
                style: TextStyle(color: HazaraColors.gold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final chosen = await showAvatarPicker(context, _avatar);
    if (chosen == null) return;
    setState(() => _avatar = chosen);
    await SessionStore().saveAvatar(chosen);
  }

  Widget _lengthChip(String id, String label) {
    final selected = _length == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? const Color(0x332E8F7E) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('length-$id'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _length = id),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? HazaraColors.you : HazaraColors.line,
              ),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // ─── Waiting room ──────────────────────────────────────────────────────────

  Widget _waiting() {
    final room = _room!;
    final filled = room.seats.where((s) => s.name != null).length;
    final hostName = _api.session?.name ?? widget.name;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              // Back + title
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Expanded(
                    child: Text('Table',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),

              // Room code chip
              Semantics(
                label: 'Room code ${room.code}',
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: HazaraColors.feltRaised,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: HazaraColors.gold),
                    ),
                    child: Text(
                      room.code,
                      style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                        color: HazaraColors.gold,
                      ),
                    ),
                  ),
                ),
              ),

              // Seat count
              Text(
                filled == 4
                    ? 'All 4 players seated'
                    : '$filled of 4 seated — need ${4 - filled} more',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: filled == 4 ? HazaraColors.you : HazaraColors.creamMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),

              // Seat ring visual
              _SeatRing(
                seats: room.seats,
                pulse: _pulse,
                myAvatar: _avatar,
              ),
              const SizedBox(height: 12),

              // Match length label
              Text(
                lengthLabel(room.matchLength),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HazaraColors.creamMuted, fontSize: 13),
              ),
            ],
          ),
        ),

        // Action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: HazaraColors.gold)),
                ),

              // Invite friends button — always shown, gold
              FilledButton.icon(
                key: const ValueKey('invite-btn'),
                style: FilledButton.styleFrom(
                  backgroundColor: HazaraColors.gold,
                  foregroundColor: HazaraColors.ink,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => showHazaraShareSheet(
                  context: context,
                  code: room.code,
                  hostName: hostName,
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite friends'),
              ),
              const SizedBox(height: 8),

              // Start / Return / Waiting
              if (room.matchId != null)
                FilledButton(
                  key: const ValueKey('return-table'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HazaraColors.you,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => _openTable(room.matchId!),
                  child: const Text('Return to table'),
                )
              else if (room.youAreHost)
                FilledButton(
                  key: const ValueKey('start-match'),
                  style: FilledButton.styleFrom(
                    backgroundColor: room.canStart
                        ? HazaraColors.you
                        : HazaraColors.feltRaised,
                    foregroundColor:
                        room.canStart ? Colors.white : HazaraColors.cream,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: room.canStart && !_busy ? _start : null,
                  child: Text(room.canStart ? 'Start match' : _needLabel(filled)),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Waiting for the host to start…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: HazaraColors.creamMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _needLabel(int filled) {
    final need = 4 - filled;
    return need == 1 ? 'Need 1 more player' : 'Need $need more players';
  }
}

// ─── Seat ring widget ──────────────────────────────────────────────────────

class _SeatRing extends StatelessWidget {
  const _SeatRing({
    required this.seats,
    required this.pulse,
    required this.myAvatar,
  });

  final List<RoomSeat> seats;
  final Animation<double> pulse;
  final int myAvatar;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final cx = w / 2;
          final cy = h / 2;
          final rx = w * 0.38;
          final ry = h * 0.40;

          return Stack(
            children: [
              // Felt oval
              CustomPaint(
                size: Size(w, h),
                painter: _OvalPainter(),
              ),

              // 4 seat chips placed around the oval
              for (var i = 0; i < 4; i++)
                Builder(builder: (context) {
                  final angle = -math.pi / 2 + i * math.pi / 2;
                  final x = cx + rx * math.cos(angle) - 28;
                  final y = cy + ry * math.sin(angle) - 28;
  final seat = i < seats.length ? seats[i] : RoomSeat(name: null, you: false);
                  return Positioned(
                    left: x,
                    top: y,
                    child: _SeatChip(
                      seat: seat,
                      isHost: i == 0,
                      avatar: seat.you ? myAvatar : null,
                      pulse: pulse,
                    ),
                  );
                }),

              // Centre "HAZARA" label
              Center(
                child: Text(
                  'HAZARA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: HazaraColors.gold.withAlpha(120),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OvalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.85,
      height: size.height * 0.85,
    );
    // Table felt gradient
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2E7D32),
          HazaraColors.feltDeep,
        ],
        radius: 0.85,
      ).createShader(rect);
    canvas.drawOval(rect, paint);
    // Wood rim
    final rimPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawOval(rect, rimPaint);
  }

  @override
  bool shouldRepaint(_OvalPainter old) => false;
}

class _SeatChip extends StatelessWidget {
  const _SeatChip({
    required this.seat,
    required this.isHost,
    required this.pulse,
    this.avatar,
  });

  final RoomSeat seat;
  final bool isHost;
  final Animation<double> pulse;
  final int? avatar;

  @override
  Widget build(BuildContext context) {
    final open = seat.name == null;
    final name = seat.name ?? '';
    final bg = seat.you
        ? HazaraColors.you
        : open
            ? HazaraColors.feltRaised
            : HazaraColors.feltRaised;
    final av = avatar;

    if (open) {
      // Pulsing open-seat ring
      return AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final opacity = 0.3 + 0.5 * pulse.value;
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HazaraColors.feltDeep,
              border: Border.all(
                color: HazaraColors.gold.withAlpha((opacity * 255).round()),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_add_alt_1,
              size: 22,
              color: HazaraColors.creamMuted,
            ),
          );
        },
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (av != null)
          AvatarChip(
            index: av,
            size: 56,
            selected: seat.you,
          )
        else
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg,
              border: Border.all(
                color: seat.you ? HazaraColors.gold : HazaraColors.line,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HazaraColors.cream),
            ),
          ),

        // Host crown badge
        if (isHost)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: HazaraColors.gold,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('♔',
                  style: TextStyle(fontSize: 11, color: HazaraColors.ink)),
            ),
          ),

        // Name tooltip below chip
        Positioned(
          top: 58,
          left: -20,
          right: -20,
          child: Text(
            seat.you ? '${name.split(' ').first} (you)' : name.split(' ').first,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: seat.you ? HazaraColors.gold : HazaraColors.cream,
              fontWeight: seat.you ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
