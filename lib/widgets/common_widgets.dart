import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../providers/app_providers.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      CircleAvatar(
        radius: 34,
        backgroundColor: AppColors.gold,
        child: Icon(
          Icons.account_balance_wallet,
          color: AppColors.ink,
          size: 32,
        ),
      ),
      SizedBox(height: 10),
      Text(
        'BROKE.AI',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
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
      color: AppColors.gold,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(color: AppColors.goldDark, offset: Offset(0, 7)),
      ],
    ),
    child: Icon(icon, color: AppColors.ink, size: size * .45),
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
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.gold),
        ),
        Text(
          DateFormat('MMM yyyy', 'id_ID').format(month),
          style: const TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              DateTime(month.year, month.month + 1),
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
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
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xff302e29)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(label, style: const TextStyle(color: AppColors.muted)),
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
