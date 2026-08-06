import 'package:flutter/material.dart';

import 'core/app_assets.dart';
import 'core/app_theme.dart';
import 'widgets/payment_method_logo.dart';

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
    initialChildSize: .88,
    minChildSize: .58,
    maxChildSize: .97,
    expand: false,
    builder: (context, scrollController) => Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x300f172a), blurRadius: 30)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 52,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xffa99cfb),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: SizedBox(
              height: 82,
              child: Stack(
                children: [
                  const Positioned.fill(
                    right: 50,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Payment Method',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Choose how this transaction was paid.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 42,
                    bottom: -4,
                    child: SizedBox(
                      width: 102,
                      height: 62,
                      child: ClipRect(
                        child: Transform.scale(
                          scale: 1.55,
                          child: Image.asset(
                            AppAssets.manualCategoryDog,
                            fit: BoxFit.cover,
                            alignment: Alignment(0, -.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 18,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceRaised,
                        minimumSize: const Size.square(46),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              key: const ValueKey('payment-search-field'),
              controller: searchController,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search banks, wallets, cards...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryAccent,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
                  borderSide: const BorderSide(
                    color: AppColors.primaryAccent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: visibleGroups.isEmpty
                ? const Center(
                    child: Text(
                      'No payment methods found.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
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

  bool get containsSelection => group.options.contains(selectedValue);

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: containsSelection ? const Color(0xfff7f5ff) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: containsSelection
            ? AppColors.primaryAccent
            : AppColors.borderSubtle,
        width: containsSelection ? 1.5 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x100f172a),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                _MethodMark(icon: group.icon, title: group.title),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (!expanded) ...[
                        const SizedBox(height: 7),
                        SizedBox(
                          height: 29,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: group.options.length.clamp(0, 6),
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
                Icon(
                  containsSelection
                      ? Icons.check_circle_rounded
                      : expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.chevron_right_rounded,
                  color: containsSelection
                      ? AppColors.primaryAccent
                      : const Color(0xff3d43a3),
                  size: containsSelection ? 28 : 24,
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
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
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
                        style: const TextStyle(fontSize: 13.5, height: 1.25),
                      ),
                    ),
                    Icon(
                      selectedValue == option
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      color: selectedValue == option
                          ? AppColors.primaryAccent
                          : AppColors.textSecondary,
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
  const _MethodMark({required this.icon, required this.title});

  final IconData icon;
  final String title;

  Color get color {
    final lower = title.toLowerCase();
    if (lower.contains('card')) return const Color(0xffd82ca4);
    if (lower.contains('qris') || lower.contains('wallet')) {
      return const Color(0xff0daf9e);
    }
    if (lower.contains('paylater')) return const Color(0xffff6545);
    if (lower.contains('instant')) return const Color(0xff09bcae);
    if (lower.contains('retail')) return const Color(0xffe99000);
    return AppColors.primaryAccent;
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: color, size: 25),
  );
}

class _OptionPreview extends StatelessWidget {
  const _OptionPreview({required this.label, this.large = false});

  final String label;
  final bool large;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: PaymentMethodLogo(paymentMethod: label, size: large ? 34 : 29),
  );
}
