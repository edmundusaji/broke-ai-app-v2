import 'dart:io';

import 'package:dio/dio.dart';

import 'api_client.dart';
import 'device_identity_store.dart';
import 'offline_database.dart';
import 'session_store.dart';

class TransactionSyncService {
  TransactionSyncService(
    this._api,
    this._sessions,
    this._database,
    this._devices, {
    this.onDataChanged,
    this.onSessionChanged,
  });

  final ApiClient _api;
  final SessionStore _sessions;
  final OfflineDatabase _database;
  final DeviceIdentityStore _devices;
  final void Function()? onDataChanged;
  final void Function()? onSessionChanged;

  Future<void>? _activeSync;

  Future<void> synchronize() {
    final active = _activeSync;
    if (active != null) return active;
    final run = _run();
    _activeSync = run;
    return run.whenComplete(() {
      if (identical(_activeSync, run)) _activeSync = null;
    });
  }

  Future<void> _run() async {
    var session = await _sessions.read();
    if (session == null) return;
    final accountScope = session.accountScope;
    await _database.markSyncStatus(accountScope, 'syncing');
    onDataChanged?.call();

    try {
      if (session.isGuest && !session.canAuthenticate) {
        session = await _api.guestLogin();
        await _sessions.save(session);
        onSessionChanged?.call();
      }
      if (!session.canAuthenticate) {
        await _database.markSyncStatus(
          accountScope,
          'authentication_required',
          errorCode: 'REAUTHENTICATION_REQUIRED',
        );
        return;
      }

      final deviceId = await _devices.readOrCreate();
      while (true) {
        final operations = await _database.pendingMutations(accountScope);
        if (operations.isEmpty) break;
        final response = await _api.pushTransactions(
          deviceId: deviceId,
          operations: operations,
        );
        await _database.applyPushResponse(accountScope, response);
        onDataChanged?.call();
        if (response.results.every(
          (result) => result.status == 'RETRYABLE_FAILURE',
        )) {
          break;
        }
      }

      await _pullAll(accountScope);
      await _processPendingCaptures(accountScope);
      await _pullAll(accountScope);
      final status = await _database.syncStatus(accountScope);
      await _database.markSyncStatus(
        accountScope,
        status.hasConflicts
            ? 'conflict'
            : status.hasPending
            ? 'pending'
            : 'synced',
      );
    } on DioException catch (error) {
      final code = _apiErrorCode(error);
      final status = error.response?.statusCode == 401
          ? 'authentication_required'
          : _isOffline(error)
          ? 'offline'
          : 'failed';
      await _database.markSyncStatus(accountScope, status, errorCode: code);
    } on StateError {
      await _database.markSyncStatus(
        accountScope,
        'authentication_required',
        errorCode: 'REAUTHENTICATION_REQUIRED',
      );
    } finally {
      onDataChanged?.call();
    }
  }

  Future<void> _pullAll(String accountScope) async {
    var cursor = await _database.cursor(accountScope);
    var hasMore = true;
    while (hasMore) {
      final response = await _api.pullTransactions(cursor: cursor);
      await _database.applyPullResponse(accountScope, response);
      cursor = response.nextCursor;
      hasMore = response.hasMore;
      onDataChanged?.call();
    }
  }

  Future<void> _processPendingCaptures(String accountScope) async {
    final captures = await _database.pendingCaptures(accountScope);
    for (final capture in captures) {
      try {
        if (capture.type == 'receipt') {
          final file = File(capture.payload);
          if (!await file.exists()) {
            await _database.failCapture(
              capture.id,
              errorCode: 'ATTACHMENT_MISSING',
              retryable: false,
            );
            continue;
          }
          await _api.receipt(file);
          await file.delete();
        } else {
          await _api.notification(capture.payload);
        }
        await _database.completeCapture(capture.id);
      } on GuestAiTrialLimitException {
        await _database.failCapture(
          capture.id,
          errorCode: GuestAiTrialLimitException.code,
          retryable: false,
        );
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final retryable = status == 429 || (status != null && status >= 500);
        await _database.failCapture(
          capture.id,
          errorCode: _isOffline(error)
              ? 'DELIVERY_UNCERTAIN'
              : _apiErrorCode(error),
          // A connection can fail after the server committed an AI result.
          // Require user review instead of risking an automatic duplicate.
          retryable: retryable,
        );
        if (_isOffline(error)) break;
      }
    }
  }

  bool _isOffline(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;

  String _apiErrorCode(DioException error) {
    final body = error.response?.data;
    if (body is Map) {
      final nested = body['error'];
      if (nested is Map && nested['code'] is String) {
        return nested['code'] as String;
      }
      if (body['code'] is String) return body['code'] as String;
    }
    return _isOffline(error) ? 'OFFLINE' : 'SYNC_FAILED';
  }
}
