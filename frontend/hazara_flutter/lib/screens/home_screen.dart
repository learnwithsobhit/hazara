import 'package:flutter/material.dart';

import '../net/api_client.dart';
import '../net/session_store.dart';
import '../theme/hazara_theme.dart';
import '../theme/layout.dart';
import '../util/legal_consent.dart';
import '../util/mic_permission.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/hero_section.dart';
import '../widgets/table_consent.dart';
import 'arrangement_screen.dart';
import 'lobby_screen.dart';
import 'rules_book.dart';
import 'settings_screen.dart';
import 'table_screen.dart';

const _kVersion = 'v1.0.0';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.roomCode});

  final String? roomCode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _sessions = SessionStore();
  final _rulesKey = GlobalKey();
  GuestSession? _saved;
  String? _matchId;
  String? _error;
  int _avatar = 0;
  int _tab = 0; // 0 = Create, 1 = Join
  bool _inviteDismissed = false;
  bool _legalAccepted = true;
  bool _allowMic = true;

  bool get _invited {
    final code = widget.roomCode;
    return !_inviteDismissed && code != null && code.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await _sessions.loadGuest();
    final matchId = await _sessions.loadMatch();
    final avatar = await _sessions.loadAvatar();
    final legal = await loadLegalAccepted();
    final mic = await loadAllowMic();
    if (!mounted) return;
    final invited =
        widget.roomCode != null && widget.roomCode!.isNotEmpty;
    setState(() {
      _saved = saved;
      _matchId = matchId;
      _avatar = invited ? 0 : avatar;
      _legalAccepted = legal;
      _allowMic = mic;
      if (!invited && saved != null && _name.text.isEmpty) {
        _name.text = saved.name;
      }
    });
    // Invitees type their own name — never inherit the last player on this device.
    if (invited) {
      _name.clear();
      setState(() {
        _tab = 1;
        _code.text = widget.roomCode!;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Widget _inviteBanner() {
    final code = widget.roomCode ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: HazaraColors.feltRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HazaraColors.gold.withAlpha(90)),
      ),
      child: Column(
        children: [
          const Text(
            'You\'re invited',
            style: TextStyle(
              fontSize: 13,
              color: HazaraColors.creamMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            style: const TextStyle(
              fontSize: 28,
              letterSpacing: 6,
              fontWeight: FontWeight.w800,
              color: HazaraColors.gold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your name and join this table.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: HazaraColors.creamMuted),
          ),
        ],
      ),
    );
  }

  void _showRules() {
    final target = _rulesKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: Duration(
        milliseconds: TableSettings.reducedMotion.value ? 0 : 280,
      ),
    );
  }

  Future<void> _pickAvatar() async {
    final chosen = await showAvatarPicker(context, _avatar);
    if (chosen == null) return;
    setState(() => _avatar = chosen);
    await _sessions.saveAvatar(chosen);
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 16) {
      setState(() => _error = 'Enter a name of 1–16 characters.');
      return;
    }
    if (!_legalAccepted) {
      setState(() => _error = 'Please agree to the Terms of Use and Privacy Policy.');
      return;
    }
    setState(() => _error = null);
    if (_allowMic) await requestMicrophonePermission();
    if (!mounted) return;
    final reuse = _saved != null && _saved!.name == name ? _saved : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(name: name, session: reuse),
      ),
    );
  }

  Future<void> _join() async {
    final name = _name.text.trim();
    final code = _code.text.trim().toUpperCase();
    if (name.isEmpty || name.length > 16) {
      setState(() => _error = 'Enter a name of 1–16 characters.');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Paste or type the 6-letter room code.');
      return;
    }
    if (!_legalAccepted) {
      setState(() => _error = 'Please agree to the Terms of Use and Privacy Policy.');
      return;
    }
    setState(() => _error = null);
    if (_allowMic) await requestMicrophonePermission();
    if (!mounted) return;
    final reuse = _saved != null && _saved!.name == name ? _saved : null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          name: name,
          session: reuse,
          roomCode: code,
          autoJoin: true,
        ),
      ),
    );
  }

  void _return() {
    final saved = _saved;
    final matchId = _matchId;
    if (saved == null || matchId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TableScreen(
          matchId: matchId,
          token: saved.token,
          base: HazaraApi().base,
        ),
      ),
    );
  }

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: ListView(
                  children: [
                    if (_invited)
                      HeroSection(compact: true)
                    else
                      const HeroSection(),

                    if (_invited) ...[
                      _inviteBanner(),
                      const SizedBox(height: 16),
                    ] else if (_matchId != null && _saved != null) ...[
                      FilledButton(
                        key: const ValueKey('return-table'),
                        style: FilledButton.styleFrom(
                          backgroundColor: HazaraColors.gold,
                          foregroundColor: HazaraColors.ink,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _return,
                        child: const Text('Return to your table'),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: HazaraColors.line),
                      const SizedBox(height: 16),
                    ],

                    // ──────────────────────────────────────────
                    // Identity row: avatar + name field
                    // ──────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Choose avatar',
                          button: true,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              children: [
                                AvatarChip(
                                  index: _avatar,
                                  size: 52,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: HazaraColors.gold,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: HazaraColors.felt, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: HazaraColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('name'),
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            maxLength: 16,
                            decoration: const InputDecoration(
                              labelText: 'Your name',
                              counterText: '',
                              filled: true,
                              fillColor: HazaraColors.feltDeep,
                            ),
                            onChanged: (_) => setState(() => _error = null),
                            onSubmitted: (_) =>
                                (_invited || _tab == 1) ? _join() : _create(),
                          ),
                        ),
                      ],
                    ),

                    // ──────────────────────────────────────────
                    // Error
                    // ──────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: HazaraColors.gold, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TableConsent(
                      legalAccepted: _legalAccepted,
                      allowMic: _allowMic,
                      onLegalChanged: (accepted) {
                        setState(() => _legalAccepted = accepted);
                        setLegalAccepted(accepted);
                      },
                      onMicChanged: (allow) {
                        setState(() => _allowMic = allow);
                        setAllowMic(allow);
                      },
                    ),
                    const SizedBox(height: 8),

                    if (_invited) ...[
                      FilledButton(
                        key: const ValueKey('join-table'),
                        style: FilledButton.styleFrom(
                          backgroundColor: HazaraColors.gold,
                          foregroundColor: HazaraColors.ink,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: _join,
                        child: const Text('Join table'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('not-this-table'),
                        onPressed: () => setState(() {
                          _inviteDismissed = true;
                          _tab = 0;
                          _error = null;
                        }),
                        child: const Text('Create your own table instead'),
                      ),
                    ] else ...[
                      _SegmentedTab(
                        selected: _tab,
                        labels: const ['Create table', 'Join table'],
                        onChanged: (i) => setState(() {
                          _tab = i;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_tab == 0)
                        FilledButton(
                          key: const ValueKey('play-friends'),
                          style: FilledButton.styleFrom(
                            backgroundColor: HazaraColors.gold,
                            foregroundColor: HazaraColors.ink,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _create,
                          child: const Text('Create & invite'),
                        )
                      else ...[
                        TextField(
                          key: const ValueKey('room-code'),
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: const InputDecoration(
                            labelText: 'Room code',
                            counterText: '',
                            filled: true,
                            fillColor: HazaraColors.feltDeep,
                            hintText: 'ABC123',
                          ),
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _join(),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          key: const ValueKey('join-table'),
                          style: FilledButton.styleFrom(
                            backgroundColor: HazaraColors.gold,
                            foregroundColor: HazaraColors.ink,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: _join,
                          child: const Text('Join table'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                        key: const ValueKey('play-online'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HazaraColors.creamMuted,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: HazaraColors.line),
                        ),
                        onPressed: null,
                        child: const Text('Play online · Soon'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('try-cards'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HazaraColors.cream,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: HazaraColors.line),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ArrangementScreen(),
                            ),
                          );
                        },
                        child: const Text('Try the cards on this device'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          key: const ValueKey('settings'),
                          style: TextButton.styleFrom(
                            foregroundColor: HazaraColors.creamMuted,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: const Text('Settings'),
                        ),
                        if (!_invited)
                          TextButton(
                            key: const ValueKey('how-to-play'),
                            style: TextButton.styleFrom(
                              foregroundColor: HazaraColors.gold,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            onPressed: _showRules,
                            child: const Text('How to play'),
                          ),
                      ],
                    ),

                    if (!_invited) ...[
                      const SizedBox(height: 20),
                      const Divider(color: HazaraColors.line),
                      const SizedBox(height: 16),
                      Text(
                        'How to play',
                        key: _rulesKey,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Read this once. The table uses these rules.',
                        style: TextStyle(color: HazaraColors.creamMuted),
                      ),
                      const SizedBox(height: 16),
                      const RulesBook(),
                    ],

                    // ──────────────────────────────────────────
                    // Legal footer + version
                    // ──────────────────────────────────────────
                    const SizedBox(height: 28),
                    const Divider(color: HazaraColors.line),
                    const SizedBox(height: 12),
                    const Text(
                      'HAZARA · Pagat Hazari · Bangladesh rules',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HazaraColors.creamMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Card images: CC0. No account required.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: HazaraColors.creamMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _kVersion,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: HazaraColors.line,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-tab segmented control styled for the felt theme.
class _SegmentedTab extends StatelessWidget {
  const _SegmentedTab({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HazaraColors.feltDeep,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HazaraColors.line),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isSelected ? HazaraColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: isSelected ? HazaraColors.ink : HazaraColors.creamMuted,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
