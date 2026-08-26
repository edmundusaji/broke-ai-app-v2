import 'package:flutter/material.dart';

import '../widgets/settings_components.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SettingsPageScaffold(
      title: 'About Broke.AI',
      subtitle: 'A calmer way to capture, organize, and understand spending.',
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(29),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: .27),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              'B.',
              style: TextStyle(
                color: colors.onPrimary,
                fontSize: 37,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Broke.AI',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Version 1.0.0 (1)',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 28),
        SettingsCard(
          child: Text(
            'Broke.AI turns receipts and everyday purchases into clear spending records, so you can understand where your money goes without tedious manual work.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Product'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.new_releases_outlined,
                color: colors.primary,
                title: 'What’s new',
                subtitle: 'See improvements in this release.',
                showDivider: true,
                onTap: () =>
                    _message(context, 'You are using the latest version.'),
              ),
              SettingsRow(
                icon: Icons.star_outline_rounded,
                color: const Color(0xffff9800),
                title: 'Rate Broke.AI',
                subtitle: 'Share feedback when store publishing is ready.',
                showDivider: true,
                onTap: () =>
                    _message(context, 'Store rating link not connected yet.'),
              ),
              SettingsRow(
                icon: Icons.code_rounded,
                color: const Color(0xff2586f5),
                title: 'Open-source licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Broke.AI',
                  applicationVersion: '1.0.0',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Center(
          child: Text(
            'Made with care for clearer money habits.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
