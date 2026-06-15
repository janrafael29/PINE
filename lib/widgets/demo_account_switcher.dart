/// Temporary demo control: quick switch between farmer / DA / admin test accounts.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/admin_session.dart';
import '../core/demo_account_credentials_store.dart';
import '../core/demo_accounts.dart';
import '../core/theme.dart';
import '../screens/demo_account_switch_screen.dart';
import '../core/supabase_client.dart';
import '../widgets/online_required_dialog.dart';

class DemoAccountSwitcher extends StatefulWidget {
  const DemoAccountSwitcher({super.key});

  @override
  State<DemoAccountSwitcher> createState() => _DemoAccountSwitcherState();
}

class _DemoAccountSwitcherState extends State<DemoAccountSwitcher> {
  bool _switching = false;
  Map<String, DemoAccountCredentials> _saved = <String, DemoAccountCredentials>{};

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reloadSaved();
  }

  Future<void> _reloadSaved() async {
    final Map<String, DemoAccountCredentials> next =
        await DemoAccountCredentialsStore.loadAll();
    if (!mounted) return;
    setState(() => _saved = next);
  }

  User? get _user => SupabaseClientProvider.instance.client.auth.currentUser;

  Future<DemoAccountCredentials?> _promptCredentials(
    DemoAccountPreset preset, {
    DemoAccountCredentials? existing,
    required bool switchAfterSave,
  }) async {
    final TextEditingController emailController =
        TextEditingController(text: existing?.email ?? '');
    final TextEditingController passwordController =
        TextEditingController(text: existing?.password ?? '');

    try {
      final DemoAccountCredentials? result =
          await showDialog<DemoAccountCredentials>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('${preset.label} test account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    existing == null
                        ? 'Enter the email and password for your ${preset.label} '
                            'test account. They are saved on this device for '
                            'debug switching only.'
                        : 'Update saved ${preset.label} credentials on this device.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      Navigator.of(dialogContext).pop(
                        DemoAccountCredentials(
                          email: emailController.text.trim(),
                          password: passwordController.text,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await DemoAccountCredentialsStore.clear(preset.roleKey);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Clear saved'),
                ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final String email = emailController.text.trim();
                  final String password = passwordController.text;
                  if (email.isEmpty || password.isEmpty) return;
                  Navigator.of(dialogContext).pop(
                    DemoAccountCredentials(email: email, password: password),
                  );
                },
                child: Text(switchAfterSave ? 'Save & switch' : 'Save'),
              ),
            ],
          );
        },
      );
      return result;
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
  }

  Future<void> _switchTo(
    DemoAccountPreset preset, {
    bool forcePrompt = false,
  }) async {
    if (_switching) return;
    if (!await ensureOnline(context)) return;

    DemoAccountCredentials? creds = forcePrompt
        ? null
        : _saved[preset.roleKey] ??
            await DemoAccountCredentialsStore.load(preset.roleKey);

    if (creds == null) {
      creds = await _promptCredentials(
        preset,
        existing: _saved[preset.roleKey],
        switchAfterSave: true,
      );
      if (!mounted || creds == null) return;
      await DemoAccountCredentialsStore.save(
        roleKey: preset.roleKey,
        credentials: creds,
      );
      await _reloadSaved();
    }

    final String targetEmail = creds.email.trim().toLowerCase();
    final String? currentEmail = _user?.email?.trim().toLowerCase();
    if (currentEmail == targetEmail &&
        demoRoleChipSelected(
          roleKey: preset.roleKey,
          isFullAdmin: userJwtFullAdmin(_user),
          isDa: userJwtDa(_user),
        )) {
      return;
    }

    setState(() => _switching = true);
    bool handedOff = false;
    try {
      if (!mounted) return;
      handedOff = true;
      await Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        '/demo-account-switch',
        (_) => false,
        arguments: DemoAccountSwitchArgs(
          email: targetEmail,
          password: creds.password,
          label: preset.label,
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
      if (mounted && !handedOff) {
        setState(() => _switching = false);
      }
    }
  }

  Future<void> _editCredentials(DemoAccountPreset preset) async {
    final DemoAccountCredentials? creds = await _promptCredentials(
      preset,
      existing: _saved[preset.roleKey],
      switchAfterSave: false,
    );
    if (!mounted || creds == null) {
      await _reloadSaved();
      return;
    }
    await DemoAccountCredentialsStore.save(
      roleKey: preset.roleKey,
      credentials: creds,
    );
    await _reloadSaved();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved ${preset.label} account (${demoEmailHint(creds.email)})',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!demoAccountSwitcherEnabled()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final User? user = _user;
    final String currentLabel = demoRoleLabelForCurrentUser(
      isFullAdmin: userJwtFullAdmin(user),
      isDa: userJwtDa(user),
    );

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.swap_horiz, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Demo · switch account',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: context.pineTextPrimary,
                  ),
                ),
                const Spacer(),
                if (_switching)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Current: $currentLabel'
              '${user?.email != null ? ' · ${demoEmailHint(user!.email!)}' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: context.pineTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to switch · long-press to set or change email/password',
              style: TextStyle(
                fontSize: 11,
                color: context.pineTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kDemoAccountPresets.map((DemoAccountPreset preset) {
                final DemoAccountCredentials? saved = _saved[preset.roleKey];
                final bool selected = demoRoleChipSelected(
                  roleKey: preset.roleKey,
                  isFullAdmin: userJwtFullAdmin(user),
                  isDa: userJwtDa(user),
                );
                return GestureDetector(
                  onLongPress: _switching
                      ? null
                      : () {
                          // ignore: discarded_futures
                          _editCredentials(preset);
                        },
                  child: InputChip(
                    label: Text(
                      saved == null
                          ? preset.label
                          : '${preset.label} · ${demoEmailHint(saved.email)}',
                    ),
                    selected: selected,
                    onSelected: _switching
                        ? null
                        : (_) {
                            // ignore: discarded_futures
                            _switchTo(preset);
                          },
                    onDeleted: saved == null
                        ? null
                        : () {
                            // ignore: discarded_futures
                            _editCredentials(preset);
                          },
                    deleteIcon: const Icon(Icons.edit_outlined, size: 16),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
