import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'widgets/payment_method_logo.dart';

const _ink = AppColors.primaryBackground;
const _panel = AppColors.surfaceCard;
const _cream = AppColors.textPrimary;
const _gold = AppColors.primaryAccent;
const _muted = AppColors.textSecondary;

class PaymentMethodGroup {
  const PaymentMethodGroup({
    required this.title,
    required this.icon,
    required this.options,
  });

  final String title;
  final IconData icon;
  final List<String> options;
}

const paymentMethodGroups = <PaymentMethodGroup>[
  PaymentMethodGroup(
    title: 'Bank Transfer',
    icon: Icons.account_balance_rounded,
    options: [
      'Bank BCA',
      'Bank Mandiri',
      'Bank BNI',
      'Bank BRI / Other Banks',
      'Bank Danamon',
      'Bank Permata',
      'Bank BSI',
      'Bank BCA Syariah',
    ],
  ),
  PaymentMethodGroup(
    title: 'Credit / Debit Card',
    icon: Icons.credit_card_rounded,
    options: ['Credit/Debit Card (Visa, Mastercard, JCB, Amex)'],
  ),
  PaymentMethodGroup(
    title: 'QRIS',
    icon: Icons.qr_code_2_rounded,
    options: ['QRIS (Scan all e-wallets / mobile banking)'],
  ),
  PaymentMethodGroup(
    title: 'E-Wallet (Uang Elektronik)',
    icon: Icons.account_balance_wallet_rounded,
    options: ['GoPay', 'OVO', 'DANA', 'LinkAja', 'Sakuku', 'LinkAja Syariah'],
  ),
  PaymentMethodGroup(
    title: 'Paylater / Cardless Credit',
    icon: Icons.schedule_rounded,
    options: ['Akulaku Paylater', 'Kredivo', 'Home Credit', 'BRI Ceria'],
  ),
  PaymentMethodGroup(
    title: 'Internet Banking',
    icon: Icons.language_rounded,
    options: ['Jenius Pay', 'OCTO Clicks / OCTO Mobile'],
  ),
  PaymentMethodGroup(
    title: 'Instant Debit',
    icon: Icons.bolt_rounded,
    options: ['OneKlik', 'OCTO Cash by CIMB Niaga'],
  ),
  PaymentMethodGroup(
    title: 'Over-the-Counter / Retail Outlets',
    icon: Icons.storefront_rounded,
    options: ['Alfa Group (Alfamart, Alfamidi, Lawson)', 'Indomaret'],
  ),
  PaymentMethodGroup(
    title: 'Cash on Delivery (COD)',
    icon: Icons.payments_rounded,
    options: ['Cash / Pay on Delivery'],
  ),
];

Future<String?> showPaymentMethodPicker(
  BuildContext context, {
  String? selectedValue,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => PaymentMethodPicker(selectedValue: selectedValue),
);

class PaymentMethodPicker extends StatefulWidget {
  const PaymentMethodPicker({super.key, this.selectedValue});

  final String? selectedValue;

  @override
  State<PaymentMethodPicker> createState() => _PaymentMethodPickerState();
}

class _PaymentMethodPickerState extends State<PaymentMethodPicker> {
  final searchController = TextEditingController();
  final expandedGroups = <String>{};
  String query = '';

  @override
  void initState() {
    super.initState();
    for (final group in paymentMethodGroups) {
      if (group.options.contains(widget.selectedValue)) {
        expandedGroups.add(group.title);
        break;
      }
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<PaymentMethodGroup> get visibleGroups {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return paymentMethodGroups;
    return paymentMethodGroups
        .map((group) {
          final groupMatches = group.title.toLowerCase().contains(
            normalizedQuery,
          );
          final options = groupMatches
              ? group.options
              : group.options
                    .where(
                      (option) =>
                          option.toLowerCase().contains(normalizedQuery),
                    )
                    .toList();
          return PaymentMethodGroup(
            title: group.title,
            icon: group.icon,
            options: options,
          );
        })
        .where((group) => group.options.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.86,
    minChildSize: 0.55,
    maxChildSize: 0.96,
    expand: false,
    builder: (context, scrollController) => Container(
      decoration: const BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select payment method',
                        style: TextStyle(
                          color: _cream,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Choose how this transaction was paid.',
                        style: TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _cream),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: searchController,
              autofocus: false,
              onChanged: (value) => setState(() => query = value),
              style: const TextStyle(color: _cream),
              decoration: InputDecoration(
                hintText: 'Search banks, wallets, cards...',
                hintStyle: const TextStyle(color: _muted),
                prefixIcon: const Icon(Icons.search_rounded, color: _gold),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded, color: _muted),
                      ),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _gold, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleGroups.isEmpty
                ? const Center(
                    child: Text(
                      'No payment methods found.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: visibleGroups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (_, index) {
                      final group = visibleGroups[index];
                      final searching = query.trim().isNotEmpty;
                      final expanded =
                          searching || expandedGroups.contains(group.title);
                      return _PaymentGroupTile(
                        group: group,
                        expanded: expanded,
                        selectedValue: widget.selectedValue,
                        onToggle: searching
                            ? null
                            : () => setState(() {
                                if (expanded) {
                                  expandedGroups.remove(group.title);
                                } else {
                                  expandedGroups.add(group.title);
                                }
                              }),
                        onSelected: (value) => Navigator.pop(context, value),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}

class _PaymentGroupTile extends StatelessWidget {
  const _PaymentGroupTile({
    required this.group,
    required this.expanded,
    required this.selectedValue,
    required this.onToggle,
    required this.onSelected,
  });

  final PaymentMethodGroup group;
  final bool expanded;
  final String? selectedValue;
  final VoidCallback? onToggle;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: expanded ? AppColors.primaryAccent : AppColors.borderSubtle,
      ),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _MethodMark(icon: group.icon, label: group.title),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        style: const TextStyle(
                          color: _cream,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!expanded) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 28,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: group.options.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (_, index) =>
                                _OptionPreview(label: group.options[index]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _gold,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ...group.options.map(
            (option) => InkWell(
              onTap: () => onSelected(option),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: Row(
                  children: [
                    _OptionPreview(label: option, large: true),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(color: _cream, height: 1.25),
                      ),
                    ),
                    Icon(
                      selectedValue == option
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: selectedValue == option ? _gold : _muted,
                      size: 21,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _MethodMark extends StatelessWidget {
  const _MethodMark({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x145b50f6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: _gold, size: 22),
    ),
  );
}

class _OptionPreview extends StatelessWidget {
  const _OptionPreview({required this.label, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: PaymentMethodLogo(paymentMethod: label, size: large ? 32 : 28),
  );
}
