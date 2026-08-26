import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/account_settings.dart';
import '../providers/app_providers.dart';
import '../services/api_client.dart';
import '../widgets/settings_components.dart';

class ManageProfilePage extends ConsumerStatefulWidget {
  const ManageProfilePage({super.key});

  @override
  ConsumerState<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends ConsumerState<ManageProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  AccountProfile? _profile;
  Uint8List? _avatar;
  bool _loading = true;
  bool _saving = false;
  bool _avatarBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await ref.read(apiProvider).getProfile();
      if (!mounted) return;
      _applyProfile(profile);
      if (profile.avatarUrl != null) {
        try {
          final bytes = await ref.read(apiProvider).avatarContent();
          if (mounted) setState(() => _avatar = bytes);
        } catch (_) {
          // A missing/stale avatar should not block editing account details.
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(AccountProfile profile) {
    setState(() {
      _profile = profile;
      _nameController.text = profile.fullName;
      _usernameController.text = profile.username;
      _emailController.text = profile.email;
      _phoneController.text = profile.phone ?? '';
      _error = null;
    });
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final username = _usernameController.text.trim();
      if (username.toLowerCase() != profile.username.toLowerCase() &&
          !await ref.read(apiProvider).usernameAvailable(username)) {
        throw StateError('That username is unavailable.');
      }
      final updated = await ref
          .read(apiProvider)
          .updateProfile(
            revision: profile.revision,
            fullName: _nameController.text.trim(),
            username: username,
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
          );
      await _storeIdentity(updated);
      if (!mounted) return;
      _applyProfile(updated);
      _message('Profile saved and synced.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _storeIdentity(AccountProfile profile) async {
    await ref
        .read(sessionStoreProvider)
        .updateAccountIdentity(
          fullName: profile.fullName,
          username: profile.username,
          email: profile.email,
        );
    ref.invalidate(sessionProvider);
    ref.invalidate(syncStatusProvider);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1200,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (await file.length() > 5 * 1024 * 1024) {
      _message('Choose an image smaller than 5 MB.', error: true);
      return;
    }
    setState(() => _avatarBusy = true);
    try {
      final profile = await ref.read(apiProvider).uploadAvatar(file);
      final bytes = await ref.read(apiProvider).avatarContent();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _avatar = bytes;
      });
      _message('Profile photo updated.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _removeAvatar() async {
    Navigator.pop(context);
    setState(() => _avatarBusy = true);
    try {
      final profile = await ref.read(apiProvider).deleteAvatar();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _avatar = null;
      });
      _message('Profile photo removed.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile photo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SettingsRow(
                icon: Icons.photo_camera_outlined,
                color: Theme.of(context).colorScheme.primary,
                title: 'Take a photo',
                onTap: () => _pickAvatar(ImageSource.camera),
                showDivider: true,
              ),
              SettingsRow(
                icon: Icons.photo_library_outlined,
                color: const Color(0xff2586f5),
                title: 'Choose from gallery',
                onTap: () => _pickAvatar(ImageSource.gallery),
                showDivider: _avatar != null,
              ),
              if (_avatar != null)
                SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                  title: 'Remove photo',
                  onTap: _removeAvatar,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeEmail() async {
    final result =
        await showModalBottomSheet<({String email, String password})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) =>
              _EmailChangeSheet(currentEmail: _emailController.text),
        );
    if (result == null || !mounted) return;
    try {
      await ref
          .read(apiProvider)
          .requestEmailChange(
            newEmail: result.email,
            currentPassword: result.password,
          );
      if (!mounted) return;
      final token = await _verificationToken();
      if (token == null || !mounted) return;
      final profile = await ref.read(apiProvider).verifyEmailChange(token);
      await _storeIdentity(profile);
      if (!mounted) return;
      _applyProfile(profile);
      _message('Email address verified and updated.');
    } catch (error) {
      if (mounted) _message(apiErrorMessage(error), error: true);
    }
  }

  Future<String?> _verificationToken() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify new email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Verification token',
            hintText: 'Paste the token from your email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = _nameController.text.trim();
    final initials = name.isEmpty
        ? 'BA'
        : name
              .split(RegExp(r'\s+'))
              .take(2)
              .map((part) => part.characters.first)
              .join()
              .toUpperCase();

    return SettingsPageScaffold(
      title: 'Manage profile',
      subtitle: 'Keep your personal details accurate and recognizable.',
      bottomAction: _profile == null
          ? null
          : SettingsPrimaryButton(
              label: 'Save changes',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 72),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SettingsInfoBanner(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your profile',
            body: _error!,
            color: colors.error,
          )
        else ...[
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 102,
                  height: 102,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xffffc342), Color(0xffffad1f)],
                    ),
                    image: _avatar == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(_avatar!),
                            fit: BoxFit.cover,
                          ),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.surface, width: 6),
                  ),
                  child: _avatar == null
                      ? Text(
                          initials,
                          style: const TextStyle(
                            color: Color(0xff071653),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -2,
                  child: _avatarBusy
                      ? const CircularProgressIndicator()
                      : IconButton.filled(
                          tooltip: 'Change profile photo',
                          onPressed: _showPhotoOptions,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 20,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const SettingsSectionLabel('Profile details'),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: settingsInputDecoration(
                    context,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your full name.'
                      : null,
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _usernameController,
                  autocorrect: false,
                  decoration: settingsInputDecoration(
                    context,
                    label: 'Username',
                    icon: Icons.alternate_email_rounded,
                  ),
                  validator: (value) => value == null || value.trim().length < 3
                      ? 'Username must contain at least 3 characters.'
                      : value.trim().length > 30
                      ? 'Username must not exceed 30 characters.'
                      : null,
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  onTap: _changeEmail,
                  decoration: settingsInputDecoration(
                    context,
                    label: 'Email address',
                    icon: Icons.mail_outline_rounded,
                  ).copyWith(suffixIcon: const Icon(Icons.edit_outlined)),
                ),
                if (_profile?.pendingEmail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Verification pending for ${_profile!.pendingEmail}',
                    style: TextStyle(color: colors.primary, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 13),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: settingsInputDecoration(
                    context,
                    label: 'Phone number (optional)',
                    hint: '+6281234567890',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    return phone.isEmpty ||
                            RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)
                        ? null
                        : 'Use international format, for example +6281234567890.';
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SettingsInfoBanner(
            icon: Icons.cloud_done_outlined,
            title: 'Synced to your account',
            body:
                'Profile changes are securely saved and available on your signed-in devices.',
            color: Color(0xff16a34a),
          ),
        ],
      ],
    );
  }
}

class _EmailChangeSheet extends StatefulWidget {
  const _EmailChangeSheet({required this.currentEmail});

  final String currentEmail;

  @override
  State<_EmailChangeSheet> createState() => _EmailChangeSheetState();
}

class _EmailChangeSheetState extends State<_EmailChangeSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
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
          'Change email address',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Current email: ${widget.currentEmail}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: settingsInputDecoration(
            context,
            label: 'New email address',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: settingsInputDecoration(
            context,
            label: 'Current password',
          ),
        ),
        const SizedBox(height: 18),
        SettingsPrimaryButton(
          label: 'Send verification',
          icon: Icons.mark_email_read_outlined,
          onPressed: () {
            final email = _email.text.trim();
            if (!email.contains('@') || _password.text.isEmpty) return;
            Navigator.pop(context, (email: email, password: _password.text));
          },
        ),
      ],
    ),
  );
}
