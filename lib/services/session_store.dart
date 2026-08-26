import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';
import '../utils/offline_ids.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';
  final FlutterSecureStorage _storage;
  Session? _activeSession;
  bool _guestEntryConfirmed = false;

  bool get guestEntryConfirmed => _guestEntryConfirmed;

  Future<Session?> read() async {
    final active = _activeSession;
    if (active != null) {
      if (active.valid) return active;
      _activeSession = null;
    }

    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = Session.fromJson(json);
      if (session.valid) {
        _activeSession = session;
        return session;
      }
    } catch (_) {
      // Invalid legacy storage should fall back to the signed-out route.
    }
    await _deleteIgnoringFailure();
    return null;
  }

  Future<Session> createOfflineGuest() async {
    final existing = await read();
    if (existing?.isGuest == true) {
      _guestEntryConfirmed = true;
      return existing!;
    }
    final clientGuestId = newUuid();
    final credentialBytes = List<int>.generate(
      32,
      (_) => Random.secure().nextInt(256),
    );
    final credential = base64UrlEncode(credentialBytes);
    final session = Session(
      token: '',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
      username: 'guest_${clientGuestId.replaceAll('-', '').substring(0, 24)}',
      isGuest: true,
      remainingAiTrials: 2,
      fullName: 'Guest User',
      localScopeId: clientGuestId,
      clientGuestId: clientGuestId,
      installationCredential: credential,
    );
    await save(session);
    return session;
  }

  Future<Session?> ensureOfflineGuestIdentity() async {
    final session = await read();
    if (session == null || !session.isGuest) return session;
    if (session.clientGuestId != null &&
        session.installationCredential != null &&
        session.localScopeId != null) {
      return session;
    }
    final clientGuestId = newUuid();
    final credential = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );
    final updated = session.copyWith(
      localScopeId: session.accountScope,
      clientGuestId: clientGuestId,
      installationCredential: credential,
    );
    await save(updated);
    return updated;
  }

  Future<void> save(Session session) async {
    _activeSession = session;
    if (session.isGuest) {
      _guestEntryConfirmed = true;
      await _writeIgnoringFailure(session);
      return;
    }

    _guestEntryConfirmed = false;
    try {
      await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    } catch (_) {
      _activeSession = null;
      rethrow;
    }
  }

  Future<void> updateActiveGuestTrials(int remainingTrials) async {
    final session = _activeSession;
    if (session == null || !session.isGuest) return;
    final updated = session.copyWith(
      remainingAiTrials: remainingTrials.clamp(0, 2),
    );
    _activeSession = updated;
    await _writeIgnoringFailure(updated);
  }

  Future<void> updateAccountIdentity({
    required String fullName,
    required String username,
    required String email,
  }) async {
    final session = await read();
    if (session == null || session.isGuest) return;
    await save(
      session.copyWith(fullName: fullName, username: username, email: email),
    );
  }

  Future<void> markReauthenticationRequired() async {
    final session = await read();
    if (session == null) return;
    final localOnly = session.copyWith(
      token: '',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(0),
      refreshAvailable: false,
    );
    _activeSession = localOnly;
    await _writeIgnoringFailure(localOnly);
  }

  Future<void> clear() async {
    _activeSession = null;
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
