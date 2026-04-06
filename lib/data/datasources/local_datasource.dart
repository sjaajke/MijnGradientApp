import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

/// Persists sessions as JSON strings in SharedPreferences.
class LocalDataSource {
  static const _key = 'sessions_v1';

  final SharedPreferences _prefs;
  LocalDataSource(this._prefs);

  Future<List<SessionModel>> getSessions() async {
    final raw = _prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => SessionModel.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            ))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveSession(SessionModel session) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.insert(0, session);
    }
    await _prefs.setStringList(
      _key,
      sessions.map((s) => s.toJsonString()).toList(),
    );
  }

  Future<void> deleteSession(String id) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == id);
    await _prefs.setStringList(
      _key,
      sessions.map((s) => s.toJsonString()).toList(),
    );
  }

  Future<SessionModel?> getSession(String id) async {
    final sessions = await getSessions();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
