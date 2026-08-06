import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../providers/app_providers.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryAccent, AppColors.secondaryAccent],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x555b50f6), blurRadius: 20),
          ],
        ),
        child: const SizedBox.square(
          dimension: 66,
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
      const SizedBox(height: 11),
      const Text(
        'BROKE.AI',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.2,
        ),
      ),
    ],
  );
}

class HeroIcon extends StatelessWidget {
  const HeroIcon({super.key, required this.icon, this.size = 70});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      shape: BoxShape.circle,
      boxShadow: const [BoxShadow(color: Color(0x555b50f6), blurRadius: 16)],
    ),
    child: Icon(icon, color: AppColors.primaryAccent, size: size * .45),
  );
}

class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      IconButton.filledTonal(onPressed: onTap, icon: Icon(icon));
}

class MonthPicker extends ConsumerWidget {
  const MonthPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              DateTime(month.year, month.month - 1),
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.primaryAccent,
          ),
        ),
        Text(
          DateFormat('MMM yyyy', 'id_ID').format(month),
          style: const TextStyle(
            color: AppColors.primaryAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              DateTime(month.year, month.month + 1),
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.primaryAccent,
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140f172a),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
