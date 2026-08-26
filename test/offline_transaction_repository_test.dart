import 'dart:io';

import 'package:broke_ai_app/models/transaction_sync.dart';
import 'package:broke_ai_app/services/offline_database.dart';
import 'package:broke_ai_app/services/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'broke-ai-offline-test-',
    );
    databasePath = '${temporaryDirectory.path}${Platform.pathSeparator}test.db';
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<OfflineDatabase> open() => OfflineDatabase.open(
    databasePath: databasePath,
    factory: databaseFactoryFfi,
  );

  test('manual transaction and outbox survive database restart', () async {
    var database = await open();
    var repository = TransactionRepository(database);
    final created = await repository.createManualTransaction(
      accountScope: 'account-a',
      date: DateTime(2026, 8, 25),
      amount: 75000,
      category: 'Food',
      paymentMethod: 'GoPay',
      description: 'Dinner',
    );

    expect(created.clientTransactionId, isNotNull);
    expect((await database.pendingMutations('account-a')), hasLength(1));
    await database.close();

    database = await open();
    repository = TransactionRepository(database);
    addTearDown(database.close);
    final dashboard = await repository.dashboard(
      'account-a',
      DateTime(2026, 8),
    );

    expect(dashboard.history.single.description, 'Dinner');
    expect(dashboard.summary.total, 75000);
    expect((await database.pendingMutations('account-a')), hasLength(1));
  });

  test(
    'editing an unsynced create coalesces into one create mutation',
    () async {
      final database = await open();
      addTearDown(database.close);
      final repository = TransactionRepository(database);
      final created = await repository.createManualTransaction(
        accountScope: 'account-a',
        date: DateTime(2026, 8, 25),
        amount: 10000,
        category: 'Food',
        paymentMethod: 'Cash',
        description: 'Draft',
      );

      await repository.updateTransaction(
        accountScope: 'account-a',
        current: created,
        date: DateTime(2026, 8, 25),
        amount: 15000,
        category: 'Food',
        paymentMethod: 'Cash',
        description: 'Final',
      );
      final mutations = await database.pendingMutations('account-a');

      expect(mutations, hasLength(1));
      expect(mutations.single.type, TransactionMutationType.create);
      expect(mutations.single.transaction?.amount, 15000);
      expect(mutations.single.transaction?.description, 'Final');
    },
  );

  test(
    'deleting an unsynced create removes it without a server mutation',
    () async {
      final database = await open();
      addTearDown(database.close);
      final repository = TransactionRepository(database);
      final created = await repository.createManualTransaction(
        accountScope: 'account-a',
        date: DateTime(2026, 8, 25),
        amount: 10000,
        category: 'Food',
        paymentMethod: 'Cash',
        description: 'Remove me',
      );

      await repository.deleteTransaction(
        accountScope: 'account-a',
        transaction: created,
      );

      expect((await database.pendingMutations('account-a')), isEmpty);
      expect(
        (await repository.dashboard('account-a', DateTime(2026, 8))).history,
        isEmpty,
      );
    },
  );

  test(
    'server conflict preserves the local draft and marks attention',
    () async {
      final database = await open();
      addTearDown(database.close);
      final repository = TransactionRepository(database);
      final local = await repository.createManualTransaction(
        accountScope: 'account-a',
        date: DateTime(2026, 8, 25),
        amount: 50000,
        category: 'Lifestyle',
        paymentMethod: 'Card',
        description: 'Local draft',
      );
      final createOperation = (await database.pendingMutations(
        'account-a',
      )).single;
      final serverVersion = local.copyWith(
        id: 91,
        revision: 1,
        syncState: 'synced',
        description: 'Initial server value',
      );
      await database.applyPushResponse(
        'account-a',
        SyncPushResponse(
          serverRevision: 1,
          results: [
            SyncOperationResult(
              operationId: createOperation.operationId,
              status: 'APPLIED',
              transaction: serverVersion,
            ),
          ],
        ),
      );
      final synced = await database.transaction(
        'account-a',
        local.clientTransactionId!,
      );
      final edited = await repository.updateTransaction(
        accountScope: 'account-a',
        current: synced!,
        date: DateTime(2026, 8, 25),
        amount: 55000,
        category: 'Lifestyle',
        paymentMethod: 'Card',
        description: 'Keep this local draft',
      );
      final updateOperation = (await database.pendingMutations(
        'account-a',
      )).single;
      await database.applyPushResponse(
        'account-a',
        SyncPushResponse(
          serverRevision: 2,
          results: [
            SyncOperationResult(
              operationId: updateOperation.operationId,
              status: 'CONFLICT',
              errorCode: 'TRANSACTION_REVISION_CONFLICT',
              transaction: serverVersion.copyWith(
                revision: 2,
                description: 'Changed elsewhere',
              ),
            ),
          ],
        ),
      );

      final preserved = await database.transaction(
        'account-a',
        edited.clientTransactionId!,
      );
      expect(preserved?.description, 'Keep this local draft');
      expect(preserved?.syncState, 'conflict');
      expect((await database.syncStatus('account-a')).conflictCount, 1);
    },
  );

  test('local queries never cross account scopes', () async {
    final database = await open();
    addTearDown(database.close);
    final repository = TransactionRepository(database);
    await repository.createManualTransaction(
      accountScope: 'account-a',
      date: DateTime(2026, 8, 25),
      amount: 10000,
      category: 'Food',
      paymentMethod: 'Cash',
      description: 'Account A',
    );
    await repository.createManualTransaction(
      accountScope: 'account-b',
      date: DateTime(2026, 8, 25),
      amount: 20000,
      category: 'Transport',
      paymentMethod: 'Cash',
      description: 'Account B',
    );

    final accountA = await repository.dashboard('account-a', DateTime(2026, 8));
    final accountB = await repository.dashboard('account-b', DateTime(2026, 8));
    expect(accountA.history.single.description, 'Account A');
    expect(accountB.history.single.description, 'Account B');
  });
}
