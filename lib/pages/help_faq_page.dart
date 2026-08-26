import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../widgets/settings_components.dart';

enum _GuestSupportChoice { close, share, signIn }

class HelpFaqPage extends ConsumerStatefulWidget {
  const HelpFaqPage({super.key, this.openBugReport = false});

  final bool openBugReport;

  @override
  ConsumerState<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends ConsumerState<HelpFaqPage> {
  String _query = '';
  List<FaqArticle> _questions = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openBugReport) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSupportSheet(bug: true);
      });
    }
  }

  Future<void> _load() async {
    try {
      final questions = await ref
          .read(settingsRepositoryProvider)
          .faqs(locale: 'en');
      if (mounted) setState(() => _questions = questions);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Help content is temporarily unavailable.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _questions
        .where(
          (item) => '${item.title} ${item.body}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    return SettingsPageScaffold(
      title: 'Help & FAQ',
      subtitle:
          'Quick answers for accounts, scanning, transactions, and privacy.',
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: settingsInputDecoration(
            context,
            label: 'Search help',
            icon: Icons.search_rounded,
          ),
        ),
        const SizedBox(height: 22),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(_error!, textAlign: TextAlign.center),
                )
              : filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 34),
                      SizedBox(height: 10),
                      Text(
                        'No matching answers',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < filtered.length; index++)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 16),
                        shape: index < filtered.length - 1
                            ? Border(
                                bottom: BorderSide(
                                  color: colors.outlineVariant,
                                ),
                              )
                            : const Border(),
                        collapsedShape: index < filtered.length - 1
                            ? Border(
                                bottom: BorderSide(
                                  color: colors.outlineVariant,
                                ),
                              )
                            : const Border(),
                        title: Text(
                          filtered[index].title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              filtered[index].body,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        const SettingsSectionLabel('Still need help?'),
        SettingsCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              SettingsRow(
                icon: Icons.chat_bubble_outline_rounded,
                color: const Color(0xff5b50f6),
                title: 'Contact support',
                subtitle: 'Start a support request.',
                showDivider: true,
                onTap: () => _showSupportSheet(bug: false),
              ),
              SettingsRow(
                icon: Icons.bug_report_outlined,
                color: const Color(0xffff5252),
                title: 'Report a bug',
                subtitle: 'Tell us what happened and how to reproduce it.',
                onTap: () => _showSupportSheet(bug: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showSupportSheet({
    required bool bug,
    String initialSubject = '',
    String initialMessage = '',
  }) async {
    final request =
        await showModalBottomSheet<({String subject, String message})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _SupportRequestSheet(
            bug: bug,
            initialSubject: initialSubject,
            initialMessage: initialMessage,
          ),
        );
    if (request == null || !mounted) return;
    if (ref.read(sessionProvider).value?.isGuest ?? true) {
      await _handleGuestSupportDraft(
        bug: bug,
        subject: request.subject,
        message: request.message,
      );
      return;
    }
    try {
      final ticket = await ref
          .read(apiProvider)
          .createSupportTicket(
            bug: bug,
            subject: request.subject,
            message: request.message,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Request submitted. Ticket ${ticket.id.substring(0, 8)} is ${ticket.status}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final editAgain = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.cloud_off_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Report not submitted'),
          content: Text(
            '${apiErrorMessage(error)}\n\nYour draft can be reopened so you do not have to type it again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Edit draft'),
            ),
          ],
        ),
      );
      if (editAgain == true && mounted) {
        await _showSupportSheet(
          bug: bug,
          initialSubject: request.subject,
          initialMessage: request.message,
        );
      }
    }
  }

  Future<void> _handleGuestSupportDraft({
    required bool bug,
    required String subject,
    required String message,
  }) async {
    final choice = await showDialog<_GuestSupportChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.login_rounded),
        title: const Text('Sign in to submit'),
        content: const Text(
          'The connected server accepts support requests from registered accounts only. You can sign in, or share this draft through email or another app.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _GuestSupportChoice.close),
            child: const Text('Keep draft'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _GuestSupportChoice.share),
            child: const Text('Share draft'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _GuestSupportChoice.signIn),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == _GuestSupportChoice.share) {
      await SharePlus.instance.share(
        ShareParams(
          title: bug ? 'Broke.AI bug report' : 'Broke.AI support request',
          subject: subject,
          text: '$subject\n\n$message',
        ),
      );
    } else if (choice == _GuestSupportChoice.signIn) {
      ref.read(authStartInLoginProvider.notifier).state = true;
      ref.read(showAuthProvider.notifier).state = true;
    } else if (choice == _GuestSupportChoice.close && mounted) {
      final reopen = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Draft kept for now'),
          content: const Text(
            'This draft is kept while this page remains open. Reopen it now if you want to make changes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Done'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Edit draft'),
            ),
          ],
        ),
      );
      if (reopen == true && mounted) {
        await _showSupportSheet(
          bug: bug,
          initialSubject: subject,
          initialMessage: message,
        );
      }
    }
  }
}

class _SupportRequestSheet extends StatefulWidget {
  const _SupportRequestSheet({
    required this.bug,
    required this.initialSubject,
    required this.initialMessage,
  });

  final bool bug;
  final String initialSubject;
  final String initialMessage;

  @override
  State<_SupportRequestSheet> createState() => _SupportRequestSheetState();
}

class _SupportRequestSheetState extends State<_SupportRequestSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.initialSubject);
    _message = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _submit() {
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Add a subject and a detailed message.');
      return;
    }
    Navigator.pop(context, (subject: subject, message: message));
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      4,
      24,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.bug ? 'Report a bug' : 'Contact support',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          widget.bug
              ? 'Describe what you expected and what happened.'
              : 'Tell us what you need help with.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _subject,
          maxLength: 160,
          decoration: settingsInputDecoration(context, label: 'Subject'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _message,
          minLines: 4,
          maxLines: 6,
          maxLength: 10000,
          decoration: settingsInputDecoration(
            context,
            label: widget.bug ? 'Bug details' : 'Your message',
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        SettingsPrimaryButton(
          label: widget.bug ? 'Submit bug report' : 'Submit request',
          icon: Icons.send_outlined,
          onPressed: _submit,
        ),
      ],
    ),
  );
}
