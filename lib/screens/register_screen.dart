// Register: choose farmer vs staff, then the matching sign-up form.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/account_intent.dart';
import '../core/registration_setup_prefs.dart';
import '../core/security_prefs.dart';
import '../core/supabase_client.dart';
import '../services/da_access_request_service.dart';
import '../services/supabase_profile_service.dart';
import '../utils/welcome_navigation.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';
import '../core/staff_role_labels.dart';
import '../widgets/register_role_picker.dart';
import 'login_screen.dart' show LoginRouteArgs;

enum _RegisterStep { chooseRole, farmerForm, staffForm }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _RegisterStep _step = _RegisterStep.chooseRole;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  final TextEditingController _staffPasswordController = TextEditingController();
  final TextEditingController _staffConfirmController = TextEditingController();
  final TextEditingController _staffNoteController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _staffObscurePassword = true;
  bool _staffObscureConfirm = true;
  bool _staffConfirmed = false;

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

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _fullNameController.dispose();
    _organizationController.dispose();
    _locationController.dispose();
    _positionController.dispose();
    _staffEmailController.dispose();
    _staffPasswordController.dispose();
    _staffConfirmController.dispose();
    _staffNoteController.dispose();
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

  void _chooseRole(AccountIntent intent) {
    setState(() {
      _step = intent == AccountIntent.farmer
          ? _RegisterStep.farmerForm
          : _RegisterStep.staffForm;
    });
  }

  void _backToRolePicker() {
    setState(() {
      _step = _RegisterStep.chooseRole;
      _staffConfirmed = false;
    });
  }

  Future<void> _openMailApp(String email) async {
    final Uri mailtoUri = Uri(scheme: 'mailto', path: email);
    try {
      final bool launched = await launchUrl(
        mailtoUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showSnack('Could not open a mail app. Address: $email', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      _showSnack('Could not open a mail app. Address: $email', isError: true);
    }
  }

  Future<void> _resendConfirmationEmail(String email) async {
    try {
      await SupabaseClientProvider.instance.client.auth.resend(
        email: email,
        type: OtpType.signup,
      );
      if (!mounted) return;
      _showSnack('Confirmation email sent. Check inbox and spam.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showSnack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Could not resend email: $e', isError: true);
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

  Future<void> _showStaffRequestSentDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Staff request sent'),
          content: const Text(
            'Your account was created and your agriculturist access request was sent '
            'to an administrator. You can use the app while you wait. '
            'Sign out and sign in again after approval to unlock agriculturist tools.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
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

  Future<void> _finishSignedInRegistration({
    required AccountIntent intent,
    required String authEmail,
    required bool usedSyntheticEmail,
    String? staffFullName,
    String? staffOrganization,
    String? staffLocation,
    String? staffPosition,
    String? staffNote,
  }) async {
    await SecurityPrefs.markSuccessfulLogin();
    await SupabaseProfileService().upsertCurrentUserProfile();
    await AccountIntentService().setCurrent(intent);

    if (intent == AccountIntent.staff) {
      try {
        await DaAccessRequestService().submitRequest(
          fullName: staffFullName ?? '',
          organization: staffOrganization ?? '',
          companyLocation: staffLocation ?? '',
          position: staffPosition ?? '',
          note: staffNote,
        );
        if (mounted) await _showStaffRequestSentDialog();
      } on StateError catch (e) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Staff request'),
              content: Text(e.message),
              actions: <Widget>[
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      }
    } else if (usedSyntheticEmail && mounted) {
      await _showSyntheticLoginEmailDialog(authEmail);
    }

    await _maybePromptEnableDeviceUnlock();
    if (!mounted) return;
    await Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _handleEmailConfirmPending({
    required String authEmail,
    required AccountIntent intent,
    String? staffFullName,
    String? staffOrganization,
    String? staffLocation,
    String? staffPosition,
    String? staffNote,
  }) async {
    await savePendingRegistrationSetup(
      PendingRegistrationSetup(
        email: authEmail,
        intent: intent,
        fullName: staffFullName,
        organization: staffOrganization,
        companyLocation: staffLocation,
        position: staffPosition,
        note: staffNote,
      ),
    );
    if (!mounted) return;
    await _showConfirmEmailDialog(authEmail);
    if (!mounted) return;
    Navigator.pushReplacementNamed<void, void>(
      context,
      '/login',
      arguments: LoginRouteArgs(email: authEmail),
    );
  }

  Future<void> _registerFarmer() async {
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

      if (newSession == null) {
        await _handleEmailConfirmPending(
          authEmail: authEmail,
          intent: AccountIntent.farmer,
        );
        return;
      }

      await _finishSignedInRegistration(
        intent: AccountIntent.farmer,
        authEmail: authEmail,
        usedSyntheticEmail: usedSyntheticEmail,
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

  Future<void> _signInExistingStaffAndSubmitRequest({
    required String fullName,
    required String organization,
    required String location,
    required String position,
    required String email,
    required String password,
    String? note,
  }) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Account already exists'),
          content: const Text(
            'This email is already registered. Sign in with the password '
            'you entered and we will submit your agriculturist access request.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign in & submit request'),
            ),
          ],
        );
      },
    );
    if (proceed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      final SupabaseClient supabase = SupabaseClientProvider.instance.client;
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        _showSnack('Sign in failed. Check your password.', isError: true);
        return;
      }
      await _finishSignedInRegistration(
        intent: AccountIntent.staff,
        authEmail: email,
        usedSyntheticEmail: false,
        staffFullName: fullName,
        staffOrganization: organization,
        staffLocation: location,
        staffPosition: position,
        staffNote: note,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final bool? goLogin = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Could not sign in'),
            content: const Text(
              'The password does not match this account. Sign in on the login '
              'screen or use Forgot password if needed.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Stay here'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Go to sign in'),
              ),
            ],
          );
        },
      );
      if (goLogin == true && mounted) {
        Navigator.pushReplacementNamed<void, void>(
          context,
          '/login',
          arguments: LoginRouteArgs(email: email),
        );
      } else if (mounted) {
        _showSnack(e.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Sign in failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerStaff() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final String fullName = _fullNameController.text.trim();
    final String organization = _organizationController.text.trim();
    final String location = _locationController.text.trim();
    final String position = _positionController.text.trim();
    final String email = _staffEmailController.text.trim().toLowerCase();
    final String password = _staffPasswordController.text;
    final String confirm = _staffConfirmController.text;
    final String note = _staffNoteController.text.trim();

    if (fullName.isEmpty ||
        organization.isEmpty ||
        location.isEmpty ||
        position.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty) {
      _showSnack('Fill in all required fields', isError: true);
      return;
    }
    if (!email.contains('@')) {
      _showSnack('Enter a valid work email', isError: true);
      return;
    }
    if (!_staffConfirmed) {
      _showSnack('Confirm that you are government staff', isError: true);
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
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{'display_name': fullName},
      );
      final Session? newSession = response.session;

      if (newSession == null) {
        await _handleEmailConfirmPending(
          authEmail: email,
          intent: AccountIntent.staff,
          staffFullName: fullName,
          staffOrganization: organization,
          staffLocation: location,
          staffPosition: position,
          staffNote: note.isEmpty ? null : note,
        );
        return;
      }

      await _finishSignedInRegistration(
        intent: AccountIntent.staff,
        authEmail: email,
        usedSyntheticEmail: false,
        staffFullName: fullName,
        staffOrganization: organization,
        staffLocation: location,
        staffPosition: position,
        staffNote: note.isEmpty ? null : note,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final String msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('user already')) {
        if (mounted) setState(() => _loading = false);
        await _signInExistingStaffAndSubmitRequest(
          fullName: fullName,
          organization: organization,
          location: location,
          position: position,
          email: email,
          password: password,
          note: note.isEmpty ? null : note,
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

  Widget _staffWarningBanner(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: cs.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'For $staffRoleWithOmagLgu staff only. Your request will be reviewed '
              'by an administrator before agriculturist tools are enabled.',
              style: TextStyle(color: cs.onSurface, fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Farmer account',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
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
          onSubmitted: (_) => _registerFarmer(),
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
            onPressed: _loading ? null : _registerFarmer,
            child: _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Text('Create farmer account'),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '$staffRoleWithOmagLgu staff',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _staffWarningBanner(cs),
        const SizedBox(height: 12),
        TextField(
          controller: _fullNameController,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Full name *',
            hint: 'Juan Dela Cruz',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _organizationController,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Organization *',
            hint: 'DA Region XI, OMAG, LGU…',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _locationController,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Office location *',
            hint: 'City, province, or office address',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _positionController,
          enabled: !_loading,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Position *',
            hint: 'Agriculturist, extension officer…',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _staffEmailController,
          enabled: !_loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Work email *',
            hint: 'you@da.gov.ph',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _staffPasswordController,
          enabled: !_loading,
          obscureText: _staffObscurePassword,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Password *',
            hint: 'At least 6 characters',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _staffObscurePassword = !_staffObscurePassword);
              },
              icon: Icon(
                _staffObscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _staffConfirmController,
          enabled: !_loading,
          obscureText: _staffObscureConfirm,
          textInputAction: TextInputAction.next,
          decoration: _fieldDecoration(
            label: 'Confirm password *',
            hint: 'Re-enter password',
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _staffObscureConfirm = !_staffObscureConfirm);
              },
              icon: Icon(
                _staffObscureConfirm ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _staffNoteController,
          enabled: !_loading,
          maxLines: 2,
          decoration: _fieldDecoration(
            label: 'Optional note',
            hint: 'Employee ID or contact number',
          ),
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          value: _staffConfirmed,
          onChanged: _loading
              ? null
              : (bool? value) {
                  setState(() => _staffConfirmed = value ?? false);
                },
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I confirm I work as $staffRoleWithOmagLgu extension staff.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _loading || !_staffConfirmed ? null : _registerStaff,
            child: _loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: cs.onPrimary,
                    ),
                  )
                : const Text('Create staff account'),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ColorScheme cs) {
    switch (_step) {
      case _RegisterStep.chooseRole:
        return RegisterRolePicker(
          onFarmer: () => _chooseRole(AccountIntent.farmer),
          onStaff: () => _chooseRole(AccountIntent.staff),
        );
      case _RegisterStep.farmerForm:
        return _buildFarmerForm(cs);
      case _RegisterStep.staffForm:
        return _buildStaffForm(cs);
    }
  }

  String _appBarTitle() {
    switch (_step) {
      case _RegisterStep.chooseRole:
        return 'Register';
      case _RegisterStep.farmerForm:
        return 'Farmer registration';
      case _RegisterStep.staffForm:
        return 'Staff registration';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool showFormBack = _step != _RegisterStep.chooseRole;

    return AppScaffold(
      title: _appBarTitle(),
      leading: showFormBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _loading ? null : _backToRolePicker,
            )
          : welcomeBackButton(context),
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
                  alignment: _step == _RegisterStep.chooseRole
                      ? Alignment.topCenter
                      : Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_step != _RegisterStep.chooseRole) ...<Widget>[
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _step == _RegisterStep.farmerForm
                                  ? Icons.agriculture_outlined
                                  : Icons.badge_outlined,
                              size: 30,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildBody(cs),
                      if (_step != _RegisterStep.chooseRole) ...<Widget>[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () =>
                                  Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...<Widget>[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/login'),
                          child: Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
