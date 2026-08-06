import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../providers/app_providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.error});

  final String? error;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _loginPasswordVisible = false;
  bool _termsAccepted = false;
  int _registerStep = 0;
  String? _error;

  bool get _upgradingGuest => ref.read(sessionProvider).value?.isGuest == true;

  @override
  void initState() {
    super.initState();
    _register = ref.read(sessionProvider).value?.isGuest == true;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_loading) return;
    if (_register && _registerStep > 0) {
      setState(() {
        _registerStep--;
        _error = null;
      });
      return;
    }
    if (_register && !_upgradingGuest) {
      setState(() {
        _register = false;
        _error = null;
      });
      return;
    }
    ref.read(showAuthProvider.notifier).state = false;
  }

  void _openRegistration() {
    if (_loading) return;
    setState(() {
      _register = true;
      _registerStep = 0;
      _error = null;
    });
  }

  void _openLogin() {
    if (_loading) return;
    setState(() {
      _register = false;
      _registerStep = 0;
      _error = null;
    });
  }

  void _continueRegistration() {
    final validationError = _registerStep == 0
        ? _validateIdentity()
        : _validateCredentials();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _registerStep++;
      _error = null;
    });
  }

  String? _validateIdentity() {
    if (_fullNameController.text.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validateCredentials() {
    if (_usernameController.text.trim().isEmpty) {
      return 'Please choose a username.';
    }
    final password = _passwordController.text;
    if (password.length < 8 ||
        !RegExp(r'\d').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Use at least 8 characters, 1 number, and 1 special character.';
    }
    if (password != _confirmPasswordController.text) {
      return 'Password confirmation does not match.';
    }
    return null;
  }

  Future<void> _submitLogin() async {
    if (_loginUsernameController.text.trim().isEmpty ||
        _loginPasswordController.text.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }
    await _runRequest(() async {
      final session = await ref
          .read(apiProvider)
          .login(
            _loginUsernameController.text.trim(),
            _loginPasswordController.text,
          );
      await ref.read(sessionStoreProvider).save(session);
    });
  }

  Future<void> _submitRegistration() async {
    final identityError = _validateIdentity();
    final credentialsError = _validateCredentials();
    if (identityError != null || credentialsError != null) {
      setState(() {
        _registerStep = identityError != null ? 0 : 1;
        _error = identityError ?? credentialsError;
      });
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Please accept the Terms and Privacy Policy.');
      return;
    }
    await _runRequest(() async {
      final api = ref.read(apiProvider);
      await api.register(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        preserveGuest: _upgradingGuest,
      );
      final session = await api.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      await ref.read(sessionStoreProvider).save(session);
    });
  }

  Future<void> _runRequest(Future<void> Function() request) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await request();
      ref.read(showAuthProvider.notifier).state = false;
      ref.invalidate(sessionProvider);
      ref.invalidate(dashboardProvider);
    } catch (exception) {
      if (mounted) {
        setState(() {
          _error = exception is DioException
              ? _messageFromDio(exception)
              : exception.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showForgotPasswordMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password recovery is not available yet. Please contact support.',
        ),
      ),
    );
  }

  void _showPolicy() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Privacy Policy'),
        content: const Text(
          'By creating an account, you agree that Broke.AI may securely store '
          'your account and transaction data to provide expense tracking and '
          'AI insights.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surfaceCard,
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: _register ? _buildRegistrationPage() : _buildLoginPage(),
      ),
    ),
  );

  Widget _buildLoginPage() => SingleChildScrollView(
    key: const ValueKey('login-page'),
    padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleBackButton(onPressed: _goBack),
            ),
            const _AuthBrand(vertical: true),
            SizedBox(
              height: 240,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          const TextSpan(
                            children: [
                              TextSpan(text: 'Welcome\nback'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 43,
                            height: 1.02,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'One place for every\nspending story.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 17,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -36,
                    bottom: -12,
                    width: 245,
                    height: 245,
                    child: Image.asset(
                      AppAssets.loginDog,
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ],
              ),
            ),
            _LoginCard(
              usernameController: _loginUsernameController,
              passwordController: _loginPasswordController,
              passwordVisible: _loginPasswordVisible,
              loading: _loading,
              error: _error ?? widget.error,
              onTogglePassword: () => setState(
                () => _loginPasswordVisible = !_loginPasswordVisible,
              ),
              onForgotPassword: _showForgotPasswordMessage,
              onSubmit: _submitLogin,
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _loading ? null : _openRegistration,
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'New here? ',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    TextSpan(
                      text: 'Register',
                      style: TextStyle(color: AppColors.primaryAccent),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildRegistrationPage() => SingleChildScrollView(
    key: ValueKey('register-step-$_registerStep'),
    padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          children: [
            const _AuthBrand(),
            const SizedBox(height: 16),
            _RegistrationProgress(step: _registerStep),
            const SizedBox(height: 16),
            if (_registerStep == 0) _buildIdentityStep(),
            if (_registerStep == 1) _buildSecurityStep(),
            if (_registerStep == 2) _buildConfirmationStep(),
          ],
        ),
      ),
    ),
  );

  Widget _buildIdentityStep() => Column(
    children: [
      const _RegistrationHero(
        step: 1,
        title: 'Save your\nguest history',
        subtitle:
            'Create an account to keep your\nexisting transactions safe and\nconnected.',
        asset: AppAssets.registerDog,
        imageAlignment: Alignment(0.3, 0),
      ),
      const SizedBox(height: 10),
      _AuthField(
        key: const ValueKey('register-full-name'),
        controller: _fullNameController,
        hint: 'Full name',
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
      ),
      const SizedBox(height: 9),
      _AuthField(
        key: const ValueKey('register-email'),
        controller: _emailController,
        hint: 'Email',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.email],
      ),
      const SizedBox(height: 12),
      const _BenefitCard(
        title: 'Why create an account?',
        benefits: [
          _Benefit(
            icon: Icons.shield_outlined,
            color: AppColors.primaryAccent,
            title: 'Save your\ntransaction history',
            subtitle: 'Never lose track\nof your data.',
          ),
          _Benefit(
            icon: Icons.devices_rounded,
            color: AppColors.secondaryAccent,
            title: 'Sync across\nall your devices',
            subtitle: 'Access your data\nanytime, anywhere.',
          ),
          _Benefit(
            icon: Icons.smart_toy_outlined,
            color: AppColors.successMint,
            title: 'Unlock continued\nAI access',
            subtitle: 'Keep getting smarter\nfinancial insights.',
          ),
        ],
      ),
      _InlineError(message: _error ?? widget.error),
      _GoldButton(
        label: 'Continue',
        loading: false,
        onPressed: _continueRegistration,
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _openLogin,
        child: const Text(
          'Already have an account? Sign in',
          style: TextStyle(color: AppColors.primaryAccent, fontSize: 16),
        ),
      ),
    ],
  );

  Widget _buildSecurityStep() => Column(
    children: [
      const _RegistrationHero(
        step: 2,
        title: 'Secure your\naccount',
        subtitle:
            'Choose a username and password\nto protect your data and keep your\nhistory safe.',
        asset: AppAssets.registerSecureDog,
        imageAlignment: Alignment(0.22, 0),
      ),
      const SizedBox(height: 10),
      _AuthField(
        key: const ValueKey('register-username'),
        controller: _usernameController,
        hint: 'Username',
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newUsername],
      ),
      const SizedBox(height: 9),
      _AuthField(
        key: const ValueKey('register-password'),
        controller: _passwordController,
        hint: 'Password',
        icon: Icons.lock_outline_rounded,
        obscureText: !_passwordVisible,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        suffixIcon: IconButton(
          tooltip: _passwordVisible ? 'Hide password' : 'Show password',
          onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          icon: Icon(
            _passwordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      const SizedBox(height: 9),
      _AuthField(
        key: const ValueKey('register-confirm-password'),
        controller: _confirmPasswordController,
        hint: 'Confirm password',
        icon: Icons.lock_outline_rounded,
        obscureText: !_confirmPasswordVisible,
        textInputAction: TextInputAction.done,
        suffixIcon: IconButton(
          tooltip: _confirmPasswordVisible
              ? 'Hide confirm password'
              : 'Show confirm password',
          onPressed: () => setState(
            () => _confirmPasswordVisible = !_confirmPasswordVisible,
          ),
          icon: Icon(
            _confirmPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Row(
        children: [
          Expanded(
            child: _RequirementChip(
              icon: Icons.verified_user_outlined,
              label: '8+ characters',
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _RequirementChip(icon: Icons.tag_rounded, label: '1 number'),
          ),
          SizedBox(width: 8),
          Expanded(
            child: _RequirementChip(
              icon: Icons.auto_awesome_rounded,
              label: '1 special character',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _BenefitCard(
        title: 'Why this matters',
        benefits: [
          _Benefit(
            icon: Icons.shield_outlined,
            color: AppColors.primaryAccent,
            title: 'Your guest data\nstays protected',
            subtitle: 'We use strong security\nto keep your data safe.',
          ),
          _Benefit(
            icon: Icons.devices_rounded,
            color: AppColors.secondaryAccent,
            title: 'You can sign in\nacross devices',
            subtitle: 'Access your account\nanytime, anywhere.',
          ),
        ],
      ),
      _InlineError(message: _error),
      _GoldButton(
        label: 'Continue',
        loading: false,
        onPressed: _continueRegistration,
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _goBack,
        child: const Text(
          'Back to previous step',
          style: TextStyle(color: AppColors.primaryAccent, fontSize: 16),
        ),
      ),
    ],
  );

  Widget _buildConfirmationStep() => Column(
    children: [
      const _RegistrationHero(
        step: 3,
        title: 'You’re all set!',
        subtitle:
            'Create your account now and\nmove your guest transactions\ninto your new Broke.AI profile.',
        asset: AppAssets.registerCompleteDog,
        imageAlignment: Alignment(0.16, 0),
      ),
      const SizedBox(height: 10),
      const _BenefitCard(
        title: 'What will be saved',
        benefits: [
          _Benefit(
            icon: Icons.history_rounded,
            color: AppColors.primaryAccent,
            title: 'Guest transaction\nhistory',
            subtitle: 'Never lose track of\nyour past activity.',
          ),
          _Benefit(
            icon: Icons.pie_chart_outline_rounded,
            color: AppColors.secondaryAccent,
            title: 'Categories and\nsummaries',
            subtitle: 'Keep your insights\norganized.',
          ),
          _Benefit(
            icon: Icons.document_scanner_outlined,
            color: AppColors.successMint,
            title: 'AI scan access',
            subtitle: 'Continue using AI to\nanalyze receipts.',
          ),
        ],
      ),
      const SizedBox(height: 12),
      _AccountSummary(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _authSurfaceDecoration(radius: 18),
        child: Row(
          children: [
            Checkbox(
              value: _termsAccepted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              activeColor: AppColors.primaryAccent,
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _termsAccepted = value ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: _showPolicy,
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms and Privacy Policy.',
                        style: TextStyle(color: AppColors.primaryAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      _InlineError(message: _error),
      _GoldButton(
        label: 'Create account',
        loading: _loading,
        onPressed: _loading ? null : _submitRegistration,
      ),
      const SizedBox(height: 10),
      TextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                _registerStep = 0;
                _error = null;
              }),
        child: const Text(
          'Edit details',
          style: TextStyle(color: AppColors.primaryAccent, fontSize: 16),
        ),
      ),
    ],
  );
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.usernameController,
    required this.passwordController,
    required this.passwordVisible,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: _authSurfaceDecoration(radius: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  AppAssets.loginFeature,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick up where you left off',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your spending story continues.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Divider(color: AppColors.borderSubtle),
        ),
        _AuthField(
          controller: usernameController,
          hint: 'Username',
          icon: Icons.person_outline_rounded,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        _AuthField(
          controller: passwordController,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          autofillHints: const [AutofillHints.password],
          obscureText: !passwordVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          suffixIcon: IconButton(
            tooltip: passwordVisible ? 'Hide password' : 'Show password',
            onPressed: onTogglePassword,
            icon: Icon(
              passwordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : onForgotPassword,
              child: const Text(
                'Forgot password?',
                style: TextStyle(color: AppColors.primaryAccent),
              ),
            ),
          ),
        ),
        _InlineError(message: error),
        _GoldButton(
          label: 'Sign in',
          loading: loading,
          onPressed: loading ? null : onSubmit,
        ),
      ],
    ),
  );
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        AppAssets.authBrandIcon,
        width: vertical ? 56 : 40,
        height: vertical ? 56 : 40,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
    const name = Text(
      'BROKE.AI',
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    );
    if (vertical) {
      return Column(children: [logo, const SizedBox(height: 10), name]);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [logo, const SizedBox(width: 14), name],
    );
  }
}

class _RegistrationProgress extends StatelessWidget {
  const _RegistrationProgress({required this.step});

  final int step;
  static const labels = ['Create account', 'Secure account', 'You’re all set'];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
    decoration: BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      children: List.generate(3, (index) {
        final active = index == step;
        final complete = index < step;
        return Expanded(
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (index < 2)
                Positioned(
                  top: 14,
                  left: 30,
                  right: -30,
                  child: Container(
                    height: 2,
                    color: complete
                        ? AppColors.secondaryAccent
                        : AppColors.borderSubtle,
                  ),
                ),
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryAccent,
                                Color(0xff55a5ff),
                              ],
                            )
                          : null,
                      color: active ? null : AppColors.surfaceCard,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? Colors.transparent
                            : AppColors.borderSubtle,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active
                          ? AppColors.primaryAccent
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    ),
  );
}

class _RegistrationHero extends StatelessWidget {
  const _RegistrationHero({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.imageAlignment,
  });

  final int step;
  final String title;
  final String subtitle;
  final String asset;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 10,
          right: -24,
          width: 204,
          height: 194,
          child: Image.asset(
            asset,
            alignment: imageAlignment,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryAccent,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Step $step of 3',
                  style: const TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 53,
          child: SizedBox(
            width: 245,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 35,
                height: 1.04,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: 132,
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.48,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    obscureText: obscureText,
    onSubmitted: onSubmitted,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: AppColors.surfaceCard,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xfff2efff),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryAccent),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 52),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: AppColors.primaryAccent,
          width: 1.8,
        ),
      ),
    ),
  );
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 42),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xfff7f5ff),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x335b50f6)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryAccent),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.title, required this.benefits});

  final String title;
  final List<_Benefit> benefits;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    decoration: _authSurfaceDecoration(radius: 22),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(benefits.length, (index) {
            final benefit = benefits[index];
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  border: index == 0
                      ? null
                      : const Border(
                          left: BorderSide(color: AppColors.borderSubtle),
                        ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: benefit.color.withValues(alpha: .09),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(benefit.icon, color: benefit.color, size: 22),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      benefit.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11.5,
                        height: 1.24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      benefit.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

class _Benefit {
  const _Benefit({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({
    required this.fullName,
    required this.email,
    required this.username,
  });

  final String fullName;
  final String email;
  final String username;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 4),
    decoration: _authSurfaceDecoration(radius: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Account summary',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        _SummaryRow(
          icon: Icons.person_outline_rounded,
          label: 'Full name',
          value: fullName,
        ),
        _SummaryRow(
          icon: Icons.mail_outline_rounded,
          label: 'Email',
          value: email,
        ),
        _SummaryRow(
          icon: Icons.alternate_email_rounded,
          label: 'Username',
          value: username,
          showDivider: false,
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      border: showDivider
          ? const Border(bottom: BorderSide(color: AppColors.borderSubtle))
          : null,
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xfff2efff),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.primaryAccent, size: 19),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffffc632), Color(0xffffab15)],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x38eab308),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(21),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.textPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox(height: 10)
      : Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceCard,
    shape: const CircleBorder(side: BorderSide(color: AppColors.borderSubtle)),
    child: IconButton(
      tooltip: 'Back to start options',
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
    ),
  );
}

BoxDecoration _authSurfaceDecoration({required double radius}) => BoxDecoration(
  color: AppColors.surfaceCard,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.borderSubtle),
  boxShadow: const [
    BoxShadow(color: Color(0x120f172a), blurRadius: 22, offset: Offset(0, 9)),
  ],
);

String _messageFromDio(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return 'Unable to connect to the server.';
}
