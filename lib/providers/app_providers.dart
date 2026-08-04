import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense_summary.dart';
import '../models/session.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/session_store.dart';

typedef DashboardData = ({ExpenseSummary summary, List<Transaction> history});

final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());
final apiProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
);
final sessionProvider = FutureProvider<Session?>(
  (ref) => ref.watch(sessionStoreProvider).read(),
);
final showAuthProvider = StateProvider<bool>((_) => false);
final selectedMonthProvider = StateProvider<DateTime>(
  (_) => DateTime(DateTime.now().year, DateTime.now().month),
);
final remainingAiTrialsProvider = StateProvider<int?>((ref) {
  final session = ref.watch(sessionProvider).value;
  return session?.isGuest == true ? session!.remainingAiTrials : null;
});
final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  final month = ref.watch(selectedMonthProvider);
  final api = ref.watch(apiProvider);
  final results = await Future.wait<Object>([
    api.summary(month),
    api.history(month),
  ]);
  return (
    summary: results[0] as ExpenseSummary,
    history: results[1] as List<Transaction>,
  );
});

void refreshTransactionState(Ref ref) {
  ref.invalidate(dashboardProvider);
}
