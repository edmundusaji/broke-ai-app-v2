import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

Future<void> showAppearanceSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _AppearanceSheet(),
    );

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 2, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dark ? 'Dark mode is active' : 'Light mode is active',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Switch(
                value: dark,
                onChanged: (value) => _setTheme(
                  context,
                  ref,
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _ThemePreview(
                  label: 'Light',
                  selected: !dark,
                  dark: false,
                  onTap: () => _setTheme(context, ref, ThemeMode.light),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ThemePreview(
                  label: 'Dark',
                  selected: dark,
                  dark: true,
                  onTap: () => _setTheme(context, ref, ThemeMode.dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: colors.primary),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Your choice updates every screen in Broke.AI immediately.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setTheme(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
  ) async {
    ref.read(themeModeProvider.notifier).state = mode;
    try {
      final preferences = await ref.read(accountPreferencesProvider.future);
      await ref
          .read(settingsRepositoryProvider)
          .updateAccountPreferences(
            current: preferences,
            themeMode: mode == ThemeMode.dark ? 'dark' : 'light',
          );
      ref.invalidate(accountPreferencesProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Theme changed, but could not be saved on this device.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({
    required this.label,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final background = dark ? const Color(0xff0b1020) : const Color(0xfff8fafc);
    final surface = dark ? const Color(0xff172135) : Colors.white;
    final text = dark ? const Color(0xfff8fafc) : const Color(0xff0f172a);
    final muted = dark ? const Color(0xff9eacc2) : const Color(0xff64748b);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? accent
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 7,
                    decoration: BoxDecoration(
                      color: text,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, color: accent, size: 20),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                height: 52,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: text,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 5),
                          FractionallySizedBox(
                            widthFactor: .7,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: muted,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 11),
              Text(
                label,
                style: TextStyle(color: text, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
