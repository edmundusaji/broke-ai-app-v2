import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../models/transaction.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../widgets/common_widgets.dart';
import '../widgets/manual_transaction_sheet.dart';
import '../widgets/surface_card.dart';
import '../widgets/transaction_tile.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        leading: const BackButton(),
        title: const Text('Transaction history'),
        actions: const [MonthPicker()],
      ),
      body: dashboard.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
        error: (error, _) => _HistoryError(error: apiErrorMessage(error)),
        data: (data) => RefreshIndicator(
          color: AppColors.gold,
          onRefresh: () => synchronizeTransactions(ref),
          child: data.history.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 220),
                    Center(
                      child: Text(
                        'No transactions in this month.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  itemCount: data.history.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (_, index) => SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: TransactionTile(
                      transaction: data.history[index],
                      onTap: () => _showTransactionActions(
                        context,
                        ref,
                        data.history[index],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _showTransactionActions(
    BuildContext context,
    WidgetRef ref,
    Transaction transaction,
  ) async {
    final action = await showModalBottomSheet<_HistoryAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SurfaceCard(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Transaction options',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.gold),
                title: const Text('Edit transaction'),
                onTap: () => Navigator.pop(sheetContext, _HistoryAction.edit),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Delete transaction',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(sheetContext, _HistoryAction.delete),
              ),
              if (transaction.syncState == 'conflict') ...[
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.phone_android_rounded,
                    color: AppColors.gold,
                  ),
                  title: const Text('Keep my version'),
                  subtitle: const Text('Retry using the latest cloud revision'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _HistoryAction.keepLocal),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Use cloud version'),
                  subtitle: const Text(
                    'Discard this device\'s conflicting edit',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _HistoryAction.useServer),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;

    if (action == _HistoryAction.keepLocal ||
        action == _HistoryAction.useServer) {
      final session = await ref.read(sessionProvider.future);
      final clientId = transaction.clientTransactionId;
      if (session == null || clientId == null) return;
      final repository = await ref.read(transactionRepositoryProvider.future);
      if (action == _HistoryAction.keepLocal) {
        await repository.resolveConflictKeepingLocal(
          accountScope: session.accountScope,
          clientTransactionId: clientId,
        );
      } else {
        await repository.resolveConflictUsingServer(
          accountScope: session.accountScope,
          clientTransactionId: clientId,
        );
      }
      ref.invalidate(dashboardProvider);
      ref.invalidate(localTransactionSyncStatusProvider);
      unawaited(synchronizeTransactions(ref));
      return;
    }

    if (action == _HistoryAction.edit) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ManualTransactionSheet(transaction: transaction),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || transaction.clientTransactionId == null) return;

    try {
      final session = await ref.read(sessionProvider.future);
      if (session == null) throw StateError('No local account is active.');
      final repository = await ref.read(transactionRepositoryProvider.future);
      await repository.deleteTransaction(
        accountScope: session.accountScope,
        transaction: transaction,
      );
      ref.invalidate(dashboardProvider);
      ref.invalidate(localTransactionSyncStatusProvider);
      unawaited(synchronizeTransactions(ref));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete transaction.')),
        );
      }
    }
  }
}

enum _HistoryAction { edit, delete, keepLocal, useServer }

class _HistoryError extends ConsumerWidget {
  const _HistoryError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.coral, size: 44),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => ref.invalidate(dashboardProvider),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
