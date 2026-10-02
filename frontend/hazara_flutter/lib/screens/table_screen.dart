import 'dart:async';

import 'package:flutter/material.dart';

import '../model/playing_card.dart';
import '../net/api_client.dart';
import 'dart:convert';

import '../net/match_socket.dart';
import '../net/table_sound.dart';
import '../net/voice_note.dart';
import '../screens/settings_screen.dart';
import '../engine/hindi.dart';
import '../widgets/card_face.dart';
import '../widgets/felt_table.dart';
import '../widgets/hindi_line.dart';
import '../widgets/reveal_table.dart';
import '../widgets/table_talk.dart';
import '../widgets/talk_blast.dart';
import '../net/snapshot.dart';
import '../theme/hazara_theme.dart';
import 'arrangement_screen.dart';
import 'victory_screen.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({
    super.key,
    required this.matchId,
    required this.token,
    required this.base,
  });

  final String matchId;
  final String token;
  final String base;

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  MatchSocket? _socket;
  TableSnapshot? _snap;
  String? _error;
  bool _reconnecting = false;
  int _rejectNonce = 0;
  String? _rejectMessage;
  Timer? _retry;
  int _clockOffsetMs = 0;
  final _talk = <_TalkLine>[];
  final _blastBursts = <TalkBurst>[];
  final _voice = VoiceNote();
  // Deal-by-deal history — filled as each deal completes
  final _dealHistory = <DealRecord>[];
  int _lastRecordedDeal = 0;
  List<int> _scoresBeforeDeal = [];
  bool _recording = false;
  // Exponential back-off for reconnect: 2s, 4s, 8s, 16s, 30s max.
  int _backoffMs = 2000;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _socket?.dispose();
    _voice.cancel();
    super.dispose();
  }

  void _scheduleRetry() {
    _retry?.cancel();
    _retry = Timer(Duration(milliseconds: _backoffMs), () {
      if (mounted) {
        _backoffMs = (_backoffMs * 2).clamp(2000, 30000);
        _connect();
      }
    });
  }

  void _retryNow() {
    _backoffMs = 2000;
    _connect();
  }

  void _connect() {
    _retry?.cancel();
    _socket?.dispose();
    final socket = MatchSocket(
      base: widget.base,
      matchId: widget.matchId,
      token: widget.token,
    );
    _socket = socket;
    socket.connect(
      onSnapshot: (snap) {
        if (!mounted) return;
        setState(() {
          _snap = snap;
          _error = null;
          _reconnecting = false;
          _backoffMs = 2000; // reset on successful connection
          if (snap.serverNow > 0) {
            _clockOffsetMs =
                snap.serverNow - DateTime.now().millisecondsSinceEpoch;
          }
          if (snap.locked) _rejectMessage = null;
          // Record completed deals for history view
          _trackDealHistory(snap);
        });
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          if (_snap?.locked == true) {
            _error = message;
          } else {
            _rejectNonce += 1;
            _rejectMessage = message;
          }
        });
      },
      onDone: () {
        if (!mounted || socket.closed) return;
        setState(() {
          _reconnecting = true;
          _error = "Reconnecting… your hand is safe on the server.";
        });
        _scheduleRetry();
      },
      onTalk: _onTalk,
    );
  }

  void _onTalk(Map<String, dynamic> talk) {
    if (!mounted) return;
    final line = _talkLine(talk);
    final id = DateTime.now().microsecondsSinceEpoch;
    final kind = talk['kind'] as String? ?? '';
    final fromSeat = _relativeTalkSeat(talk);
    setState(() {
      _talk.add(_TalkLine(id, line));
      if (_talk.length > 3) _talk.removeAt(0);
      // Add talk blast for emoji/text (not sound/voice)
      if (kind == 'emoji' || kind == 'text') {
        final text = kind == 'emoji'
            ? (talk['emoji'] as String? ?? '🎉')
            : (talk['text'] as String? ?? '');
        addBurst(
          bursts: _blastBursts,
          fromSeat: fromSeat,
          text: text,
          isEmoji: kind == 'emoji',
        );
      }
    });
    Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _talk.removeWhere((item) => item.id == id));
    });
    if (!TableSettings.tableSound.value) return;
    if (kind == 'sound') {
      final sound = talk['sound'] as String? ?? '';
      playSoundId(sound);
    } else if (kind == 'voice') {
      final raw = talk['audio_b64'] as String? ?? '';
      final mime = talk['mime'] as String? ?? 'audio/webm';
      if (raw.isEmpty) return;
      playVoice(base64Decode(raw), mime);
    }
  }

  int _relativeTalkSeat(Map<String, dynamic> talk) {
    final snap = _snap;
    int? abs = (talk['seat'] as num?)?.toInt();
    if (abs == null && snap != null) {
      final from = talk['from'] as String?;
      if (from != null) {
        final match = snap.seats.where((s) => s.name == from).firstOrNull;
        abs = match?.seat;
      }
    }
    if (abs == null) return 0;
    final you = snap?.you ?? 0;
    return (abs - you + 4) % 4;
  }

  String _talkLine(Map<String, dynamic> talk) {
    final from = talk['from'] as String? ?? 'Player';
    switch (talk['kind']) {
      case 'emoji':
        return '$from  ${talk['emoji'] ?? ''}';
      case 'text':
        final emojis = talk['emojis'];
        final extra = emojis is List ? emojis.join() : '';
        return '$from  ${talk['text'] ?? ''} $extra'.trim();
      case 'sound':
        return '$from played a sound';
      case 'voice':
        return '$from  voice';
      default:
        return from;
    }
  }

  Future<void> _toggleVoice() async {
    await unlockTableSound();
    if (_recording) {
      final clip = await _voice.stop();
      if (!mounted) return;
      setState(() => _recording = false);
      if (clip == null) return;
      _socket?.voice(
        mime: clip.mime,
        durationMs: clip.durationMs,
        audioB64: clip.audioB64,
      );
      return;
    }
    try {
      await _voice.start();
      if (!mounted) return;
      setState(() => _recording = true);
      Timer(const Duration(seconds: 6), () {
        if (mounted && _recording) _toggleVoice();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The microphone stayed off.');
    }
  }

  List<List<String>> _ids(List<List<PlayingCard>> sets) {
    return [
      for (final set in sets) [for (final card in set) card.id],
    ];
  }

  Future<bool> _confirmLeave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HazaraColors.feltDeep,
        title: const Text(
          'Leave the table?',
          style: TextStyle(color: HazaraColors.cream),
        ),
        content: const Text(
          'Your hand stays locked on the server. You can rejoin with the same code.',
          style: TextStyle(color: HazaraColors.creamMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Stay',
              style: TextStyle(color: HazaraColors.gold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(color: HazaraColors.creamMuted),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    if (snap == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final nav = Navigator.of(context);
          if (await _confirmLeave()) {
            if (mounted) nav.pop();
          }
        },
        child: Scaffold(
          backgroundColor: HazaraColors.feltDeep,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ColoredBox(
                color: HazaraColors.felt,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? 'Joining the table…',
                          textAlign: TextAlign.center,
                        ),
                        if (_reconnecting) ...[
                          const SizedBox(height: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HazaraColors.gold,
                              side: const BorderSide(color: HazaraColors.gold),
                            ),
                            onPressed: _retryNow,
                            child: const Text('Try again'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (snap.protocol != 1) {
      return const _UpdateScreen();
    }
    void onHome() =>
        Navigator.of(context).popUntil((route) => route.isFirst);
    final page = snap.revealing
        ? _Reveal(snap: snap, clockOffsetMs: _clockOffsetMs)
        : snap.matchOver
        ? VictoryScreen(
            snap: snap,
            dealHistory: _dealHistory,
            onRematch: () => _socket?.rematch(),
            onHome: onHome,
          )
        : !snap.arranging
        ? _Summary(
            snap: snap,
            error: _reconnecting ? null : _error,
            onNext: () => _socket?.nextDeal(),
            onRematch: () => _socket?.rematch(),
            onForceEnd: snap.youAreHost ? () => _socket?.forceEnd() : null,
            onHome: onHome,
          )
        : ArrangementScreen(

            key: ValueKey('deal-${snap.dealNo}'),
            showCoach: snap.dealNo == 1,
            hand: snap.hand,
            live: true,
            banner: 'Deal ${snap.dealNo} · ${lengthLabel(snap.matchLength)}',
            seats: _chips(snap),
            note: _statusLine(snap),
            arrangeDeadlineMs: snap.arrangeDeadlineMs,
            clockOffsetMs: _clockOffsetMs,
            serverLocked: snap.locked,
            autoLocked: snap.autoLocked,
            sealedSets: _sealedCards(snap),
            rejectNonce: _rejectNonce,
            rejectMessage: _rejectMessage,
            onDraft: (sets) => _socket?.saveDraft(_ids(sets)),
            onLocked: (sets) {
              final actionId = '${DateTime.now().microsecondsSinceEpoch}';
              _socket?.ready(actionId, _ids(sets));
            },
          );
    final inner = _reconnecting
        ? Stack(children: [
            page,
            _ReconnectBanner(onRetry: _retryNow),
          ])
        : page;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmLeave()) {
          if (mounted) nav.pop();
        }
      },
      child: _withTalk(inner, snap),
    );
  }

  Widget _withTalk(Widget page, TableSnapshot snap) {
    final awayNames = [
      for (final seat in snap.seats)
        if (!seat.you && seat.status == 'reconnecting') seat.name,
    ];
    return Column(
      children: [
        Expanded(
          child: TalkBlastOverlay(
            bursts: _blastBursts,
            child: page,
          ),
        ),
        if (awayNames.isNotEmpty)
          _AwayBar(
            names: awayNames,
            onNudge: (name) {
              unlockTableSound();
              _socket?.nudge(name);
            },
          ),
        TableTalkBar(
          lines: [for (final line in _talk) line.text],
          recording: _recording,
          onEmoji: (emoji) {
            unlockTableSound();
            _socket?.reaction(emoji);
          },
          onText: (text) {
            unlockTableSound();
            _socket?.talkText(text);
          },
          onSound: (sound) {
            unlockTableSound();
            _socket?.sound(sound);
          },
          onVoice: () {
            _toggleVoice();
          },
        ),
      ],
    );
  }

  List<List<PlayingCard>>? _sealedCards(TableSnapshot snap) {
    if (snap.sealed.isEmpty) return null;
    return [
      for (final group in snap.sealed)
        [for (final id in group) PlayingCard.parse(id)],
    ];
  }

  /// Records beats for a completed deal when the phase transitions to 'summary'
  /// or when the match ends. We capture once per deal number.
  void _trackDealHistory(TableSnapshot snap) {
    final isTerminal = snap.phase == 'summary' || snap.matchOver;
    if (!isTerminal || snap.beats.isEmpty) return;
    if (snap.dealNo <= _lastRecordedDeal) return;
    final scoresBefore = List<int>.from(_scoresBeforeDeal);
    _dealHistory.add(DealRecord(
      dealNo: snap.dealNo,
      playerNames: [for (final s in snap.seats) s.name],
      scoresBefore: scoresBefore,
      scoresAfter: List<int>.from(snap.scores),
      beats: snap.beats,
    ));
    _lastRecordedDeal = snap.dealNo;
    // Update scoresBefore for the NEXT deal
    _scoresBeforeDeal = List<int>.from(snap.scores);
  }

  String? _statusLine(TableSnapshot snap) {
    if (snap.note != null) return snap.note;
    if (_reconnecting && snap.locked) return "You're still locked in.";
    if (!snap.locked) return _reconnecting ? null : _error;
    // Check if the host is away — warn other players.
    final hostAway = !snap.youAreHost &&
        snap.seats.isNotEmpty &&
        snap.seats.first.status == 'reconnecting';
    if (hostAway) return 'Host is away. The deal continues when they return.';
    final names = [
      for (final seat in snap.seats)
        if (!seat.you &&
            (seat.status == 'arranging' || seat.status == 'reconnecting'))
          seat.name,
    ];
    if (names.isEmpty) return null;
    if (names.length == 1) return 'Waiting for ${names.first}.';
    final last = names.removeLast();
    return 'Waiting for ${names.join(', ')} and $last.';
  }

  List<SeatChip> _chips(TableSnapshot snap) {
    return [
      for (var step = 0; step < snap.seats.length; step++)
        () {
          final index = (snap.you + step) % snap.seats.length;
          final seat = snap.seats[index];
          final locked = seat.status == 'ready' ||
              seat.status == 'auto' ||
              seat.status == 'locked';
          return SeatChip(
            name: step == 0 ? 'You' : seat.name,
            detail:
                '${snap.scores[index]} · ${statusWord(seat.status)}',
            you: step == 0,
            remainingSets: locked ? 4 : 0,
            reconnecting: seat.status == 'reconnecting',
            dealer: snap.dealer == seat.seat,
            host: seat.host,
          );
        }(),
    ];
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.snap,
    required this.error,
    required this.onNext,
    required this.onRematch,
    required this.onHome,
    this.onForceEnd,
  });

  final TableSnapshot snap;
  final String? error;
  final VoidCallback onNext;
  final VoidCallback onRematch;
  final VoidCallback onHome;
  final VoidCallback? onForceEnd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ColoredBox(
              color: HazaraColors.felt,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                        const SizedBox(height: 4),
                        Text(
                          snap.matchOver
                              ? 'Match finished · ${lengthLabel(snap.matchLength)}'
                              : 'Deal ${snap.dealNo} · ${lengthLabel(snap.matchLength)}',
                          style: const TextStyle(
                            color: HazaraColors.creamMuted,
                          ),
                        ),
                        if (snap.matchOver) ...[
                          const SizedBox(height: 8),
                          Text(
                            _resultLine(snap),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        PlayTable(
                          compact: true,
                          aspectRatio: 2.85,
                          seats: [
                            for (var step = 0; step < snap.seats.length; step++)
                              () {
                                final index =
                                    (snap.you + step) % snap.seats.length;
                                final seat = snap.seats[index];
                                final score = index < snap.scores.length
                                    ? snap.scores[index]
                                    : 0;
                                return TableSeatInfo(
                                  name: step == 0 ? 'You' : seat.name,
                                  detail: '$score pts',
                                  you: step == 0,
                                  reconnecting: seat.status == 'reconnecting',
                                  dealer: snap.dealer == seat.seat,
                                  host: seat.host,
                                  winner: _dealLeader(snap) == seat.name,
                                );
                              }(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (var i = 0; i < snap.beats.length; i++)
                          _beat(i, snap.beats[i]),
                        const SizedBox(height: 8),
                        if (snap.beats.fold<int>(
                              0,
                              (sum, beat) => sum + beat.points,
                            ) ==
                            360)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              'This deal is 360 points.',
                              style: TextStyle(color: HazaraColors.creamMuted),
                            ),
                          ),
                        if (!snap.matchOver)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Next dealer: ${_seatName(snap, (snap.dealer + 1) % 4)}',
                              style: const TextStyle(
                                color: HazaraColors.creamMuted,
                              ),
                            ),
                          ),
                        for (final chip in _scoreChips(snap))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${chip.$1}  ${chip.$2}    +${chip.$3} this deal',
                            ),
                          ),
                        if (snap.note != null)
                          Text(
                            snap.note!,
                            style: const TextStyle(color: HazaraColors.gold),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              error!,
                              style: const TextStyle(color: HazaraColors.gold),
                            ),
                          ),
                        if (snap.matchOver) ...[
                          if (snap.youAreHost)
                            FilledButton(
                              key: const ValueKey('rematch'),
                              style: FilledButton.styleFrom(
                                backgroundColor: HazaraColors.gold,
                                foregroundColor: HazaraColors.ink,
                                minimumSize: const Size.fromHeight(52),
                              ),
                              onPressed: onRematch,
                              child: const Text('Play again'),
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
                          OutlinedButton(
                            key: const ValueKey('match-home'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: HazaraColors.cream,
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: HazaraColors.line),
                            ),
                            onPressed: onHome,
                            child: const Text('Home'),
                          ),
                        ] else if (snap.youAreHost) ...[
                          FilledButton(
                            key: const ValueKey('next-deal'),
                            style: FilledButton.styleFrom(
                              backgroundColor: HazaraColors.gold,
                              foregroundColor: HazaraColors.ink,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: onNext,
                            child: const Text('Next deal'),
                          ),
                          if (onForceEnd != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              key: const ValueKey('end-match'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HazaraColors.creamMuted,
                                minimumSize: const Size.fromHeight(44),
                                side: const BorderSide(color: HazaraColors.line),
                              ),
                              onPressed: onForceEnd,
                              child: const Text('End match early'),
                            ),
                          ],
                        ] else
                          const Text(
                            'Waiting for the host.',
                            textAlign: TextAlign.center,
                          ),
                        if (!snap.matchOver)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'The next deal starts when the host is ready.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: HazaraColors.creamMuted,
                                fontSize: 12,
                              ),
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
      ),
    );
  }

  Widget _beat(int index, BeatView beat) {
    const names = ['Strongest', 'Second', 'Third', 'Spare'];
    final title = index < names.length ? names[index] : 'Set ${index + 1}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HazaraColors.feltRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: beat.tied
              ? HazaraColors.line
              : HazaraColors.gold.withAlpha(70),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                beat.tied ? '${beat.points} (tied)' : '+${beat.points}',
                style: TextStyle(
                  color: beat.tied ? HazaraColors.creamMuted : HazaraColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (index < kHindiSetNames.length)
            HindiLine(kHindiSetNames[index], size: 12),
          const SizedBox(height: 4),
          Text(
            '${beat.winner} takes this set',
            style: const TextStyle(
              color: HazaraColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (beat.tied)
            const Text(
              'Same hand. The later player takes this set.',
              style: TextStyle(color: HazaraColors.gold, fontSize: 13),
            ),
          const SizedBox(height: 6),
          for (final row in beat.rows) ...[
            Text(
              '${row.name} · ${row.label}',
              style: TextStyle(
                fontWeight: row.name == beat.winner
                    ? FontWeight.w700
                    : FontWeight.normal,
                color: row.name == beat.winner
                    ? HazaraColors.gold
                    : HazaraColors.cream,
              ),
            ),
            if (hindiFromLabel(row.label) != null)
              HindiLine(hindiFromLabel(row.label)!, size: 12),
            if (row.cards.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: _faces(row, glowWinner: row.name == beat.winner),
              ),
          ],
        ],
      ),
    );
  }

  Widget _faces(BeatRow row, {bool glowWinner = false}) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final card in row.cards)
          CardFace(
            card: card,
            width: 42,
            selected: glowWinner && row.spareId != card.id,
            dimmed: row.spareId == card.id,
          ),
      ],
    );
  }
}

String? _dealLeader(TableSnapshot snap) {
  final tally = <String, int>{};
  for (final beat in snap.beats) {
    tally[beat.winner] = (tally[beat.winner] ?? 0) + beat.points;
  }
  if (tally.isEmpty) return null;
  return tally.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

String _seatName(TableSnapshot snap, int seat) {
  for (final person in snap.seats) {
    if (person.seat == seat) return person.name;
  }
  return 'Seat ${seat + 1}';
}

List<(String, String, int)> _scoreChips(TableSnapshot snap) {
  return [
    for (var step = 0; step < snap.seats.length; step++)
      () {
        final index = (snap.you + step) % snap.seats.length;
        final name = snap.seats[index].name;
        var deal = 0;
        for (final beat in snap.beats) {
          if (beat.winner == name) deal += beat.points;
        }
        return (
          step == 0 ? 'You' : name,
          '${index < snap.scores.length ? snap.scores[index] : 0}',
          deal,
        );
      }(),
  ];
}

class _TalkLine {
  _TalkLine(this.id, this.text);

  final int id;
  final String text;
}

String _resultLine(TableSnapshot snap) {
  if (snap.scores.isEmpty) return 'Match finished';
  var best = snap.scores.first;
  for (final score in snap.scores) {
    if (score > best) best = score;
  }
  final names = [
    for (var i = 0; i < snap.seats.length; i++)
      if (i < snap.scores.length && snap.scores[i] == best) snap.seats[i].name,
  ];
  if (names.length == 1) return '${names.first} wins with $best';
  return '${names.join(' and ')} share the lead at $best';
}

class _UpdateScreen extends StatelessWidget {
  const _UpdateScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: HazaraColors.feltDeep,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Update HAZARA to keep playing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            color: HazaraColors.ink,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text(
                      "Reconnecting… your hand is safe.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: HazaraColors.gold,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin bar shown when one or more players at the table are away.
class _AwayBar extends StatelessWidget {
  const _AwayBar({required this.names, required this.onNudge});

  final List<String> names;
  final void Function(String name) onNudge;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HazaraColors.feltDeep,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 14, color: HazaraColors.creamMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${names.join(', ')} ${names.length == 1 ? 'is' : 'are'} away',
              style: const TextStyle(
                color: HazaraColors.creamMuted,
                fontSize: 12,
              ),
            ),
          ),
          for (final name in names)
            TextButton(
              key: ValueKey('nudge-$name'),
              onPressed: () => onNudge(name),
              style: TextButton.styleFrom(
                foregroundColor: HazaraColors.gold,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Nudge ${name.split(' ').first}'),
            ),
        ],
      ),
    );
  }
}

class _Reveal extends StatefulWidget {
  const _Reveal({required this.snap, required this.clockOffsetMs});

  final TableSnapshot snap;
  final int clockOffsetMs;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  Timer? _clock;
  String _left = '';

  @override
  void initState() {
    super.initState();
    _tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_tick);
    });
  }

  @override
  void didUpdateWidget(_Reveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tick();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _tick() {
    final leftMs =
        widget.snap.revealUntilMs -
        (DateTime.now().millisecondsSinceEpoch + widget.clockOffsetMs);
    if (leftMs <= 0) {
      _left = '0:00';
      return;
    }
    final total = (leftMs / 1000).ceil();
    _left = '0:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return RevealTable(snap: widget.snap, clockLabel: _left);
  }
}
