import 'package:flutter/material.dart';

import '../core/app_theme.dart';
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
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: PaymentMethodLogo(paymentMethod: transaction.paymentMethod),
      title: Text(
        category,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${description?.isNotEmpty == true ? description : 'No description'} • ${shortDate(transaction.date)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted, height: 1.3),
      ),
      trailing:
          trailing ??
          Text(
            '-${money(transaction.amount ?? 0)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
    );
  }
}
