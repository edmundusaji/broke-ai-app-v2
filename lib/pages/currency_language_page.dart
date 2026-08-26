import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../widgets/settings_components.dart';

class CurrencyLanguagePage extends ConsumerStatefulWidget {
  const CurrencyLanguagePage({super.key});

  @override
  ConsumerState<CurrencyLanguagePage> createState() =>
      _CurrencyLanguagePageState();
}

class _CurrencyLanguagePageState extends ConsumerState<CurrencyLanguagePage> {
  static const _currencies = [
    _Choice('IDR', 'Indonesian Rupiah', 'Rp'),
    _Choice('USD', 'US Dollar', r'$'),
    _Choice('SGD', 'Singapore Dollar', r'S$'),
    _Choice('MYR', 'Malaysian Ringgit', 'RM'),
    _Choice('EUR', 'Euro', '€'),
    _Choice('JPY', 'Japanese Yen', '¥'),
    _Choice('AUD', 'Australian Dollar', r'A$'),
  ];
  static const _languages = [
    _Choice('en', 'English', 'EN'),
    _Choice('id', 'Bahasa Indonesia', 'ID'),
    _Choice('ms', 'Bahasa Melayu', 'MS'),
    _Choice('zh-Hans', 'Chinese — Simplified', 'ZH'),
    _Choice('ja', 'Japanese', 'JA'),
  ];
  static const _regions = [
    _Choice('ID', 'Indonesia', 'ID'),
    _Choice('SG', 'Singapore', 'SG'),
    _Choice('MY', 'Malaysia', 'MY'),
    _Choice('US', 'United States', 'US'),
    _Choice('AU', 'Australia', 'AU'),
    _Choice('JP', 'Japan', 'JP'),
  ];

  AccountPreferences? _preferences;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref
          .read(settingsRepositoryProvider)
          .accountPreferences();
      if (!mounted) return;
      setState(() => _preferences = value);
      _publish(value);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _publish(AccountPreferences value) {
    final language = _find(_languages, value.languageCode).label;
    final region = _find(_regions, value.regionCode).label;
    ref.read(localePreferencesProvider.notifier).state = LocalePreferences(
      currencyCode: value.currencyCode,
      language: language,
      region: region,
    );
  }

  Future<void> _update({
    String? currencyCode,
    String? languageCode,
    String? regionCode,
  }) async {
    final current = _preferences;
    if (current == null) return;
    setState(() => _saving = true);
    try {
      final value = await ref
          .read(settingsRepositoryProvider)
          .updateAccountPreferences(
            current: current,
            currencyCode: currencyCode,
            languageCode: languageCode,
            regionCode: regionCode,
            timeZone: regionCode == null ? null : _timeZone(regionCode),
          );
      if (!mounted) return;
      setState(() => _preferences = value);
      _publish(value);
      ref.invalidate(accountPreferencesProvider);
      _message('Preference saved.');
    } catch (_) {
      if (mounted) {
        _message('Could not save this preference on the device.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _choose({
    required String title,
    required String hint,
    required String selected,
    required List<_Choice> choices,
    required Future<void> Function(String) save,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ChoiceSheet(
        title: title,
        searchHint: hint,
        selectedValue: selected,
        choices: choices,
      ),
    );
    if (value != null) await save(value);
  }

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGuest = ref.watch(sessionProvider).value?.isGuest ?? true;
    if (_loading) {
      return const SettingsPageScaffold(
        title: 'Currency & language',
        subtitle: 'Choose how amounts, dates, and app content are displayed.',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }
    final preferences = _preferences;
    if (preferences == null) return const SizedBox.shrink();
    final currency = _find(_currencies, preferences.currencyCode);
    final language = _find(_languages, preferences.languageCode);
    final region = _find(_regions, preferences.regionCode);
    return SettingsPageScaffold(
      title: 'Currency & language',
      subtitle: 'Choose how amounts, dates, and app content are displayed.',
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xff16a34a).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xff16a34a).withValues(alpha: .22),
            ),
          ),
          child: Row(
            children: [
              const SettingsIcon(
                icon: Icons.account_balance_wallet_outlined,
                color: Color(0xff16a34a),
                size: 52,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currency.symbol} 1,250,000',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Preview in ${preferences.currencyCode}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (_saving) const CircularProgressIndicator(),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SettingsSectionLabel('Money'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: SettingsRow(
            icon: Icons.payments_outlined,
            color: const Color(0xff16a34a),
            title: 'Primary currency',
            subtitle: '${currency.label} (${currency.value})',
            onTap: _saving
                ? null
                : () => _choose(
                    title: 'Choose currency',
                    hint: 'Search currency or code',
                    selected: preferences.currencyCode,
                    choices: _currencies,
                    save: (value) => _update(currencyCode: value),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Language & region'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.translate_rounded,
                color: colors.primary,
                title: 'App language',
                subtitle: language.label,
                showDivider: true,
                onTap: _saving
                    ? null
                    : () => _choose(
                        title: 'App language',
                        hint: 'Search language',
                        selected: preferences.languageCode,
                        choices: _languages,
                        save: (value) => _update(languageCode: value),
                      ),
              ),
              SettingsRow(
                icon: Icons.public_rounded,
                color: const Color(0xff2586f5),
                title: 'Region',
                subtitle: region.label,
                onTap: _saving
                    ? null
                    : () => _choose(
                        title: 'Your region',
                        hint: 'Search country or region',
                        selected: preferences.regionCode,
                        choices: _regions,
                        save: (value) => _update(regionCode: value),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SettingsInfoBanner(
          icon: Icons.save_outlined,
          title: 'Saved automatically',
          body: isGuest
              ? 'Preferences are saved for this guest profile on this device. Create an account to carry them to another device.'
              : 'Preferences work offline and sync to your account whenever the server is available.',
          color: const Color(0xff16a34a),
        ),
      ],
    );
  }

  _Choice _find(List<_Choice> choices, String value) => choices.firstWhere(
    (item) => item.value == value,
    orElse: () => _Choice(value, value, value),
  );

  String _timeZone(String regionCode) => switch (regionCode) {
    'SG' => 'Asia/Singapore',
    'MY' => 'Asia/Kuala_Lumpur',
    'US' => 'America/New_York',
    'AU' => 'Australia/Sydney',
    'JP' => 'Asia/Tokyo',
    _ => 'Asia/Jakarta',
  };
}

class _Choice {
  const _Choice(this.value, this.label, this.symbol);

  final String value;
  final String label;
  final String symbol;
}

class _ChoiceSheet extends StatefulWidget {
  const _ChoiceSheet({
    required this.title,
    required this.searchHint,
    required this.selectedValue,
    required this.choices,
  });

  final String title;
  final String searchHint;
  final String selectedValue;
  final List<_Choice> choices;

  @override
  State<_ChoiceSheet> createState() => _ChoiceSheetState();
}

class _ChoiceSheetState extends State<_ChoiceSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = widget.choices
        .where(
          (item) => '${item.value} ${item.label} ${item.symbol}'
              .toLowerCase()
              .contains(_query.toLowerCase()),
        )
        .toList();
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .78,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: settingsInputDecoration(
                  context,
                  label: widget.searchHint,
                  icon: Icons.search_rounded,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: colors.outlineVariant),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final selected = item.value == widget.selectedValue;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      minTileHeight: 62,
                      leading: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          item.symbol,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(item.value),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, item.value),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
