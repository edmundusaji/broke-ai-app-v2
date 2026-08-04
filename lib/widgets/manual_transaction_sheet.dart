import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/transaction.dart';
import '../payment_method_picker.dart';
import '../providers/app_providers.dart';
import '../utils/transaction_visuals.dart';
import 'surface_card.dart';

const manualTransactionCategories = <String>[
  'Food',
  'Transport',
  'Lifestyle',
  'Health',
  'Donation',
  'Utility',
  'Payment',
];

class ManualTransactionSheet extends ConsumerStatefulWidget {
  const ManualTransactionSheet({super.key, this.transaction});
  final Transaction? transaction;

  @override
  ConsumerState<ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState
    extends ConsumerState<ManualTransactionSheet> {
  late final TextEditingController amountController;
  late DateTime date;
  String? category;
  String? paymentMethod;
  bool saving = false;
  bool showValidation = false;

  bool get editing => widget.transaction?.id != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    amountController = TextEditingController(
      text: transaction?.jumlah?.toString() ?? '',
    );
    category = _canonicalCategory(transaction?.kategori);
    paymentMethod = transaction?.merchant?.trim().isNotEmpty == true
        ? transaction!.merchant!.trim()
        : null;
    date = DateTime.tryParse(transaction?.tanggal ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  Future<void> _selectPayment() async {
    final selected = await showPaymentMethodPicker(
      context,
      selectedValue: paymentMethod,
    );
    if (selected != null && mounted) {
      setState(() {
        paymentMethod = selected;
        showValidation = false;
      });
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (amount == null ||
        amount <= 0 ||
        category == null ||
        paymentMethod == null) {
      setState(() => showValidation = true);
      return;
    }

    setState(() => saving = true);
    try {
      final api = ref.read(apiProvider);
      if (editing) {
        await api.updateTransaction(
          id: widget.transaction!.id!,
          date: date,
          amount: amount,
          category: category!,
          merchant: paymentMethod!,
        );
      } else {
        await api.createManualTransaction(
          date: date,
          amount: amount,
          category: category!,
          merchant: paymentMethod!,
        );
      }
      ref.invalidate(dashboardProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save transaction.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      12,
      12,
      12,
      MediaQuery.viewInsetsOf(context).bottom + 12,
    ),
    child: SurfaceCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    editing ? 'Edit transaction' : 'Manual transaction',
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDate: date,
                );
                if (selected != null) setState(() => date = selected);
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat.yMMMMd('id_ID').format(date)),
              style: secondaryButtonStyle(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: appInputDecoration('Amount').copyWith(
                prefixText: 'Rp ',
                errorText:
                    showValidation &&
                        (double.tryParse(
                                  amountController.text.replaceAll(',', '.'),
                                ) ??
                                0) <=
                            0
                    ? 'Enter a valid amount'
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              dropdownColor: AppColors.panel,
              decoration: appInputDecoration('Category').copyWith(
                errorText: showValidation && category == null
                    ? 'Select a category'
                    : null,
              ),
              items: manualTransactionCategories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Row(
                        children: [
                          Icon(
                            categoryIcon(item),
                            color: categoryColor(item),
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text(item),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                category = value;
                showValidation = false;
              }),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectPayment,
              borderRadius: BorderRadius.circular(15),
              child: InputDecorator(
                isEmpty: paymentMethod == null,
                decoration: appInputDecoration('').copyWith(
                  errorText: showValidation && paymentMethod == null
                      ? 'Select a payment method'
                      : null,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        paymentMethod ?? 'Choose payment method',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: paymentMethod == null
                              ? AppColors.muted
                              : AppColors.cream,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                minimumSize: const Size(0, 52),
              ),
              icon: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink,
                      ),
                    )
                  : Icon(editing ? Icons.save_outlined : Icons.add_rounded),
              label: Text(
                saving
                    ? 'Saving...'
                    : editing
                    ? 'Save changes'
                    : 'Add transaction',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String? _canonicalCategory(String? value) {
  final normalized = value?.trim().toLowerCase() ?? '';
  for (final category in manualTransactionCategories) {
    if (category.toLowerCase() == normalized) return category;
  }
  if (normalized.contains('makan')) return 'Food';
  if (normalized.contains('gojek') || normalized.contains('grab')) {
    return 'Transport';
  }
  if (normalized.contains('belanja') || normalized.contains('shop')) {
    return 'Lifestyle';
  }
  if (normalized.contains('sehat')) return 'Health';
  if (normalized.contains('donasi')) return 'Donation';
  if (normalized.contains('tagihan')) return 'Utility';
  if (normalized.contains('bayar') || normalized.contains('bank')) {
    return 'Payment';
  }
  return null;
}
