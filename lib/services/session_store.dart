import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';
  final FlutterSecureStorage _storage;
  Session? _activeGuestSession;
  bool _guestEntryConfirmed = false;

  bool get guestEntryConfirmed => _guestEntryConfirmed;

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
      final session = Session.fromJson(json);
      if (session.valid) {
        if (session.isGuest) _activeGuestSession = session;
        return session;
      }
    } catch (_) {
      // Invalid legacy storage should fall back to the signed-out route.
    }
    await _deleteIgnoringFailure();
    return null;
  }

  Future<void> save(Session session) async {
    if (session.isGuest) {
      _activeGuestSession = session;
      _guestEntryConfirmed = true;
      await _writeIgnoringFailure(session);
      return;
    }

    _activeGuestSession = null;
    _guestEntryConfirmed = false;
    await _writeIgnoringFailure(session);
  }

  Future<void> updateActiveGuestTrials(int remainingTrials) async {
    final session = _activeGuestSession;
    if (session == null || !session.isGuest) return;
    final updated = session.copyWith(
      remainingAiTrials: remainingTrials.clamp(0, 2),
    );
    _activeGuestSession = updated;
    await _writeIgnoringFailure(updated);
  }

  Future<void> clear() async {
    _activeGuestSession = null;
    _guestEntryConfirmed = false;
    await _storage.delete(key: _key);
  }

  Future<void> _writeIgnoringFailure(Session session) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {
      // Keep the active session usable even when secure storage is unavailable.
    }
  }

  Future<void> _deleteIgnoringFailure() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // Guest mode remains available in memory for this process.
    }
  }
}
