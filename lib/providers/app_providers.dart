import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expense_summary.dart';
import '../models/account_settings.dart';
import '../models/session.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/app_lock_service.dart';
import '../services/expense_export_service.dart';
import '../services/session_store.dart';
import '../services/settings_repository.dart';
import '../services/notification_capture_service.dart';
import '../services/device_identity_store.dart';
import '../services/offline_database.dart';
import '../services/transaction_repository.dart';
import '../services/transaction_sync_service.dart';
import '../utils/offline_ids.dart';

typedef DashboardData = ({
  ExpenseSummary summary,
  List<Transaction> history,
  List<Transaction> recent,
});

final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());
final notificationCaptureServiceProvider = Provider<NotificationCaptureService>(
  (_) => NotificationCaptureService(),
);
final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(sessionStoreProvider),
    onUnauthorized: () {
      unawaited(ref.read(notificationCaptureServiceProvider).clear());
      ref.invalidate(sessionProvider);
    },
  ),
);
final expenseExportServiceProvider = Provider<ExpenseExportService>(
  (_) => const ExpenseExportService(),
);
final sessionProvider = FutureProvider<Session?>(
  (ref) => ref.watch(sessionStoreProvider).read(),
);
final deviceIdentityStoreProvider = Provider<DeviceIdentityStore>(
  (_) => DeviceIdentityStore(),
);
final offlineDatabaseProvider = FutureProvider<OfflineDatabase>((ref) async {
  final database = await OfflineDatabase.open();
  final session = await ref.watch(sessionStoreProvider).read();
  if (session != null) {
    await _migrateLegacyCaptureQueue(database, session.accountScope);
  }
  ref.onDispose(database.close);
  return database;
});
final transactionRepositoryProvider = FutureProvider<TransactionRepository>((
  ref,
) async {
  return TransactionRepository(await ref.watch(offlineDatabaseProvider.future));
});
final showAuthProvider = StateProvider<bool>((_) => false);
final authStartInLoginProvider = StateProvider<bool>((_) => false);
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.light);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(apiProvider),
    accountScope: ref.watch(sessionProvider).value?.accountScope,
    // A loading session is not assumed to be a guest. Once the session
    // resolves, Riverpod rebuilds this repository with the correct scope.
    localOnly: ref.watch(sessionProvider).value?.isGuest ?? false,
  ),
);

final accountPreferencesProvider = FutureProvider<AccountPreferences>(
  (ref) => ref.watch(settingsRepositoryProvider).accountPreferences(),
);

final syncStatusProvider = FutureProvider<SyncStatus>(
  (ref) => ref.watch(settingsRepositoryProvider).syncStatus(),
);

typedef ProfileDraft = ({String fullName, String username, String email});

final profileDraftProvider = StateProvider<ProfileDraft?>((_) => null);

class LocalePreferences {
  const LocalePreferences({
    this.currencyCode = 'IDR',
    this.language = 'English',
    this.region = 'Indonesia',
  });

  final String currencyCode;
  final String language;
  final String region;

  LocalePreferences copyWith({
    String? currencyCode,
    String? language,
    String? region,
  }) => LocalePreferences(
    currencyCode: currencyCode ?? this.currencyCode,
    language: language ?? this.language,
    region: region ?? this.region,
  );
}

final localePreferencesProvider = StateProvider<LocalePreferences>(
  (_) => const LocalePreferences(),
);
final appLockServiceProvider = Provider<AppLockService>(
  (_) => AppLockService(),
);
final appLockSettingsProvider = FutureProvider<AppLockSettings>(
  (ref) => ref.watch(appLockServiceProvider).read(),
);

/// This intentionally starts false on every process launch. The persisted
/// configuration decides whether AuthGate must show the PIN screen.
final appUnlockedProvider = StateProvider<bool>((_) => false);

enum AppLockRecoveryStep { none, reauthenticate, chooseAction, changePin }

final appLockRecoveryProvider = StateProvider<AppLockRecoveryStep>(
  (_) => AppLockRecoveryStep.none,
);
final privacyAnalyticsProvider = StateProvider<bool>((_) => true);
final personalizedInsightsProvider = StateProvider<bool>((_) => true);
final selectedMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);
final remainingAiTrialsProvider = StateProvider<int?>((ref) {
  final session = ref.watch(sessionProvider).value;
  return session?.isGuest == true ? session!.remainingAiTrials : null;
});
final localTransactionSyncStatusProvider =
    FutureProvider<LocalTransactionSyncStatus>((ref) async {
      final session = await ref.watch(sessionProvider.future);
      if (session == null) {
        return const LocalTransactionSyncStatus(
          status: 'local',
          pendingCount: 0,
          conflictCount: 0,
        );
      }
      final repository = await ref.watch(transactionRepositoryProvider.future);
      return repository.syncStatus(session.accountScope);
    });

final transactionSyncServiceProvider = FutureProvider<TransactionSyncService>((
  ref,
) async {
  return TransactionSyncService(
    ref.watch(apiProvider),
    ref.watch(sessionStoreProvider),
    await ref.watch(offlineDatabaseProvider.future),
    ref.watch(deviceIdentityStoreProvider),
    onDataChanged: () {
      ref.invalidate(dashboardProvider);
      ref.invalidate(localTransactionSyncStatusProvider);
    },
    onSessionChanged: () => ref.invalidate(sessionProvider),
  );
});

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  final session = await ref.watch(sessionProvider.future);
  if (session == null) {
    return (
      summary: const ExpenseSummary(0, []),
      history: <Transaction>[],
      recent: <Transaction>[],
    );
  }
  final repository = await ref.watch(transactionRepositoryProvider.future);
  final local = await repository.dashboard(session.accountScope, month);
  return (summary: local.summary, history: local.history, recent: local.recent);
});

void refreshTransactionState(Ref ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(localTransactionSyncStatusProvider);
}

Future<void> synchronizeTransactions(WidgetRef ref) async {
  final service = await ref.read(transactionSyncServiceProvider.future);
  await service.synchronize();
  ref.invalidate(dashboardProvider);
  ref.invalidate(localTransactionSyncStatusProvider);
}

Future<void> _migrateLegacyCaptureQueue(
  OfflineDatabase database,
  String accountScope,
) async {
  final preferences = await SharedPreferences.getInstance();
  final legacy = preferences.getStringList('offline_queue');
  if (legacy == null || legacy.isEmpty) return;
  for (final raw in legacy) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final type = json['type'] as String?;
      final payload = json['payload'] as String?;
      if ((type == 'receipt' || type == 'notification') &&
          payload != null &&
          payload.isNotEmpty) {
        await database.queueCapture(
          queueId: newUuid(),
          accountScope: accountScope,
          type: type!,
          payload: payload,
        );
      }
    } catch (_) {
      // Invalid legacy entries cannot be replayed safely.
    }
  }
  await preferences.remove('offline_queue');
}
