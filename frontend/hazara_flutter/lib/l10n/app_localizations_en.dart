// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HAZARA';

  @override
  String get tagline => 'Four people. One table. Room code.';

  @override
  String get subTagline => 'Pagat Hazari · Bangladesh rules';

  @override
  String get howToPlay => 'How to play';

  @override
  String get yourName => 'Your name';

  @override
  String get createTable => 'Create table';

  @override
  String get joinTable => 'Join table';

  @override
  String get createAndInvite => 'Create & invite';

  @override
  String get roomCode => 'Room code';

  @override
  String get playWithFriends => 'Play with friends';

  @override
  String get playOnlineSoon => 'Play online · Soon';

  @override
  String get tryCards => 'Try the cards on this device';

  @override
  String get returnToTable => 'Return to your table';

  @override
  String get matchLength => 'Match length';

  @override
  String get oneDeal => 'One deal';

  @override
  String get shortMatch => 'Short · 3 deals';

  @override
  String get fullMatch => 'Full · first to 1000 · about 30–50 min';

  @override
  String needMorePlayers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'players',
      one: 'player',
    );
    return 'Need $n more $_temp0';
  }

  @override
  String seatedCount(int filled) {
    return '$filled of 4 seated';
  }

  @override
  String get shareCode => 'Share this code';

  @override
  String get copyCode => 'Copy';

  @override
  String get shareInvite => 'Share';

  @override
  String get start => 'Start';

  @override
  String get waitingForHost => 'Waiting for the host.';

  @override
  String get leaveTableTitle => 'Leave the table?';

  @override
  String get leaveTableBody =>
      'Your hand stays locked on the server. You can rejoin with the same code.';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get reconnecting => 'Reconnecting… your hand is safe.';

  @override
  String get tryAgain => 'Try again';

  @override
  String awayPlayers(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'are',
      one: 'is',
    );
    return '$names $_temp0 away';
  }

  @override
  String get nextDeal => 'Next deal';

  @override
  String get endMatchEarly => 'End match early';

  @override
  String get playAgain => 'Play again';

  @override
  String get home => 'Home';

  @override
  String get matchFinished => 'Match finished';

  @override
  String winsExclamation(String name) {
    return '$name wins!';
  }

  @override
  String versionLabel(String version) {
    return 'v$version';
  }

  @override
  String get legalFooter => 'Card images: CC0. No account required.';
}
