// Register with username, optional email + password (faster input than OTP).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase_client.dart';
import '../core/security_prefs.dart';
import '../services/supabase_profile_service.dart';
import '../utils/welcome_navigation.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';
import 'login_screen.dart' show LoginRouteArgs;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  static const String _syntheticEmailDomain = 'users.pine.app';

  String _slugForSyntheticEmail(String raw) {
    final String lower = raw.trim().toLowerCase();
    String slug = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');
    slug = slug.replaceAll(RegExp(r'\.{2,}'), '.');
    if (slug.isEmpty) return 'user';
    if (slug.length > 32) return slug.substring(0, 32);
    return slug;
  }

  String _randomAlnum(int length) {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random r = Random();
    return List<String>.generate(
      length,
      (_) => chars[r.nextInt(chars.length)],
    ).join();
  }

  String _syntheticLoginEmail(String username) =>
      '${_slugForSyntheticEmail(username)}.${_randomAlnum(8)}@$_syntheticEmailDomain';

  Future<void> _openMailApp(String email) async {
    final Uri mailtoUri = Uri(scheme: 'mailto', path: email);
    try {
      final bool launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open a mail app. Address: $email'),
            backgroundColor: Theme.of(context).colorScheme.inverseSurface,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open a mail app. Address: $email'),
          backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        ),
      );
    }
  }

  Future<void> _resendConfirmationEmail(String email) async {
    try {
      await SupabaseClientProvider.instance.client.auth.resend(
        email: email,
        type: OtpType.signup,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Confirmation email sent. Check inbox and spam.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not resend email: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _showConfirmEmailDialog(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Check your email (optional)'),
          content: Text(
            'If this project requires email confirmation, we sent a link '
            'to:\n\n$email\n\nIf sign-in works without confirming, you can '
            'ignore the message and sign in now.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _resendConfirmationEmail(email);
              },
              child: const Text('Resend'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _openMailApp(email);
              },
              child: const Text('Open email'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue to login'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSyntheticLoginEmailDialog(String loginEmail) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Save your sign-in address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'You skipped a personal email. Use this address when you '
                'sign in (you can also use your username on the login screen):',
              ),
              const SizedBox(height: 12),
              SelectableText(
                loginEmail,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: loginEmail));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              child: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? cs.error : cs.primary,
      ),
    );
  }

  Future<void> _register() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final String username = _usernameController.text.trim();
    final String emailInput = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text;
    final String confirm = _confirmController.text;

    if (username.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Please add a username and password', isError: true);
      return;
    }
    if (username.length < 2) {
      _showSnack('Username must be at least 2 characters', isError: true);
      return;
    }
    if (username.contains('@')) {
      _showSnack('Username cannot contain @', isError: true);
      return;
    }
    if (emailInput.isNotEmpty && !emailInput.contains('@')) {
      _showSnack('Enter a valid email or leave it blank', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnack('Passwords do not match', isError: true);
      return;
    }

    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final SupabaseClient supabase = SupabaseClientProvider.instance.client;
      final bool usedSyntheticEmail = emailInput.isEmpty;
      final String authEmail =
          usedSyntheticEmail ? _syntheticLoginEmail(username) : emailInput;

      final AuthResponse response = await supabase.auth.signUp(
        email: authEmail,
        password: password,
        data: <String, dynamic>{'display_name': username},
      );
      final Session? newSession = response.session;

      // Email confirmation enabled in Supabase → no session until user verifies.
      if (newSession == null) {
        if (!mounted) return;
        await _showConfirmEmailDialog(authEmail);
        if (!mounted) return;
        Navigator.pushReplacementNamed<void, void>(
          context,
          '/login',
          arguments: LoginRouteArgs(email: authEmail),
        );
        return;
      }

      await SecurityPrefs.markSuccessfulLogin();
      await SupabaseProfileService().upsertCurrentUserProfile();
      if (usedSyntheticEmail && mounted) {
        await _showSyntheticLoginEmailDialog(authEmail);
      }
      await _maybePromptEnableDeviceUnlock();
      if (!mounted) return;
      await Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (Route<dynamic> route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final String msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('user already')) {
        _showSnack(
          'This email is already registered. Sign in with the same password, '
          'or use Forgot password if needed.',
          isError: true,
        );
      } else {
        _showSnack(e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Registration failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _maybePromptEnableDeviceUnlock() async {
    if (!mounted) return;
    final bool shown = await SecurityPrefs.deviceUnlockPromptShown();
    if (shown) return;

    await SecurityPrefs.setDeviceUnlockPromptShown(true);

    if (!mounted) return;
    final bool? enable = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Enable device unlock?'),
          content: const Text(
            'For extra privacy, require your fingerprint/face or device PIN each time you open the app.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (enable == true) {
      await SecurityPrefs.setRequireDeviceUnlock(true);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ).copyWith(suffixIcon: suffixIcon);
  }

  Widget _buildRegisterForm(BuildContext context, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_rounded,
              size: 30,
              color: cs.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Register',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Username required. Email optional.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          enabled: !_loading,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          decoration: _fieldDecoration(
            label: 'Username',
            hint: 'How we’ll show your name',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Email (optional)',
            hint: 'Leave blank for generated login',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          enabled: !_loading,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Password',
            hint: 'At least 6 characters',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmController,
          enabled: !_loading,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _register(),
          decoration: _fieldDecoration(
            label: 'Confirm password',
            hint: 'Re-enter password',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Text('Create account'),
          ),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pushReplacementNamed(context, '/login'),
          child: Text(
            'Already have an account? Sign in',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'Register',
      leading: welcomeBackButton(context),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.center,
                  child: _buildRegisterForm(context, cs),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
