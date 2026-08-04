import 'package:flutter/material.dart';

import '../core/app_theme.dart';

Color categoryColor(String name) {
  final value = name.toLowerCase();
  if (value.contains('food') || value.contains('makan')) return AppColors.coral;
  if (value.contains('transport') ||
      value.contains('gojek') ||
      value.contains('grab')) {
    return AppColors.sage;
  }
  if (value.contains('lifestyle') ||
      value.contains('shop') ||
      value.contains('belanja')) {
    return const Color(0xffb497e8);
  }
  if (value.contains('health') || value.contains('sehat')) {
    return const Color(0xff74b6ab);
  }
  if (value.contains('donation') || value.contains('donasi')) {
    return const Color(0xffdf7e97);
  }
  if (value.contains('utility') || value.contains('tagihan')) {
    return const Color(0xffd5a94f);
  }
  if (value.contains('payment') ||
      value.contains('transfer') ||
      value.contains('bank')) {
    return const Color(0xff76a5cf);
  }
  return AppColors.gold;
}

IconData categoryIcon(String name) {
  final value = name.toLowerCase();
  if (value.contains('food') || value.contains('makan')) {
    return Icons.restaurant;
  }
  if (value.contains('transport') ||
      value.contains('gojek') ||
      value.contains('grab')) {
    return Icons.two_wheeler;
  }
  if (value.contains('lifestyle') ||
      value.contains('shop') ||
      value.contains('belanja')) {
    return Icons.shopping_bag;
  }
  if (value.contains('health') || value.contains('sehat')) {
    return Icons.medical_services;
  }
  if (value.contains('donation') || value.contains('donasi')) {
    return Icons.volunteer_activism;
  }
  if (value.contains('utility') || value.contains('tagihan')) return Icons.bolt;
  if (value.contains('payment') ||
      value.contains('transfer') ||
      value.contains('bank')) {
    return Icons.payments;
  }
  return Icons.category;
}

String? paymentMethodLogoAsset(String? paymentMethod) {
  final value = paymentMethod?.toLowerCase() ?? '';
  if (value.contains('bca syariah')) {
    return 'assets/logos/bank_transfer/BCA_Syariah.png';
  }
  if (value.contains('bca')) return 'assets/logos/bank_transfer/BCA.png';
  if (value.contains('mandiri')) {
    return 'assets/logos/bank_transfer/Mandiri.png';
  }
  if (value.contains('bni')) return 'assets/logos/bank_transfer/BNI.png';
  if (value.contains('bri ceria')) {
    return 'assets/logos/cardless_credit/BRI_ceria.png';
  }
  if (value.contains('bri')) return 'assets/logos/bank_transfer/BRI.png';
  if (value.contains('danamon')) {
    return 'assets/logos/bank_transfer/Danamon.png';
  }
  if (value.contains('permata')) {
    return 'assets/logos/bank_transfer/Permata.png';
  }
  if (value.contains('bsi')) return 'assets/logos/bank_transfer/BSI.png';
  if (value.contains('akulaku')) {
    return 'assets/logos/cardless_credit/Akulaku.png';
  }
  if (value.contains('kredivo')) {
    return 'assets/logos/cardless_credit/Kredivo.png';
  }
  if (value.contains('home credit')) {
    return 'assets/logos/cardless_credit/home_credit.png';
  }
  if (value.contains('credit/debit') ||
      value.contains('visa') ||
      value.contains('mastercard')) {
    return 'assets/logos/credit_debit/cards.png';
  }
  if (value.contains('gopay')) return 'assets/logos/e-wallet/Gopay.png';
  if (value.contains('linkaja syariah')) {
    return 'assets/logos/e-wallet/LinkAjaSyariah.png';
  }
  if (value.contains('linkaja')) return 'assets/logos/e-wallet/LinkAja.png';
  if (value.contains('ovo')) return 'assets/logos/e-wallet/OVO.png';
  if (value.contains('dana')) return 'assets/logos/e-wallet/Dana.png';
  if (value.contains('sakuku')) return 'assets/logos/e-wallet/Sakuku.png';
  if (value.contains('qris')) return 'assets/logos/QRIS/QRIS.png';
  if (value.contains('jenius')) {
    return 'assets/logos/internet_banking/jenius.png';
  }
  if (value.contains('octo clicks') || value.contains('octo mobile')) {
    return 'assets/logos/internet_banking/octo_clicks.png';
  }
  if (value.contains('octo cash')) {
    return 'assets/logos/instant_debit/OCTO_cash.png';
  }
  if (value.contains('oneklik')) {
    return 'assets/logos/instant_debit/OneKlik.png';
  }
  if (value.contains('alfa') || value.contains('lawson')) {
    return 'assets/logos/over_the_counter/alfagroup.png';
  }
  if (value.contains('indomaret')) {
    return 'assets/logos/over_the_counter/indomaret.png';
  }
  return null;
}
