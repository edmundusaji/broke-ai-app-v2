import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction_sync.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/device_identity_store.dart';
import 'package:broke_ai_app/services/offline_database.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:broke_ai_app/services/transaction_repository.dart';
import 'package:broke_ai_app/services/transaction_sync_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(sqfliteFfiInit);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('sync pushes local mutations and applies the server identity', () async {
    final database = await OfflineDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(database.close);
    final sessions = SessionStore();
    final session = Session(
      token: 'valid-token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      username: 'edmund',
      isGuest: false,
      accountId: '66b918e3-eb57-4e7e-8eb4-0636a8870f73',
    );
    await sessions.save(session);
    final repository = TransactionRepository(database);
    await repository.createManualTransaction(
      accountScope: session.accountScope,
      date: DateTime(2026, 8, 25),
      amount: 25000,
      category: 'Transport',
      paymentMethod: 'Cash',
      description: 'Bus',
    );
    final api = _SuccessfulSyncApi(sessions);
    final service = TransactionSyncService(
      api,
      sessions,
      database,
      DeviceIdentityStore(),
    );

    await service.synchronize();

    expect(api.pushedOperations, hasLength(1));
    expect(await database.pendingMutations(session.accountScope), isEmpty);
    final dashboard = await repository.dashboard(
      session.accountScope,
      DateTime(2026, 8),
    );
    expect(dashboard.history.single.id, 700);
    expect(dashboard.history.single.revision, 1);
    expect(dashboard.history.single.syncState, 'synced');
  });

  test('offline guest is usable locally before server bootstrap', () async {
    final store = SessionStore();
    final guest = await store.createOfflineGuest();

    expect(guest.valid, isTrue);
    expect(guest.canAuthenticate, isFalse);
    expect(guest.clientGuestId, isNotNull);
    expect(guest.installationCredential?.length, greaterThanOrEqualTo(32));
    expect((await SessionStore().read())?.accountScope, guest.accountScope);
  });
}

class _SuccessfulSyncApi extends ApiClient {
  _SuccessfulSyncApi(super.sessions);

  final pushedOperations = <TransactionMutation>[];

  @override
  Future<SyncPushResponse> pushTransactions({
    required String deviceId,
    required List<TransactionMutation> operations,
  }) async {
    pushedOperations.addAll(operations);
    return SyncPushResponse(
      serverRevision: 1,
      results: operations
          .map(
            (operation) => SyncOperationResult(
              operationId: operation.operationId,
              status: 'APPLIED',
              transaction: operation.transaction?.copyWith(
                id: 700,
                revision: 1,
                syncState: 'synced',
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<SyncPullResponse> pullTransactions({
    String? cursor,
    int limit = 100,
  }) async => const SyncPullResponse(
    changes: [],
    nextCursor: 'djE6MQ',
    hasMore: false,
    serverRevision: 1,
  );
}
