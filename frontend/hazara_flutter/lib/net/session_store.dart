import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class SessionStore {
  static const _token = 'hazara_token';
  static const _player = 'hazara_player';
  static const _name = 'hazara_name';
  static const _match = 'hazara_match';
  static const _avatar = 'hazara_avatar';

  Future<GuestSession?> loadGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_token);
    final playerId = prefs.getString(_player);
    final name = prefs.getString(_name);
    if (token == null || playerId == null || name == null || name.isEmpty) {
      return null;
    }
    return GuestSession(token: token, playerId: playerId, name: name);
  }

  Future<void> saveGuest(GuestSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_token, session.token);
    await prefs.setString(_player, session.playerId);
    await prefs.setString(_name, session.name);
  }

  Future<String?> loadMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final matchId = prefs.getString(_match);
    if (matchId == null || matchId.isEmpty) return null;
    return matchId;
  }

  Future<void> saveMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_match, matchId);
  }

  Future<int> loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_avatar) ?? 0;
  }

  Future<void> saveAvatar(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatar, index);
  }
}
