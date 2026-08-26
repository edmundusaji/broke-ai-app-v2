import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/expense_summary.dart';
import '../models/transaction.dart';
import '../utils/offline_ids.dart';
import 'offline_database.dart';

class LocalDashboardData {
  const LocalDashboardData({
    required this.summary,
    required this.history,
    required this.recent,
  });

  final ExpenseSummary summary;
  final List<Transaction> history;
  final List<Transaction> recent;
}

class TransactionRepository {
  const TransactionRepository(this._database);

  final OfflineDatabase _database;

  Future<LocalDashboardData> dashboard(
    String accountScope,
    DateTime month,
  ) async {
    final history = await _database.transactionsForMonth(accountScope, month);
    final recent = await _database.recentTransactions(accountScope);
    final categoryTotals = <String, double>{};
    var total = 0.0;
    for (final transaction in history) {
      final amount = transaction.amount ?? 0;
      total += amount;
      final category = transaction.category?.trim().isNotEmpty == true
          ? transaction.category!.trim()
          : 'Other';
      categoryTotals.update(
        category,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    final categories =
        categoryTotals.entries
            .map((entry) => CategorySummary(entry.key, entry.value))
            .toList()
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return LocalDashboardData(
      summary: ExpenseSummary(total, categories),
      history: history,
      recent: recent,
    );
  }

  Future<Transaction> createManualTransaction({
    required String accountScope,
    required DateTime date,
    required double amount,
    required String category,
    required String paymentMethod,
    required String description,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final transaction = Transaction(
      clientTransactionId: newUuid(),
      date: date.toIso8601String(),
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      description: description,
      inputType: 'MANUAL',
      validationStatus: 'CONFIRMED',
      createdAt: now,
      updatedAt: now,
      syncState: 'pending',
    );
    await _database.insertLocalTransaction(
      accountScope: accountScope,
      transaction: transaction,
      operationId: newUuid(),
    );
    return transaction;
  }

  Future<Transaction> updateTransaction({
    required String accountScope,
    required Transaction current,
    required DateTime date,
    required double amount,
    required String category,
    required String paymentMethod,
    required String description,
  }) async {
    final updated = current.copyWith(
      date: date.toIso8601String(),
      amount: amount,
      category: category,
      paymentMethod: paymentMethod,
      description: description,
      syncState: 'pending',
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _database.updateLocalTransaction(
      accountScope: accountScope,
      transaction: updated,
      operationId: newUuid(),
    );
    return updated;
  }

  Future<void> deleteTransaction({
    required String accountScope,
    required Transaction transaction,
  }) => _database.deleteLocalTransaction(
    accountScope: accountScope,
    transaction: transaction,
    operationId: newUuid(),
  );

  Future<int> clearTransactions(String accountScope) async {
    final transactions = await _database.activeTransactions(accountScope);
    for (final transaction in transactions) {
      await deleteTransaction(
        accountScope: accountScope,
        transaction: transaction,
      );
    }
    return transactions.length;
  }

  Future<void> queueNotificationText({
    required String accountScope,
    required String text,
  }) => _database.queueCapture(
    queueId: newUuid(),
    accountScope: accountScope,
    type: 'notification',
    payload: text,
  );

  Future<String> queueReceipt({
    required String accountScope,
    required File source,
  }) async {
    final queueId = newUuid();
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'offline_receipts'));
    await directory.create(recursive: true);
    final extension = path.extension(source.path).toLowerCase();
    final destination = File(
      path.join(
        directory.path,
        '$queueId${extension.isEmpty ? '.jpg' : extension}',
      ),
    );
    await source.copy(destination.path);
    await _database.queueCapture(
      queueId: queueId,
      accountScope: accountScope,
      type: 'receipt',
      payload: destination.path,
    );
    return destination.path;
  }

  Future<LocalTransactionSyncStatus> syncStatus(String accountScope) =>
      _database.syncStatus(accountScope);

  Future<void> resolveConflictUsingServer({
    required String accountScope,
    required String clientTransactionId,
  }) => _database.resolveConflictUsingServer(accountScope, clientTransactionId);

  Future<void> resolveConflictKeepingLocal({
    required String accountScope,
    required String clientTransactionId,
  }) => _database.resolveConflictKeepingLocal(
    accountScope: accountScope,
    clientTransactionId: clientTransactionId,
    operationId: newUuid(),
    replacementClientTransactionId: newUuid(),
  );

  Future<void> migrateAccountScope(String from, String to) =>
      _database.migrateAccountScope(from, to);

  Future<void> clearAccount(String accountScope) =>
      _database.clearAccount(accountScope);
}
