// Password reset via Supabase email link (matches email + password auth).
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_display_message.dart';
import '../core/supabase_client.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';

/// Optional [Navigator.pushNamed] arguments to prefill email from Login.
class ForgotPasswordRouteArgs {
  const ForgotPasswordRouteArgs({this.email});

  final String? email;
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.prefillEmail,
  });

  final String? prefillEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final TextEditingController _emailController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final String email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter the email address you registered with.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final SupabaseClient supabase = SupabaseClientProvider.instance.client;
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'pine://reset-password',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: const Text(
            'Reset link sent (if the email exists). Check Inbox + Spam/Junk for '
            'Pinya-Pic / p1ny4p1c@gmail.com.',
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErrorMessageForUser(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not send reset email. Check your connection and try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    return AppScaffold(
      title: 'Reset password',
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardPad),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 16),
              Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: cs.primary.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 20),
              Text(
                'Forgot your password?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your registered email address. We will send you a link '
                'to choose a new password. Check your Inbox and Spam/Junk. '
                'It may come from Pinya-Pic or p1ny4p1c@gmail.com.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.4,
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _sendResetLink,
                  child: _loading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text('Send reset link'),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Back to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
