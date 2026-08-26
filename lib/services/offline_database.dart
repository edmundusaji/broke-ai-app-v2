import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import '../models/transaction.dart';
import '../models/transaction_sync.dart';

class LocalTransactionSyncStatus {
  const LocalTransactionSyncStatus({
    required this.status,
    required this.pendingCount,
    required this.conflictCount,
    this.lastSyncedAt,
    this.lastErrorCode,
  });

  final String status;
  final int pendingCount;
  final int conflictCount;
  final DateTime? lastSyncedAt;
  final String? lastErrorCode;

  bool get hasPending => pendingCount > 0;
  bool get hasConflicts => conflictCount > 0;
}

class PendingCapture {
  const PendingCapture({
    required this.id,
    required this.type,
    required this.payload,
  });

  final String id;
  final String type;
  final String payload;
}

class OfflineDatabase {
  OfflineDatabase._(this.database);

  final Database database;

  static const schemaVersion = 1;

  static Future<OfflineDatabase> open({
    String? databasePath,
    DatabaseFactory? factory,
  }) async {
    DatabaseFactory selectedFactory;
    if (factory != null) {
      selectedFactory = factory;
    } else if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      selectedFactory = databaseFactoryFfi;
    } else {
      selectedFactory = databaseFactory;
    }
    final resolvedPath =
        databasePath ??
        path.join(
          await selectedFactory.getDatabasesPath(),
          'broke_ai_offline.db',
        );
    final db = await selectedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) async {
          await _createSchema(database);
        },
      ),
    );
    return OfflineDatabase._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE local_transactions (
        account_scope TEXT NOT NULL,
        client_transaction_id TEXT NOT NULL,
        server_id INTEGER,
        date TEXT,
        amount REAL,
        category TEXT,
        payment_method TEXT,
        description TEXT,
        input_type TEXT,
        validation_status TEXT,
        capture_id TEXT,
        capture_mode TEXT,
        source_package TEXT,
        source_notification_posted_at TEXT,
        revision INTEGER,
        created_at TEXT,
        updated_at TEXT,
        deleted_at TEXT,
        sync_state TEXT NOT NULL DEFAULT 'synced',
        sync_error_code TEXT,
        conflict_json TEXT,
        PRIMARY KEY (account_scope, client_transaction_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX ix_local_transactions_scope_date
      ON local_transactions (account_scope, date DESC)
    ''');
    await db.execute('''
      CREATE TABLE mutation_outbox (
        operation_id TEXT PRIMARY KEY,
        account_scope TEXT NOT NULL,
        client_transaction_id TEXT NOT NULL,
        mutation_type TEXT NOT NULL,
        base_revision INTEGER,
        payload_json TEXT,
        state TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error_code TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_scope, client_transaction_id)
          REFERENCES local_transactions(account_scope, client_transaction_id)
          ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX ix_mutation_outbox_scope_state_created
      ON mutation_outbox (account_scope, state, created_at)
    ''');
    await db.execute('''
      CREATE TABLE transaction_sync_state (
        account_scope TEXT PRIMARY KEY,
        cursor TEXT,
        server_revision INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'local',
        last_synced_at TEXT,
        last_error_code TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_captures (
        capture_queue_id TEXT PRIMARY KEY,
        account_scope TEXT NOT NULL,
        capture_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error_code TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX ix_pending_captures_scope_state_created
      ON pending_captures (account_scope, state, created_at)
    ''');
  }

  Future<List<Transaction>> transactionsForMonth(
    String accountScope,
    DateTime month,
  ) async {
    final monthKey =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    final rows = await database.query(
      'local_transactions',
      where:
          'account_scope = ? AND deleted_at IS NULL AND substr(date, 1, 7) = ?',
      whereArgs: [accountScope, monthKey],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(_transactionFromRow).toList();
  }

  Future<List<Transaction>> recentTransactions(
    String accountScope, {
    int limit = 5,
  }) async {
    final rows = await database.query(
      'local_transactions',
      where: 'account_scope = ? AND deleted_at IS NULL',
      whereArgs: [accountScope],
      orderBy: 'date DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(_transactionFromRow).toList();
  }

  Future<List<Transaction>> activeTransactions(String accountScope) async {
    final rows = await database.query(
      'local_transactions',
      where: 'account_scope = ? AND deleted_at IS NULL',
      whereArgs: [accountScope],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(_transactionFromRow).toList();
  }

  Future<Transaction?> transaction(
    String accountScope,
    String clientTransactionId,
  ) async {
    final rows = await database.query(
      'local_transactions',
      where: 'account_scope = ? AND client_transaction_id = ?',
      whereArgs: [accountScope, clientTransactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : _transactionFromRow(rows.first);
  }

  Future<void> insertLocalTransaction({
    required String accountScope,
    required Transaction transaction,
    required String operationId,
  }) async {
    await database.transaction((txn) async {
      await txn.insert(
        'local_transactions',
        _transactionValues(
          accountScope,
          transaction.copyWith(syncState: 'pending'),
        ),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await txn.insert('mutation_outbox', {
        'operation_id': operationId,
        'account_scope': accountScope,
        'client_transaction_id': transaction.clientTransactionId,
        'mutation_type': 'CREATE',
        'payload_json': jsonEncode(transaction.toJson()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _ensureSyncState(txn, accountScope);
      await txn.update(
        'transaction_sync_state',
        {'status': 'pending', 'last_error_code': null},
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
    });
  }

  Future<void> updateLocalTransaction({
    required String accountScope,
    required Transaction transaction,
    required String operationId,
  }) async {
    final clientId = transaction.clientTransactionId;
    if (clientId == null) throw StateError('Transaction has no client ID.');
    await database.transaction((txn) async {
      final existingRows = await txn.query(
        'mutation_outbox',
        where: 'account_scope = ? AND client_transaction_id = ? AND state != ?',
        whereArgs: [accountScope, clientId, 'conflict'],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      final existing = existingRows.isEmpty ? null : existingRows.first;
      final existingType = existing?['mutation_type'] as String?;
      final effectiveOperationId =
          existingType == 'CREATE' || existingType == 'UPDATE'
          ? existing!['operation_id'] as String
          : operationId;
      final baseRevision = existingType == 'UPDATE'
          ? existing!['base_revision'] as int?
          : transaction.revision;

      await txn.update(
        'local_transactions',
        _transactionValues(
          accountScope,
          transaction.copyWith(
            syncState: 'pending',
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ),
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientId],
      );
      if (existing != null &&
          (existingType == 'CREATE' || existingType == 'UPDATE')) {
        await txn.update(
          'mutation_outbox',
          {
            'payload_json': jsonEncode(transaction.toJson()),
            'state': 'pending',
            'attempt_count': 0,
            'next_attempt_at': null,
            'last_error_code': null,
          },
          where: 'operation_id = ?',
          whereArgs: [effectiveOperationId],
        );
      } else {
        await txn.insert('mutation_outbox', {
          'operation_id': effectiveOperationId,
          'account_scope': accountScope,
          'client_transaction_id': clientId,
          'mutation_type': 'UPDATE',
          'base_revision': baseRevision,
          'payload_json': jsonEncode(transaction.toJson()),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await _markAccountPending(txn, accountScope);
    });
  }

  Future<void> deleteLocalTransaction({
    required String accountScope,
    required Transaction transaction,
    required String operationId,
  }) async {
    final clientId = transaction.clientTransactionId;
    if (clientId == null) throw StateError('Transaction has no client ID.');
    await database.transaction((txn) async {
      final pending = await txn.query(
        'mutation_outbox',
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientId],
        orderBy: 'created_at DESC',
      );
      final pendingCreate = pending.any(
        (row) => row['mutation_type'] == 'CREATE',
      );
      if (pendingCreate && transaction.revision == null) {
        await txn.delete(
          'local_transactions',
          where: 'account_scope = ? AND client_transaction_id = ?',
          whereArgs: [accountScope, clientId],
        );
        return;
      }
      await txn.delete(
        'mutation_outbox',
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientId],
      );
      await txn.update(
        'local_transactions',
        {
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'sync_state': 'pending',
          'sync_error_code': null,
          'conflict_json': null,
        },
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientId],
      );
      await txn.insert('mutation_outbox', {
        'operation_id': operationId,
        'account_scope': accountScope,
        'client_transaction_id': clientId,
        'mutation_type': 'DELETE',
        'base_revision': transaction.revision,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _markAccountPending(txn, accountScope);
    });
  }

  Future<List<TransactionMutation>> pendingMutations(
    String accountScope, {
    int limit = 100,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await database.rawQuery(
      '''
      SELECT o.*, t.*
      FROM mutation_outbox o
      JOIN local_transactions t
        ON t.account_scope = o.account_scope
       AND t.client_transaction_id = o.client_transaction_id
      WHERE o.account_scope = ?
        AND o.state = 'pending'
        AND (o.next_attempt_at IS NULL OR o.next_attempt_at <= ?)
      ORDER BY o.created_at ASC
      LIMIT ?
      ''',
      [accountScope, now, limit],
    );
    return rows.map((row) {
      final typeName = row['mutation_type'] as String;
      final type = TransactionMutationType.values.firstWhere(
        (value) => value.name.toUpperCase() == typeName,
      );
      return TransactionMutation(
        operationId: row['operation_id'] as String,
        type: type,
        clientTransactionId: row['client_transaction_id'] as String,
        baseRevision: row['base_revision'] as int?,
        transaction: type == TransactionMutationType.delete
            ? null
            : _transactionFromRow(row),
      );
    }).toList();
  }

  Future<void> applyPushResponse(
    String accountScope,
    SyncPushResponse response,
  ) async {
    await database.transaction((txn) async {
      for (final result in response.results) {
        final outboxRows = await txn.query(
          'mutation_outbox',
          where: 'account_scope = ? AND operation_id = ?',
          whereArgs: [accountScope, result.operationId],
          limit: 1,
        );
        if (outboxRows.isEmpty) continue;
        final clientId = outboxRows.first['client_transaction_id'] as String;
        switch (result.status) {
          case 'APPLIED':
          case 'DUPLICATE':
            if (result.transaction != null) {
              await _upsertServerTransaction(
                txn,
                accountScope,
                result.transaction!,
              );
            }
            await txn.delete(
              'mutation_outbox',
              where: 'operation_id = ?',
              whereArgs: [result.operationId],
            );
            break;
          case 'CONFLICT':
            await txn.update(
              'local_transactions',
              {
                'sync_state': 'conflict',
                'sync_error_code': result.errorCode,
                'conflict_json': result.transaction == null
                    ? null
                    : jsonEncode(result.transaction!.toJson()),
              },
              where: 'account_scope = ? AND client_transaction_id = ?',
              whereArgs: [accountScope, clientId],
            );
            await txn.update(
              'mutation_outbox',
              {'state': 'conflict', 'last_error_code': result.errorCode},
              where: 'operation_id = ?',
              whereArgs: [result.operationId],
            );
            break;
          case 'REJECTED':
            await txn.update(
              'local_transactions',
              {'sync_state': 'failed', 'sync_error_code': result.errorCode},
              where: 'account_scope = ? AND client_transaction_id = ?',
              whereArgs: [accountScope, clientId],
            );
            await txn.update(
              'mutation_outbox',
              {'state': 'failed', 'last_error_code': result.errorCode},
              where: 'operation_id = ?',
              whereArgs: [result.operationId],
            );
            break;
          default:
            await _scheduleRetry(txn, result.operationId, result.errorCode);
        }
      }
      await _ensureSyncState(txn, accountScope);
      await txn.update(
        'transaction_sync_state',
        {'server_revision': response.serverRevision},
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
    });
  }

  Future<String?> cursor(String accountScope) async {
    final rows = await database.query(
      'transaction_sync_state',
      columns: ['cursor'],
      where: 'account_scope = ?',
      whereArgs: [accountScope],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['cursor'] as String?;
  }

  Future<void> applyPullResponse(
    String accountScope,
    SyncPullResponse response,
  ) async {
    await database.transaction((txn) async {
      for (final change in response.changes) {
        final pending = await txn.query(
          'mutation_outbox',
          where: 'account_scope = ? AND client_transaction_id = ?',
          whereArgs: [accountScope, change.clientTransactionId],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        if (pending.isNotEmpty) {
          final mutationType = pending.first['mutation_type'] as String;
          final baseRevision = pending.first['base_revision'] as int?;
          if (mutationType == 'CREATE' && change.transaction != null) {
            await _upsertServerTransaction(
              txn,
              accountScope,
              change.transaction!,
            );
            await txn.delete(
              'mutation_outbox',
              where: 'account_scope = ? AND client_transaction_id = ?',
              whereArgs: [accountScope, change.clientTransactionId],
            );
            continue;
          }
          if (baseRevision != null && change.revision > baseRevision) {
            await txn.update(
              'local_transactions',
              {
                'sync_state': 'conflict',
                'sync_error_code': 'TRANSACTION_REVISION_CONFLICT',
                'conflict_json': change.transaction == null
                    ? jsonEncode({
                        'clientTransactionId': change.clientTransactionId,
                        'revision': change.revision,
                        'deletedAt': change.deletedAt,
                      })
                    : jsonEncode(change.transaction!.toJson()),
              },
              where: 'account_scope = ? AND client_transaction_id = ?',
              whereArgs: [accountScope, change.clientTransactionId],
            );
            await txn.update(
              'mutation_outbox',
              {
                'state': 'conflict',
                'last_error_code': 'TRANSACTION_REVISION_CONFLICT',
              },
              where: 'account_scope = ? AND client_transaction_id = ?',
              whereArgs: [accountScope, change.clientTransactionId],
            );
          }
          continue;
        }
        if (change.type == 'TRANSACTION_DELETE') {
          await txn.update(
            'local_transactions',
            {
              'revision': change.revision,
              'deleted_at': change.deletedAt,
              'sync_state': 'synced',
              'sync_error_code': null,
              'conflict_json': null,
            },
            where: 'account_scope = ? AND client_transaction_id = ?',
            whereArgs: [accountScope, change.clientTransactionId],
          );
        } else if (change.transaction != null) {
          await _upsertServerTransaction(
            txn,
            accountScope,
            change.transaction!,
          );
        }
      }
      await _ensureSyncState(txn, accountScope);
      await txn.update(
        'transaction_sync_state',
        {
          'cursor': response.nextCursor,
          'server_revision': response.serverRevision,
          'status': 'synced',
          'last_synced_at': DateTime.now().toUtc().toIso8601String(),
          'last_error_code': null,
        },
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
    });
  }

  Future<void> resolveConflictUsingServer(
    String accountScope,
    String clientTransactionId,
  ) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'local_transactions',
        columns: ['conflict_json'],
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientTransactionId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['conflict_json'] == null) return;
      final server = Transaction.fromJson(
        jsonDecode(rows.first['conflict_json'] as String)
            as Map<String, dynamic>,
      );
      await txn.delete(
        'mutation_outbox',
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientTransactionId],
      );
      if (server.deletedAt != null) {
        await txn.update(
          'local_transactions',
          {
            'revision': server.revision,
            'deleted_at': server.deletedAt,
            'sync_state': 'synced',
            'sync_error_code': null,
            'conflict_json': null,
          },
          where: 'account_scope = ? AND client_transaction_id = ?',
          whereArgs: [accountScope, clientTransactionId],
        );
      } else {
        await _upsertServerTransaction(txn, accountScope, server);
      }
    });
  }

  Future<void> resolveConflictKeepingLocal({
    required String accountScope,
    required String clientTransactionId,
    required String operationId,
    required String replacementClientTransactionId,
  }) async {
    await database.transaction((txn) async {
      final rows = await txn.query(
        'local_transactions',
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientTransactionId],
        limit: 1,
      );
      if (rows.isEmpty || rows.first['conflict_json'] == null) return;
      final local = _transactionFromRow(rows.first);
      final conflict = Transaction.fromJson(
        jsonDecode(rows.first['conflict_json'] as String)
            as Map<String, dynamic>,
      );
      await txn.delete(
        'mutation_outbox',
        where: 'account_scope = ? AND client_transaction_id = ?',
        whereArgs: [accountScope, clientTransactionId],
      );
      if (conflict.deletedAt != null) {
        await txn.update(
          'local_transactions',
          {
            'revision': conflict.revision,
            'deleted_at': conflict.deletedAt,
            'sync_state': 'synced',
            'sync_error_code': null,
            'conflict_json': null,
          },
          where: 'account_scope = ? AND client_transaction_id = ?',
          whereArgs: [accountScope, clientTransactionId],
        );
        final replacement = Transaction.fromJson({
          ...local.toJson(),
          'id': null,
          'clientTransactionId': replacementClientTransactionId,
          'revision': null,
          'deletedAt': null,
          'syncState': 'pending',
          'syncErrorCode': null,
        });
        await txn.insert(
          'local_transactions',
          _transactionValues(accountScope, replacement),
        );
        await txn.insert('mutation_outbox', {
          'operation_id': operationId,
          'account_scope': accountScope,
          'client_transaction_id': replacementClientTransactionId,
          'mutation_type': 'CREATE',
          'payload_json': jsonEncode(replacement.toJson()),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await txn.update(
          'local_transactions',
          {
            'revision': conflict.revision,
            'sync_state': 'pending',
            'sync_error_code': null,
            'conflict_json': null,
          },
          where: 'account_scope = ? AND client_transaction_id = ?',
          whereArgs: [accountScope, clientTransactionId],
        );
        await txn.insert('mutation_outbox', {
          'operation_id': operationId,
          'account_scope': accountScope,
          'client_transaction_id': clientTransactionId,
          'mutation_type': 'UPDATE',
          'base_revision': conflict.revision,
          'payload_json': jsonEncode(local.toJson()),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await _markAccountPending(txn, accountScope);
    });
  }

  Future<void> markSyncStatus(
    String accountScope,
    String status, {
    String? errorCode,
  }) async {
    await database.transaction((txn) async {
      await _ensureSyncState(txn, accountScope);
      await txn.update(
        'transaction_sync_state',
        {'status': status, 'last_error_code': errorCode},
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
    });
  }

  Future<LocalTransactionSyncStatus> syncStatus(String accountScope) async {
    final stateRows = await database.query(
      'transaction_sync_state',
      where: 'account_scope = ?',
      whereArgs: [accountScope],
      limit: 1,
    );
    final pendingMutations =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''SELECT COUNT(*) FROM mutation_outbox
               WHERE account_scope = ? AND state IN ('pending', 'failed')''',
            [accountScope],
          ),
        ) ??
        0;
    final pendingCaptures =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''SELECT COUNT(*) FROM pending_captures
               WHERE account_scope = ? AND state = 'pending' ''',
            [accountScope],
          ),
        ) ??
        0;
    final pending = pendingMutations + pendingCaptures;
    final conflicts =
        Sqflite.firstIntValue(
          await database.rawQuery(
            '''SELECT COUNT(*) FROM local_transactions
               WHERE account_scope = ? AND sync_state = 'conflict' ''',
            [accountScope],
          ),
        ) ??
        0;
    final row = stateRows.isEmpty ? const <String, Object?>{} : stateRows.first;
    return LocalTransactionSyncStatus(
      status: row['status'] as String? ?? (pending > 0 ? 'pending' : 'local'),
      pendingCount: pending,
      conflictCount: conflicts,
      lastSyncedAt: DateTime.tryParse(row['last_synced_at'] as String? ?? ''),
      lastErrorCode: row['last_error_code'] as String?,
    );
  }

  Future<void> migrateAccountScope(String from, String to) async {
    if (from == to) return;
    await database.transaction((txn) async {
      await txn.rawInsert(
        '''
        INSERT OR IGNORE INTO local_transactions (
          account_scope, client_transaction_id, server_id, date, amount,
          category, payment_method, description, input_type,
          validation_status, capture_id, capture_mode, source_package,
          source_notification_posted_at, revision, created_at, updated_at,
          deleted_at, sync_state, sync_error_code, conflict_json
        )
        SELECT ?, client_transaction_id, server_id, date, amount,
          category, payment_method, description, input_type,
          validation_status, capture_id, capture_mode, source_package,
          source_notification_posted_at, revision, created_at, updated_at,
          deleted_at, sync_state, sync_error_code, conflict_json
        FROM local_transactions
        WHERE account_scope = ?
        ''',
        [to, from],
      );
      await txn.update(
        'mutation_outbox',
        {'account_scope': to},
        where: 'account_scope = ?',
        whereArgs: [from],
      );
      await txn.delete(
        'local_transactions',
        where: 'account_scope = ?',
        whereArgs: [from],
      );
      await txn.update(
        'pending_captures',
        {'account_scope': to},
        where: 'account_scope = ?',
        whereArgs: [from],
      );
      final oldState = await txn.query(
        'transaction_sync_state',
        where: 'account_scope = ?',
        whereArgs: [from],
        limit: 1,
      );
      if (oldState.isNotEmpty) {
        await txn.insert('transaction_sync_state', {
          ...oldState.first,
          'account_scope': to,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        await txn.delete(
          'transaction_sync_state',
          where: 'account_scope = ?',
          whereArgs: [from],
        );
      }
    });
  }

  Future<void> clearAccount(String accountScope) async {
    await database.transaction((txn) async {
      await txn.delete(
        'local_transactions',
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
      await txn.delete(
        'pending_captures',
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
      await txn.delete(
        'transaction_sync_state',
        where: 'account_scope = ?',
        whereArgs: [accountScope],
      );
    });
  }

  Future<void> queueCapture({
    required String queueId,
    required String accountScope,
    required String type,
    required String payload,
    Duration retention = const Duration(days: 7),
  }) async {
    final now = DateTime.now().toUtc();
    await database.insert('pending_captures', {
      'capture_queue_id': queueId,
      'account_scope': accountScope,
      'capture_type': type,
      'payload': payload,
      'created_at': now.toIso8601String(),
      'expires_at': now.add(retention).toIso8601String(),
    });
  }

  Future<List<PendingCapture>> pendingCaptures(
    String accountScope, {
    int limit = 20,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.delete(
      'pending_captures',
      where: 'account_scope = ? AND expires_at <= ?',
      whereArgs: [accountScope, now],
    );
    final rows = await database.query(
      'pending_captures',
      where: 'account_scope = ? AND state = ?',
      whereArgs: [accountScope, 'pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows
        .map(
          (row) => PendingCapture(
            id: row['capture_queue_id'] as String,
            type: row['capture_type'] as String,
            payload: row['payload'] as String,
          ),
        )
        .toList();
  }

  Future<void> completeCapture(String captureId) async {
    await database.delete(
      'pending_captures',
      where: 'capture_queue_id = ?',
      whereArgs: [captureId],
    );
  }

  Future<void> failCapture(
    String captureId, {
    required String errorCode,
    required bool retryable,
  }) async {
    await database.rawUpdate(
      '''
      UPDATE pending_captures
         SET state = ?,
             attempt_count = attempt_count + 1,
             last_error_code = ?
       WHERE capture_queue_id = ?
      ''',
      [retryable ? 'pending' : 'failed', errorCode, captureId],
    );
  }

  Future<void> close() => database.close();

  static Future<void> _ensureSyncState(
    DatabaseExecutor executor,
    String accountScope,
  ) async {
    await executor.insert('transaction_sync_state', {
      'account_scope': accountScope,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _markAccountPending(
    DatabaseExecutor executor,
    String accountScope,
  ) async {
    await _ensureSyncState(executor, accountScope);
    await executor.update(
      'transaction_sync_state',
      {'status': 'pending', 'last_error_code': null},
      where: 'account_scope = ?',
      whereArgs: [accountScope],
    );
  }

  static Future<void> _scheduleRetry(
    DatabaseExecutor executor,
    String operationId,
    String? errorCode,
  ) async {
    final rows = await executor.query(
      'mutation_outbox',
      columns: ['attempt_count'],
      where: 'operation_id = ?',
      whereArgs: [operationId],
      limit: 1,
    );
    final attempt = ((rows.firstOrNull?['attempt_count'] as int?) ?? 0) + 1;
    final seconds = (1 << attempt.clamp(0, 8)) * 5;
    await executor.update(
      'mutation_outbox',
      {
        'attempt_count': attempt,
        'next_attempt_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: seconds))
            .toIso8601String(),
        'last_error_code': errorCode,
      },
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  static Future<void> _upsertServerTransaction(
    DatabaseExecutor executor,
    String accountScope,
    Transaction transaction,
  ) async {
    final clientId = transaction.clientTransactionId;
    if (clientId == null) return;
    await executor.insert(
      'local_transactions',
      _transactionValues(
        accountScope,
        transaction.copyWith(syncState: 'synced'),
      ),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Map<String, Object?> _transactionValues(
    String accountScope,
    Transaction transaction,
  ) => {
    'account_scope': accountScope,
    'client_transaction_id': transaction.clientTransactionId,
    'server_id': transaction.id,
    'date': transaction.date,
    'amount': transaction.amount,
    'category': transaction.category,
    'payment_method': transaction.paymentMethod,
    'description': transaction.description,
    'input_type': transaction.inputType,
    'validation_status': transaction.validationStatus,
    'capture_id': transaction.captureId,
    'capture_mode': transaction.captureMode,
    'source_package': transaction.sourcePackage,
    'source_notification_posted_at': transaction.sourceNotificationPostedAt,
    'revision': transaction.revision,
    'created_at': transaction.createdAt,
    'updated_at': transaction.updatedAt,
    'deleted_at': transaction.deletedAt,
    'sync_state': transaction.syncState,
    'sync_error_code': transaction.syncErrorCode,
  };

  static Transaction _transactionFromRow(Map<String, Object?> row) =>
      Transaction(
        id: row['server_id'] as int?,
        clientTransactionId: row['client_transaction_id'] as String?,
        date: row['date'] as String?,
        amount: (row['amount'] as num?)?.toDouble(),
        category: row['category'] as String?,
        paymentMethod: row['payment_method'] as String?,
        description: row['description'] as String?,
        inputType: row['input_type'] as String?,
        validationStatus: row['validation_status'] as String?,
        captureId: row['capture_id'] as String?,
        captureMode: row['capture_mode'] as String?,
        sourcePackage: row['source_package'] as String?,
        sourceNotificationPostedAt:
            row['source_notification_posted_at'] as String?,
        revision: row['revision'] as int?,
        createdAt: row['created_at'] as String?,
        updatedAt: row['updated_at'] as String?,
        deletedAt: row['deleted_at'] as String?,
        syncState: row['sync_state'] as String? ?? 'synced',
        syncErrorCode: row['sync_error_code'] as String?,
      );
}
