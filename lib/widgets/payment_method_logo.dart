import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../utils/transaction_visuals.dart';

class PaymentMethodLogo extends StatelessWidget {
  const PaymentMethodLogo({
    super.key,
    required this.paymentMethod,
    this.size = 44,
  });

  final String? paymentMethod;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = paymentMethodLogoAsset(paymentMethod);
    final fallback = Icon(
      Icons.account_balance_wallet_rounded,
      color: AppColors.primaryAccent,
      size: size * .48,
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(asset == null ? 0 : size * .12),
      decoration: BoxDecoration(
        color: asset == null ? const Color(0x145b50f6) : Colors.white,
        border: Border.all(color: AppColors.borderSubtle),
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
