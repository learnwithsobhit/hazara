import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// The application title.
  ///
  /// In en, this message translates to:
  /// **'HAZARA'**
  String get appTitle;

  /// Short tagline shown on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Four people. One table. Room code.'**
  String get tagline;

  /// Game rules attribution on home screen.
  ///
  /// In en, this message translates to:
  /// **'Pagat Hazari · Bangladesh rules'**
  String get subTagline;

  /// Button and section header for the rulebook.
  ///
  /// In en, this message translates to:
  /// **'How to play'**
  String get howToPlay;

  /// Label for the player name text field.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// Segmented control tab to create a new table.
  ///
  /// In en, this message translates to:
  /// **'Create table'**
  String get createTable;

  /// Segmented control tab to join an existing table.
  ///
  /// In en, this message translates to:
  /// **'Join table'**
  String get joinTable;

  /// Primary CTA button on the Create tab.
  ///
  /// In en, this message translates to:
  /// **'Create & invite'**
  String get createAndInvite;

  /// Label for the room code input.
  ///
  /// In en, this message translates to:
  /// **'Room code'**
  String get roomCode;

  /// Generic CTA for starting a friends game.
  ///
  /// In en, this message translates to:
  /// **'Play with friends'**
  String get playWithFriends;

  /// Disabled online play button label.
  ///
  /// In en, this message translates to:
  /// **'Play online · Soon'**
  String get playOnlineSoon;

  /// Solo arrangement practice button.
  ///
  /// In en, this message translates to:
  /// **'Try the cards on this device'**
  String get tryCards;

  /// Button shown when the player has an active match.
  ///
  /// In en, this message translates to:
  /// **'Return to your table'**
  String get returnToTable;

  /// Label for the match length selector.
  ///
  /// In en, this message translates to:
  /// **'Match length'**
  String get matchLength;

  /// One deal match length option.
  ///
  /// In en, this message translates to:
  /// **'One deal'**
  String get oneDeal;

  /// Short match length option.
  ///
  /// In en, this message translates to:
  /// **'Short · 3 deals'**
  String get shortMatch;

  /// Full match length option.
  ///
  /// In en, this message translates to:
  /// **'Full · first to 1000 · about 30–50 min'**
  String get fullMatch;

  /// Lobby label when not enough players have joined.
  ///
  /// In en, this message translates to:
  /// **'Need {n} more {n, plural, one{player} other{players}}'**
  String needMorePlayers(int n);

  /// Player count in the lobby waiting room.
  ///
  /// In en, this message translates to:
  /// **'{filled} of 4 seated'**
  String seatedCount(int filled);

  /// Instruction above the large room code in the lobby.
  ///
  /// In en, this message translates to:
  /// **'Share this code'**
  String get shareCode;

  /// Copy room code button.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyCode;

  /// Share invite link button.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareInvite;

  /// Host start match button.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Message shown to non-host players waiting for the match to start.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host.'**
  String get waitingForHost;

  /// Confirm dialog title when pressing back on the table screen.
  ///
  /// In en, this message translates to:
  /// **'Leave the table?'**
  String get leaveTableTitle;

  /// Confirm dialog body when leaving the table.
  ///
  /// In en, this message translates to:
  /// **'Your hand stays locked on the server. You can rejoin with the same code.'**
  String get leaveTableBody;

  /// Cancel button in the leave confirm dialog.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// Confirm leave button.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// Reconnect banner message.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting… your hand is safe.'**
  String get reconnecting;

  /// Retry reconnection button.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Away presence bar message.
  ///
  /// In en, this message translates to:
  /// **'{names} {count, plural, one{is} other{are}} away'**
  String awayPlayers(String names, int count);

  /// Host button to advance to the next deal.
  ///
  /// In en, this message translates to:
  /// **'Next deal'**
  String get nextDeal;

  /// Host button to force-end a match before the natural conclusion.
  ///
  /// In en, this message translates to:
  /// **'End match early'**
  String get endMatchEarly;

  /// Rematch button shown on the victory screen.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get playAgain;

  /// Home navigation button.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Header on the victory/summary screen when the match ends.
  ///
  /// In en, this message translates to:
  /// **'Match finished'**
  String get matchFinished;

  /// Winner announcement on the victory screen.
  ///
  /// In en, this message translates to:
  /// **'{name} wins!'**
  String winsExclamation(String name);

  /// Version string in the footer.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String versionLabel(String version);

  /// Legal footer on the home screen.
  ///
  /// In en, this message translates to:
  /// **'Card images: CC0. No account required.'**
  String get legalFooter;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
