/// Temporary demo control: quick switch between farmer / DA / admin test accounts.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/admin_session.dart';
import '../core/app_state.dart';
import '../core/demo_accounts.dart';
import '../core/security_prefs.dart';
import '../core/supabase_client.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/cloud_sync_service.dart';
import '../services/supabase_profile_service.dart';
import '../widgets/online_required_dialog.dart';

class DemoAccountSwitcher extends StatefulWidget {
  const DemoAccountSwitcher({super.key});

  @override
  State<DemoAccountSwitcher> createState() => _DemoAccountSwitcherState();
}

class _DemoAccountSwitcherState extends State<DemoAccountSwitcher> {
  static String? _sessionPassword;

  bool _switching = false;

  String? get _currentEmail =>
      SupabaseClientProvider.instance.client.auth.currentUser?.email
          ?.trim()
          .toLowerCase();

  Future<String?> _resolvePassword() async {
    final String fromEnv = demoSwitchPasswordFromEnv();
    if (fromEnv.isNotEmpty) return fromEnv;
    if (_sessionPassword != null && _sessionPassword!.isNotEmpty) {
      return _sessionPassword;
    }

    final TextEditingController controller = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Demo account password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Enter the shared password for your test accounts. '
                'It is kept in memory for this app session only.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (String value) {
                  Navigator.of(dialogContext).pop(value);
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (entered == null || entered.isEmpty) return null;
    _sessionPassword = entered;
    return entered;
  }

  Future<void> _switchTo(DemoAccountPreset preset) async {
    if (_switching) return;
    final String targetEmail = preset.email.toLowerCase();
    if (_currentEmail == targetEmail) return;
    if (!await ensureOnline(context)) return;

    final String? password = await _resolvePassword();
    if (!mounted || password == null || password.isEmpty) return;

    setState(() => _switching = true);
    final SupabaseClient client = SupabaseClientProvider.instance.client;
    try {
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      );
      await SecurityPrefs.markSuccessfulLogin();
      await SupabaseProfileService().upsertCurrentUserProfile();

      if (!mounted) return;
      final AppState appState = context.read<AppState>();
      appState.setLoggedIn(true);
      appState.bumpCapturedPhotos();
      appState.bumpFieldRecency();

      // Best-effort cloud pull for the new account.
      // ignore: discarded_futures
      CapturedPhotosRemoteSync().pullIntoLocalIfSignedIn();
      // ignore: discarded_futures
      CloudSyncService().syncInBackground();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${preset.label} (${preset.email})'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      _sessionPassword = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switch failed: ${e.message}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switch failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!demoAccountSwitcherEnabled()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final User? user = SupabaseClientProvider.instance.client.auth.currentUser;
    final String currentLabel = demoRoleLabelForCurrentUser(
      email: user?.email,
      isFullAdmin: userJwtFullAdmin(user),
      isDa: userJwtDa(user),
    );

    return Material(
      color: cs.tertiaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.swap_horiz, size: 18, color: cs.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Demo · switch account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                const Spacer(),
                if (_switching)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.tertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Current: $currentLabel',
              style: TextStyle(
                fontSize: 12,
                color: cs.onTertiaryContainer.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kDemoAccountPresets.map((DemoAccountPreset preset) {
                final bool selected =
                    _currentEmail == preset.email.toLowerCase();
                return ChoiceChip(
                  label: Text(preset.label),
                  selected: selected,
                  onSelected: _switching || selected
                      ? null
                      : (_) {
                          // ignore: discarded_futures
                          _switchTo(preset);
                        },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
