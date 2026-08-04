import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';
  final FlutterSecureStorage _storage;
  Session? _activeGuestSession;

  Future<Session?> read() async {
    final guest = _activeGuestSession;
    if (guest != null) {
      if (guest.valid) return guest;
      _activeGuestSession = null;
    }

    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = Session(
        token: json['token'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        username: json['username'] as String,
        isGuest: json['isGuest'] as bool? ?? false,
        remainingAiTrials: (json['remaining_ai_trials'] as num?)?.toInt() ?? 0,
        name: json['name'] as String?,
        email: json['email'] as String?,
      );
      if (!session.isGuest && session.valid) return session;
    } catch (_) {
      // Invalid legacy storage should fall back to the signed-out route.
    }
    await _deleteIgnoringFailure();
    return null;
  }

  Future<void> save(Session session) async {
    if (session.isGuest) {
      _activeGuestSession = session;
      await _deleteIgnoringFailure();
      return;
    }

    _activeGuestSession = null;
    await _storage.write(
      key: _key,
      value: jsonEncode({
        'token': session.token,
        'expiresAt': session.expiresAt.toIso8601String(),
        'username': session.username,
        'isGuest': false,
        'remaining_ai_trials': session.remainingAiTrials,
        'name': session.name,
        'email': session.email,
      }),
    );
  }

  void updateActiveGuestTrials(int remainingTrials) {
    final session = _activeGuestSession;
    if (session == null || !session.isGuest) return;
    _activeGuestSession = session.copyWith(
      remainingAiTrials: remainingTrials.clamp(0, 2),
    );
  }

  Future<void> clear() async {
    _activeGuestSession = null;
    await _storage.delete(key: _key);
  }

  Future<void> _deleteIgnoringFailure() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Guest mode remains available in memory for this process.
    }
  }
}
