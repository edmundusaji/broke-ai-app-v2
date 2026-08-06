import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';

class AppBootPage extends StatelessWidget {
  const AppBootPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primaryBackground,
    body: Center(
      child: Semantics(
        label: 'Broke.AI is starting',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: Image.asset(
                AppAssets.appIcon,
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 132,
                  height: 132,
                  child: Icon(
                    Icons.pets_rounded,
                    size: 72,
                    color: AppColors.primaryAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'BROKE.AI',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primaryAccent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
