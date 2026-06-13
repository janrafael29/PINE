// Login with username or email + password (no SMS / phone).
library;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/supabase_client.dart';
import '../core/security_prefs.dart';
import '../core/theme.dart';
import '../services/supabase_profile_service.dart';
import '../utils/welcome_navigation.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';
import 'forgot_password_screen.dart' show ForgotPasswordRouteArgs;

/// Pass via [Navigator.pushNamed] `arguments` to prefill email on login (e.g. after register).
class LoginRouteArgs {
  const LoginRouteArgs({this.email});

  final String? email;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.prefillEmail,
  });

  final String? prefillEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefillEmail ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isEmailNotConfirmed(AuthException e) {
    final String m = e.message.toLowerCase();
    return m.contains('email not confirmed') ||
        (m.contains('not confirmed') && m.contains('email'));
  }

  /// Returns the auth email for [identifier] (email string or [profiles.display_name]).
  ///
  /// Throws [PostgrestException] if the lookup RPC fails (e.g. migration not applied).
  Future<String?> _resolveSignInEmail(String identifier) async {
    final String trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('@')) {
      return trimmed.toLowerCase();
    }
    final dynamic res =
        await SupabaseClientProvider.instance.client.rpc<dynamic>(
      'resolve_sign_in_email',
      params: <String, dynamic>{'p_identifier': trimmed},
    );
    if (res is String && res.isNotEmpty) return res;
    return null;
  }

  /// Opens **Gmail** on the device when possible.
  ///
  /// - **Android:** [SENDTO] intent with package [com.google.android.gm], then
  ///   a generic mailto intent (any mail app), then [url_launcher].
  /// - **iOS:** `googlegmail://` compose link, then `mailto:`.
  /// - Do not rely on [canLaunchUrl] for `mailto:` on Android — it is often wrong.
  Future<void> _openMailApp(String email) async {
    final Uri mailtoUri = Uri(scheme: 'mailto', path: email);
    final String mailtoData = Uri.encodeFull('mailto:$email');

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final AndroidIntent gmailIntent = AndroidIntent(
          action: 'android.intent.action.SENDTO',
          data: mailtoData,
          package: 'com.google.android.gm',
        );
        await gmailIntent.launch();
        return;
      } catch (_) {
        // Gmail not installed or intent blocked — try any mail handler.
      }
      try {
        final AndroidIntent anyMailIntent = AndroidIntent(
          action: 'android.intent.action.SENDTO',
          data: mailtoData,
        );
        await anyMailIntent.launch();
        return;
      } catch (_) {
        // Fall through to url_launcher.
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final Uri gmailUri = Uri.parse(
        'googlegmail://co?to=${Uri.encodeComponent(email)}',
      );
      try {
        final bool launched = await launchUrl(
          gmailUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}
    }

    try {
      bool launched = await launchUrl(mailtoUri, mode: LaunchMode.platformDefault);
      if (!launched) {
        launched = await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      }
      if (!launched && mounted) {
        await _showMailFallbackSnack(email);
      }
    } catch (_) {
      if (mounted) await _showMailFallbackSnack(email);
    }
  }

  Future<void> _showMailFallbackSnack(String email) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          'Could not open Gmail or another mail app. Address: $email',
        ),
        action: SnackBarAction(
          label: 'Copy email',
          textColor: Colors.white,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                content: const Text('Email copied to clipboard'),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          },
        ),
      ),
    );
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text(
            'Confirmation email sent. Check your inbox and spam folder.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(e.message),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Could not resend email: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _showEmailNotConfirmedDialog(String email) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme cs = theme.colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_unread_rounded,
                    size: 34,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Email confirmation',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  'If your project requires it, open the link we sent to this '
                  'address. If sign-in is allowed without confirming, try again '
                  'in a moment or ask your admin to turn off email confirmation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: SelectableText(
                    email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Optional: open our message and tap Confirm. '
                          'Check Spam / Junk if you don\'t see it.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Column(
                  children: <Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _openMailApp(email);
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 20),
                        label: const Text('Open Gmail'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.primary,
                          side: BorderSide(color: cs.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _resendConfirmationEmail(email);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('Resend confirmation email'),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Got it'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    final String identifier = _emailController.text.trim();
    final String password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: const Text('Enter your username or email and password'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final SupabaseClient supabase = SupabaseClientProvider.instance.client;
      final String? email;
      try {
        email = await _resolveSignInEmail(identifier);
      } on PostgrestException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Username sign-in needs the database function resolve_sign_in_email '
              '(run migration 20250509000000_resolve_sign_in_email.sql). ${e.message}',
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
      if (email == null || email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'No account found for that username. Try your full email address.',
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }

      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await SecurityPrefs.markSuccessfulLogin();

      await SupabaseProfileService().upsertCurrentUserProfile();
      await _maybePromptEnableDeviceUnlock();
      if (!mounted) return;
      await Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (Route<dynamic> route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      if (_isEmailNotConfirmed(e)) {
        await _showEmailNotConfirmedDialog(
          await _resolveSignInEmail(identifier) ?? identifier,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(e.message),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Login failed: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Login',
      leading: welcomeBackButton(context),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ColorScheme cs = Theme.of(context).colorScheme;
              final double keyboardBottomInset = MediaQuery.of(context).viewInsets.bottom;
              final bool keyboardOpen = keyboardBottomInset > 0;
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + keyboardBottomInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(height: keyboardOpen ? 0 : 8),
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              AppTheme.primaryGreen.withValues(alpha: 0.15),
                              AppTheme.secondaryGreen.withValues(alpha: 0.12),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mail_outline_rounded,
                          size: 44,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    SizedBox(height: keyboardOpen ? 16 : 28),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your username or email and password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.35,
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    SizedBox(height: keyboardOpen ? 16 : 28),
                    Card(
                      elevation: 0,
                      color: cs.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Email or username',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _emailController,
                              enabled: !_loading,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              decoration: InputDecoration(
                                hintText: 'Username or name@email.com',
                                prefixIcon: Icon(
                                  Icons.alternate_email_rounded,
                                  color: cs.onSurfaceVariant,
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.outline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Password',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _passwordController,
                              enabled: !_loading,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _login(),
                              scrollPadding: const EdgeInsets.only(bottom: 140),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: cs.onSurfaceVariant,
                                  size: 22,
                                ),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.outline,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.pushNamed(
                                          context,
                                          '/forgot-password',
                                          arguments: ForgotPasswordRouteArgs(
                                            email: _emailController.text
                                                .trim(),
                                          ),
                                        ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _loading
                                    ? SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pushNamed(context, '/register'),
                      child: Text(
                        'Create an account',
                        style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}
