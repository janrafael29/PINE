/// Full-screen handoff for demo account switching.
///
/// Auth runs only after the dashboard route is removed so sign-out does not
/// dispose [MainDashboardScreen] while its dependents are still active.
library;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/cloud_sync_service.dart';
import '../services/supabase_profile_service.dart';
import '../core/security_prefs.dart';

class DemoAccountSwitchArgs {
  const DemoAccountSwitchArgs({
    required this.email,
    required this.password,
    required this.label,
  });

  final String email;
  final String password;
  final String label;
}

class DemoAccountSwitchScreen extends StatefulWidget {
  const DemoAccountSwitchScreen({super.key, required this.args});

  final DemoAccountSwitchArgs args;

  @override
  State<DemoAccountSwitchScreen> createState() => _DemoAccountSwitchScreenState();
}

class _DemoAccountSwitchScreenState extends State<DemoAccountSwitchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _runSwitch();
    });
  }

  Future<void> _runSwitch() async {
    final DemoAccountSwitchArgs args = widget.args;
    final SupabaseClient client = SupabaseClientProvider.instance.client;
    String? errorMessage;
    try {
      await client.auth.signOut();
      await client.auth.signInWithPassword(
        email: args.email,
        password: args.password,
      );
      await SecurityPrefs.markSuccessfulLogin();
      await SupabaseProfileService().upsertCurrentUserProfile();
      // ignore: discarded_futures
      CapturedPhotosRemoteSync().pullIntoLocalIfSignedIn();
      // ignore: discarded_futures
      CloudSyncService().syncInBackground();
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!mounted) return;
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    await navigator.pushNamedAndRemoveUntil('/', (_) => false);

    if (errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext rootContext = navigator.context;
        ScaffoldMessenger.maybeOf(rootContext)?.showSnackBar(
          SnackBar(
            content: Text('Switch failed: $errorMessage'),
            backgroundColor: Theme.of(rootContext).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext rootContext = navigator.context;
      ScaffoldMessenger.maybeOf(rootContext)?.showSnackBar(
        SnackBar(
          content: Text('Switched to ${args.label} (${args.email})'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Switching to ${widget.args.label}…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
