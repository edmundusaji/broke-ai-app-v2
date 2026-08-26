import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../models/transaction.dart';
import '../payment_method_picker.dart';
import '../providers/app_providers.dart';
import '../utils/transaction_visuals.dart';
import 'payment_method_logo.dart';

const manualTransactionCategories = <String>[
  'Food',
  'Transport',
  'Lifestyle',
  'Health',
  'Donation',
  'Utility',
  'Payment',
];

const _categoryDescriptions = <String, String>{
  'Food': 'Meals, snacks, restaurants',
  'Transport': 'Ride, fuel, public transport',
  'Lifestyle': 'Shopping, hobbies, entertainment',
  'Health': 'Medical, pharmacy, wellness',
  'Donation': 'Charity, social contribution',
  'Utility': 'Electricity, water, internet',
  'Payment': 'Subscriptions, loans, others',
};

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
  late final TextEditingController descriptionController;
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
      text: transaction?.amount?.toStringAsFixed(0) ?? '0',
    );
    descriptionController = TextEditingController(
      text: transaction?.description ?? '',
    );
    category = _canonicalCategory(transaction?.category);
    paymentMethod = transaction?.paymentMethod?.trim().isNotEmpty == true
        ? transaction!.paymentMethod!.trim()
        : null;
    date = DateTime.tryParse(transaction?.date ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectCategory() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPicker(selectedValue: category),
    );
    if (selected != null && mounted) {
      setState(() {
        category = selected;
        showValidation = false;
      });
    }
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

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: date,
    );
    if (selected != null && mounted) setState(() => date = selected);
  }

  Future<void> _submit() async {
    final amount = double.tryParse(
      amountController.text.replaceAll('.', '').replaceAll(',', '.'),
    );
    final description = descriptionController.text.trim();
    if (amount == null ||
        amount <= 0 ||
        category == null ||
        paymentMethod == null) {
      setState(() => showValidation = true);
      return;
    }

    setState(() => saving = true);
    try {
      final session = await ref.read(sessionProvider.future);
      if (session == null) throw StateError('No local account is active.');
      final repository = await ref.read(transactionRepositoryProvider.future);
      if (editing) {
        await repository.updateTransaction(
          accountScope: session.accountScope,
          current: widget.transaction!,
          date: date,
          amount: amount,
          category: category!,
          paymentMethod: paymentMethod!,
          description: description.isEmpty ? 'Manual transaction' : description,
        );
      } else {
        await repository.createManualTransaction(
          accountScope: session.accountScope,
          date: date,
          amount: amount,
          category: category!,
          paymentMethod: paymentMethod!,
          description: description.isEmpty ? 'Manual transaction' : description,
        );
      }
      ref.invalidate(dashboardProvider);
      ref.invalidate(localTransactionSyncStatusProvider);
      unawaited(synchronizeTransactions(ref));
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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: const [BoxShadow(color: Color(0x300f172a), blurRadius: 30)],
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 10, 24, bottomInset + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xffc4b5fd),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing ? 'Edit Transaction' : 'Add Transaction',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (!editing)
                        const Text(
                          'Manual transaction',
                          style: TextStyle(
                            color: Colors.transparent,
                            fontSize: .1,
                            height: .1,
                          ),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        editing
                            ? 'Update your expense details'
                            : 'Record your expense in seconds',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                _CloseButton(onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 22),
            _PickerField(
              key: const ValueKey('manual-date-field'),
              icon: Icons.calendar_month_rounded,
              value: DateFormat('d MMMM yyyy', 'en_US').format(date),
              onTap: _selectDate,
              trailing: Icons.arrow_drop_down_rounded,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Amount'),
            const SizedBox(height: 7),
            TextField(
              key: const ValueKey('manual-amount-field'),
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              decoration: _fieldDecoration(
                context,
                hintText: '0',
                prefixText: 'Rp ',
                errorText:
                    showValidation &&
                        (double.tryParse(
                                  amountController.text
                                      .replaceAll('.', '')
                                      .replaceAll(',', '.'),
                                ) ??
                                0) <=
                            0
                    ? 'Enter a valid amount'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Category'),
            const SizedBox(height: 7),
            _PickerField(
              key: const ValueKey('manual-category-field'),
              icon: category == null
                  ? Icons.shopping_bag_outlined
                  : categoryIcon(category!),
              iconColor: category == null
                  ? AppColors.primaryAccent
                  : categoryColor(category!),
              value: category ?? 'Choose a category',
              muted: category == null,
              onTap: _selectCategory,
              errorText: showValidation && category == null
                  ? 'Select a category'
                  : null,
              trailing: Icons.keyboard_arrow_down_rounded,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Description (Optional)'),
            const SizedBox(height: 7),
            TextField(
              key: const ValueKey('manual-description-field'),
              controller: descriptionController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 1,
              decoration: _fieldDecoration(
                context,
                hintText: 'Add a note about this transaction',
                prefixIcon: const SizedBox(
                  width: 66,
                  child: Center(child: _InputIcon(icon: Icons.notes_rounded)),
                ),
                errorText:
                    showValidation && descriptionController.text.trim().isEmpty
                    ? 'Enter a description'
                    : null,
              ),
              onChanged: (_) {
                if (showValidation) setState(() => showValidation = false);
              },
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Payment Method'),
            const SizedBox(height: 7),
            _PickerField(
              key: const ValueKey('manual-payment-field'),
              icon: Icons.credit_card_rounded,
              value: paymentMethod ?? 'Choose payment method',
              muted: paymentMethod == null,
              logo: paymentMethod == null
                  ? null
                  : PaymentMethodLogo(paymentMethod: paymentMethod, size: 40),
              onTap: _selectPayment,
              errorText: showValidation && paymentMethod == null
                  ? 'Select a payment method'
                  : null,
              trailing: Icons.chevron_right_rounded,
            ),
            const SizedBox(height: 20),
            Container(
              height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xffeee7ff),
                    Color(0xfff3eeff),
                    Color(0xfff8f5ff),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  SizedBox(
                    width: 122,
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0, .78, 1],
                      ).createShader(bounds),
                      child: Image.asset(
                        AppAssets.manualDog,
                        height: 92,
                        fit: BoxFit.cover,
                        alignment: const Alignment(-.1, -.05),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 12, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep your spending organized',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Add details now to get better insights and summaries.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
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
              child: FilledButton.icon(
                onPressed: saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(0, 56),
                ),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(editing ? Icons.save_outlined : Icons.add_rounded),
                label: Text(
                  saving
                      ? 'Saving...'
                      : editing
                      ? 'Save Changes'
                      : 'Add Transaction',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({this.selectedValue});

  final String? selectedValue;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: .78,
    minChildSize: .55,
    maxChildSize: .94,
    expand: false,
    builder: (context, controller) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: const [BoxShadow(color: Color(0x300f172a), blurRadius: 28)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xffc4b5fd),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Category',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pick a category that fits your transaction',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 122,
                  height: 90,
                  child: ClipRect(
                    child: Transform.scale(
                      scale: 1.55,
                      child: Image.asset(
                        AppAssets.manualCategoryDog,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -.2),
                      ),
                    ),
                  ),
                ),
                _CloseButton(onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: manualTransactionCategories.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                if (index == manualTransactionCategories.length) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'More categories coming soon!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  );
                }
                final value = manualTransactionCategories[index];
                final selected = value == selectedValue;
                return InkWell(
                  onTap: () => Navigator.pop(context, value),
                  borderRadius: BorderRadius.circular(19),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: .1)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(19),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryAccent
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: selected ? 1.5 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x100f172a),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: categoryColor(value).withValues(alpha: .17),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            categoryIcon(value),
                            color: categoryColor(value),
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _categoryDescriptions[value] ?? '',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                          color: selected
                              ? AppColors.primaryAccent
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          size: selected ? 28 : 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      fontSize: 14,
    ),
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    super.key,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.trailing,
    this.iconColor = AppColors.primaryAccent,
    this.muted = false,
    this.errorText,
    this.logo,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final VoidCallback onTap;
  final IconData trailing;
  final bool muted;
  final String? errorText;
  final Widget? logo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText == null
                  ? Theme.of(context).colorScheme.outlineVariant
                  : AppColors.danger,
            ),
          ),
          child: Row(
            children: [
              logo ?? _InputIcon(icon: icon, color: iconColor),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              Icon(trailing, color: const Color(0xff636b8d)),
            ],
          ),
        ),
      ),
      if (errorText != null) ...[
        const SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            errorText!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    ],
  );
}

class _InputIcon extends StatelessWidget {
  const _InputIcon({required this.icon, this.color = AppColors.primaryAccent});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Close',
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      minimumSize: const Size.square(48),
    ),
    icon: Icon(
      Icons.close_rounded,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

InputDecoration _fieldDecoration(
  BuildContext context, {
  String? hintText,
  String? prefixText,
  Widget? prefixIcon,
  String? errorText,
}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    prefixIcon: prefixIcon,
    prefixIconConstraints: prefixIcon == null
        ? null
        : const BoxConstraints(minWidth: 66),
    errorText: errorText,
    hintStyle: TextStyle(color: colors.onSurfaceVariant),
    filled: true,
    fillColor: colors.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: colors.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
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
