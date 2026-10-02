// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'हज़ारा';

  @override
  String get tagline => 'चार लोग। एक मेज़। रूम कोड।';

  @override
  String get subTagline => 'पगत हज़ारी · बांग्लादेश नियम';

  @override
  String get howToPlay => 'कैसे खेलें';

  @override
  String get yourName => 'आपका नाम';

  @override
  String get createTable => 'मेज़ बनाएं';

  @override
  String get joinTable => 'मेज़ से जुड़ें';

  @override
  String get createAndInvite => 'बनाएं और आमंत्रित करें';

  @override
  String get roomCode => 'रूम कोड';

  @override
  String get playWithFriends => 'दोस्तों के साथ खेलें';

  @override
  String get playOnlineSoon => 'ऑनलाइन खेलें · जल्द आ रहा है';

  @override
  String get tryCards => 'इस डिवाइस पर पत्ते आज़माएं';

  @override
  String get returnToTable => 'अपनी मेज़ पर वापस जाएं';

  @override
  String get matchLength => 'मैच की लंबाई';

  @override
  String get oneDeal => 'एक डील';

  @override
  String get shortMatch => 'छोटा · 3 डील';

  @override
  String get fullMatch => 'पूरा · पहले 1000 · लगभग 30–50 मिनट';

  @override
  String needMorePlayers(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'खिलाड़ी चाहिए',
      one: 'खिलाड़ी चाहिए',
    );
    return '$n और $_temp0';
  }

  @override
  String seatedCount(int filled) {
    return '4 में से $filled बैठे';
  }

  @override
  String get shareCode => 'यह कोड शेयर करें';

  @override
  String get copyCode => 'कॉपी करें';

  @override
  String get shareInvite => 'शेयर करें';

  @override
  String get start => 'शुरू करें';

  @override
  String get waitingForHost => 'होस्ट का इंतज़ार हो रहा है।';

  @override
  String get leaveTableTitle => 'मेज़ छोड़ें?';

  @override
  String get leaveTableBody =>
      'आपका हाथ सर्वर पर सुरक्षित रहेगा। उसी कोड से वापस जुड़ सकते हैं।';

  @override
  String get stay => 'रुकें';

  @override
  String get leave => 'छोड़ें';

  @override
  String get reconnecting => 'दोबारा जुड़ रहे हैं… आपका हाथ सुरक्षित है।';

  @override
  String get tryAgain => 'फिर कोशिश करें';

  @override
  String awayPlayers(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'हैं',
      one: 'है',
    );
    return '$names अनुपस्थित $_temp0';
  }

  @override
  String get nextDeal => 'अगली डील';

  @override
  String get endMatchEarly => 'मैच जल्दी समाप्त करें';

  @override
  String get playAgain => 'फिर खेलें';

  @override
  String get home => 'होम';

  @override
  String get matchFinished => 'मैच समाप्त';

  @override
  String winsExclamation(String name) {
    return '$name जीत गए!';
  }

  @override
  String versionLabel(String version) {
    return 'v$version';
  }

  @override
  String get legalFooter => 'पत्ते: CC0। कोई अकाउंट नहीं चाहिए।';
}
