/// Versioned client-side legal consent (Terms + Privacy).
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Bump this when Terms or Privacy text changes so a new visit starts checked again.
const String kLegalAgreementVersion = '2026-10-02';

const String kLegalOperatorName = 'HAZARA';
const String kLegalOperatorEmail = 'shobhit.chaturvedi@zohomail.in';

const _acceptedKey = 'hazara_legal_accepted_v';
const _declinedKey = 'hazara_legal_declined';
const _micKey = 'hazara_allow_mic';

/// First visit is accepted. A deliberate uncheck is remembered.
Future<bool> loadLegalAccepted() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_declinedKey) == true) return false;
  final stored = prefs.getString(_acceptedKey);
  if (stored == null) return true;
  return stored == kLegalAgreementVersion;
}

Future<void> setLegalAccepted(bool accepted) async {
  final prefs = await SharedPreferences.getInstance();
  if (accepted) {
    await prefs.setString(_acceptedKey, kLegalAgreementVersion);
    await prefs.remove(_declinedKey);
  } else {
    await prefs.remove(_acceptedKey);
    await prefs.setBool(_declinedKey, true);
  }
}

/// First visit allows the microphone prompt. A deliberate uncheck is remembered.
Future<bool> loadAllowMic() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_micKey) ?? true;
}

Future<void> setAllowMic(bool allow) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_micKey, allow);
}
