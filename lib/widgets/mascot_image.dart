import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class MascotImage extends StatelessWidget {
  const MascotImage({
    super.key,
    required this.asset,
    required this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = 24,
    this.alignment = Alignment.center,
  });

  final String asset;
  final double height;
  final BoxFit fit;
  final double borderRadius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Broke.AI dog mascot',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(
        color: AppColors.surfaceCard,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Image.asset(
            asset,
            fit: fit,
            alignment: alignment,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.pets_rounded,
                size: 64,
                color: AppColors.primaryAccent,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
