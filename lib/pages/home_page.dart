import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import '../utils/transaction_visuals.dart';
import '../widgets/common_widgets.dart';
import '../widgets/surface_card.dart';
import '../widgets/transaction_tile.dart';
import 'history_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    final user = ref.watch(sessionProvider).value;
    return SafeArea(
      child: dashboard.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (error, _) => _HomeError(error: error.toString()),
        data: (data) => RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => ref.refresh(dashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.displayName.split(' ').first ?? 'There'}',
                          style: const TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Let\'s track your spending!',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.notifications_none_rounded),
                ],
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                tint: AppColors.goldDark,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('This month\'s expense'),
                          const SizedBox(height: 8),
                          Text(
                            money(data.summary.total),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Synced',
                            style: TextStyle(color: AppColors.cream),
                          ),
                        ],
                      ),
                    ),
                    const HeroIcon(
                      icon: Icons.account_balance_wallet_rounded,
                      size: 76,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  MetricCard(
                    label: 'Today',
                    value: money(
                      data.history
                          .where((transaction) => isToday(transaction.tanggal))
                          .fold<double>(
                            0,
                            (sum, item) => sum + (item.jumlah ?? 0),
                          ),
                    ),
                    icon: Icons.today_outlined,
                    color: AppColors.sage,
                  ),
                  const SizedBox(width: 12),
                  MetricCard(
                    label: 'Transactions',
                    value: '${data.history.length}',
                    icon: Icons.receipt_long_outlined,
                    color: AppColors.coral,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Row(
                children: [
                  Text(
                    'Spending overview',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  Spacer(),
                  MonthPicker(),
                ],
              ),
              const SizedBox(height: 10),
              SurfaceCard(child: _SpendingChart(data: data)),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Newest activities',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const HistoryPage(),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded, size: 19),
                    label: const Text('History'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: data.recent.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No activities yet..',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : Column(
                        children: data.recent
                            .take(5)
                            .map(
                              (transaction) =>
                                  TransactionTile(transaction: transaction),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    if (data.summary.categories.isEmpty || data.summary.total <= 0) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No transactions yet',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 145,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 40,
              sectionsSpace: 3,
              sections: data.summary.categories
                  .map(
                    (category) => PieChartSectionData(
                      value: category.total,
                      color: categoryColor(category.name),
                      radius: 38,
                      title: '',
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: data.summary.categories.map((category) {
            final percentage = (category.total / data.summary.total * 100)
                .round();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  categoryIcon(category.name),
                  size: 15,
                  color: categoryColor(category.name),
                ),
                const SizedBox(width: 5),
                Text(
                  '${category.name} ($percentage%)',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HomeError extends ConsumerWidget {
  const _HomeError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
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
  );
}
