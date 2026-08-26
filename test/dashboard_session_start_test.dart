import 'package:broke_ai_app/models/expense_summary.dart';
import 'package:broke_ai_app/models/session.dart';
import 'package:broke_ai_app/models/transaction.dart';
import 'package:broke_ai_app/providers/app_providers.dart';
import 'package:broke_ai_app/services/api_client.dart';
import 'package:broke_ai_app/services/offline_database.dart';
import 'package:broke_ai_app/services/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

void main() {
  setUpAll(sqfliteFfiInit);

  test('dashboard renders from local storage without API reads', () async {
    final database = await OfflineDatabase.open(
      databasePath: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    addTearDown(database.close);
    final api = _ReadTrackingApi();
    final session = Session(
      token: 'token',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      username: 'offline-user',
      isGuest: false,
      accountId: '48eb7d8b-2fc4-42d6-8795-6ae031bf7053',
    );
    final container = ProviderContainer(
      overrides: [
        apiProvider.overrideWithValue(api),
        sessionProvider.overrideWith((ref) async => session),
        offlineDatabaseProvider.overrideWith((ref) async => database),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      transactionRepositoryProvider.future,
    );
    await repository.createManualTransaction(
      accountScope: session.accountScope,
      date: DateTime.now(),
      amount: 42000,
      category: 'Food',
      paymentMethod: 'Cash',
      description: 'Offline lunch',
    );
    final dashboard = await container.read(dashboardProvider.future);

    expect(dashboard.history, hasLength(1));
    expect(dashboard.summary.total, 42000);
    expect(api.calls, isEmpty);
  });
}

class _ReadTrackingApi extends ApiClient {
  _ReadTrackingApi() : super(SessionStore());

  final calls = <String>[];

  @override
  Future<ExpenseSummary> summary(DateTime month) async {
    calls.add('summary');
    return const ExpenseSummary(0, []);
  }

  @override
  Future<List<Transaction>> history(DateTime month) async {
    calls.add('history');
    return const [];
  }

  @override
  Future<List<Transaction>> recentTransactions() async {
    calls.add('recent');
    return const [];
  }
}
