import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../models/transaction.dart';
import '../models/session.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../services/offline_database.dart';
import '../utils/formatters.dart';
import '../utils/transaction_visuals.dart';
import '../widgets/common_widgets.dart';
import '../widgets/mascot_image.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/surface_card.dart';
import '../widgets/transaction_tile.dart';
import 'history_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _openHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final localSync = ref.watch(localTransactionSyncStatusProvider).value;
    final selectedMonth = ref.watch(selectedMonthProvider);
    final user = ref.watch(sessionProvider).value;
    return SafeArea(
      bottom: false,
      child: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _HomeError(error: apiErrorMessage(error)),
        data: (data) {
          final todayTotal = data.history
              .where((transaction) => isToday(transaction.date))
              .fold<double>(0, (sum, item) => sum + (item.amount ?? 0));
          return RefreshIndicator(
            color: AppColors.primaryAccent,
            onRefresh: () => synchronizeTransactions(ref),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 108),
              children: [
                _HomeHeader(
                  name: user?.displayName.split(' ').first ?? 'Guest',
                ),
                if (user != null &&
                    localSync != null &&
                    (localSync.status != 'synced' || localSync.hasPending)) ...[
                  const SizedBox(height: 12),
                  _OfflineSyncBanner(session: user, status: localSync),
                ],
                const SizedBox(height: 22),
                _ExpenseSummaryCard(data: data),
                const SizedBox(height: 16),
                Row(
                  children: [
                    MetricCard(
                      label: 'Today',
                      value: money(todayTotal),
                      icon: Icons.calendar_today_rounded,
                      color: const Color(0xff2586f5),
                    ),
                    const SizedBox(width: 12),
                    MetricCard(
                      label: 'Transactions',
                      value: '${data.history.length}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.coral,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Spending overview',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          MonthPicker(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SpendingChart(data: data, month: selectedMonth),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Newest activities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openHistory(context),
                      icon: const Icon(Icons.history_rounded, size: 19),
                      label: const Text('History'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _RecentActivityCard(
                  transactions: data.recent.take(5).toList(),
                  onViewAll: () => _openHistory(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner({required this.session, required this.status});

  final Session session;
  final LocalTransactionSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, color) = switch (status.status) {
      'syncing' => (
        Icons.sync_rounded,
        'Syncing',
        'Updating the copy saved on this device.',
        const Color(0xff2586f5),
      ),
      'authentication_required' => (
        Icons.lock_clock_outlined,
        'Sign in to sync',
        'Your data is safe on this device. Reauthenticate to back it up.',
        AppColors.coral,
      ),
      'conflict' => (
        Icons.warning_amber_rounded,
        'Some changes need attention',
        '${status.conflictCount} transaction conflict${status.conflictCount == 1 ? '' : 's'} preserved locally.',
        AppColors.coral,
      ),
      'failed' => (
        Icons.cloud_off_rounded,
        'Sync paused',
        'Changes remain saved on this device. Pull down to retry.',
        AppColors.coral,
      ),
      _ => (
        Icons.cloud_off_rounded,
        status.hasPending ? 'Changes saved on this device' : 'Offline copy',
        status.hasPending
            ? '${status.pendingCount} change${status.pendingCount == 1 ? '' : 's'} waiting to sync.'
            : session.canAuthenticate
            ? 'Pull down to check for updates.'
            : 'Sign in when online to resume cloud backup.',
        const Color(0xff7c5ce5),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Let\'s track your spending!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () {},
        color: AppColors.primaryAccent,
        iconSize: 27,
        icon: const Icon(Icons.notifications_none_rounded),
      ),
    ],
  );
}

class _ExpenseSummaryCard extends StatelessWidget {
  const _ExpenseSummaryCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 22, 18, 22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff8a4df8), Color(0xff427df5)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x285b50f6),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This month\'s expenses',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 9),
              Text(
                money(data.summary.total),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${data.history.length} transaction${data.history.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            color: Color(0xeef8fafc),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: AppColors.primaryAccent,
            size: 36,
          ),
        ),
      ],
    ),
  );
}

class _SpendingChart extends ConsumerStatefulWidget {
  const _SpendingChart({required this.data, required this.month});

  final DashboardData data;
  final DateTime month;

  @override
  ConsumerState<_SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends ConsumerState<_SpendingChart> {
  bool exporting = false;

  Future<void> _export() async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      await ref
          .read(expenseExportServiceProvider)
          .exportMonthly(
            transactions: widget.data.history,
            month: widget.month,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not export the Excel report. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.summary.categories.isEmpty || data.summary.total <= 0) {
      return Column(
        children: [
          const MascotImage(
            asset: AppAssets.dashboardDog,
            darkAsset: AppAssets.dashboardDogDark,
            height: 178,
            borderRadius: 18,
            alignment: Alignment(0, -.12),
          ),
          const SizedBox(height: 10),
          const Text(
            'No transactions yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Start adding your first expense\nto see your spending insights.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          _GradientActionButton(
            icon: Icons.add_rounded,
            label: 'Add Expense',
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ManualTransactionSheet(),
            ),
          ),
        ],
      );
    }

    final categories = data.summary.categories.take(6).toList();
    return Column(
      children: [
        SizedBox(
          height: 172,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                    sections: categories
                        .map(
                          (category) => PieChartSectionData(
                            value: category.totalAmount,
                            color: categoryColor(category.category),
                            radius: 27,
                            title: '',
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: categories.map((category) {
                    final percentage =
                        (category.totalAmount / data.summary.total * 100)
                            .round();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: categoryColor(category.category),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text.rich(
                              TextSpan(text: '${category.category} '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: exporting ? null : _export,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.table_view_rounded,
                  size: 20,
                  color: AppColors.primaryAccent,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Export to Excel (.xlsx)',
                    style: TextStyle(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (exporting)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else
                  const Icon(
                    Icons.download_rounded,
                    color: AppColors.primaryAccent,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xff8a4df8), Color(0xff278df5)],
      ),
      borderRadius: BorderRadius.circular(99),
      boxShadow: const [
        BoxShadow(
          color: Color(0x305b50f6),
          blurRadius: 16,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.transactions,
    required this.onViewAll,
  });

  final List<Transaction> transactions;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    padding: EdgeInsets.zero,
    child: transactions.isEmpty
        ? const Padding(
            padding: EdgeInsets.fromLTRB(20, 34, 20, 34),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xffc9d2fb),
                  size: 62,
                ),
                SizedBox(height: 16),
                Text(
                  'No activities yet',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 5),
                Text(
                  'Your recent transactions will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : Column(
            children: [
              ...transactions.asMap().entries.map(
                (entry) => TransactionTile(transaction: entry.value),
              ),
              InkWell(
                onTap: onViewAll,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View all transactions',
                          style: TextStyle(
                            color: AppColors.primaryAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primaryAccent,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class _HomeError extends ConsumerWidget {
  const _HomeError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => ref.invalidate(dashboardProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
