import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../utils/transaction_visuals.dart';

class MerchantLogo extends StatelessWidget {
  const MerchantLogo({
    super.key,
    required this.merchant,
    required this.category,
    this.size = 44,
  });

  final String? merchant;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = merchantLogoAsset(merchant);
    final fallback = Icon(
      categoryIcon(category),
      color: AppColors.ink,
      size: size * .48,
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(asset == null ? 0 : size * .12),
      decoration: BoxDecoration(
        color: asset == null ? categoryColor(category) : Colors.white,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      alignment: Alignment.center,
      child: asset == null
          ? fallback
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}
