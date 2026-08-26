import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../utils/formatters.dart';
import 'payment_method_logo.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.trailing,
  });

  final Transaction transaction;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final category = transaction.category ?? 'Other';
    final description = transaction.description?.trim();
    final source = transaction.captureMode == 'AUTOMATIC'
        ? 'Auto-captured · '
        : '';
    final syncLabel = switch (transaction.syncState) {
      'pending' => ' · Saved on device',
      'failed' => ' · Sync failed',
      'conflict' => ' · Needs attention',
      _ => '',
    };
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: PaymentMethodLogo(paymentMethod: transaction.paymentMethod),
      title: Text(
        category,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '$source${description?.isNotEmpty == true ? description : 'No description'} · ${shortDate(transaction.date)}$syncLabel',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.3,
          fontSize: 12.5,
        ),
      ),
      trailing:
          trailing ??
          Text(
            '-${money(transaction.amount ?? 0)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
    );
  }
}
