// Intro flow: splash → onboarding (3 slides) → welcome or dashboard.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import 'splash_screen.dart';
import 'onboarding_screen.dart' show OnboardingScreen, isOnboardingComplete, resetOnboardingComplete;
import 'welcome_screen.dart';
import 'main_dashboard_screen.dart';
import '../widgets/unlock_gate.dart';
import '../widgets/navigation_guide_host.dart';

enum _IntroPhase { splash, onboarding, auth }

class IntroFlowScreen extends StatefulWidget {
  const IntroFlowScreen({super.key});

  @override
  State<IntroFlowScreen> createState() => _IntroFlowScreenState();
}

class _IntroFlowScreenState extends State<IntroFlowScreen> {
  _IntroPhase _phase = _IntroPhase.splash;

  @override
  void initState() {
    super.initState();
    _runIntro();
  }

  Future<void> _runIntro() async {
    // Keep a brief splash for branding without adding heavy startup delay.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    // Re-show onboarding (starting animation) if the app wasn't opened for a while.
    // Default: 14 days. If you want a different threshold, tell me and I'll adjust it.
    const int kInactivityDays = 14;
    const String kLastOpenedAtKey = 'last_opened_at_millis';

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? lastOpenedAtMillis = prefs.getInt(kLastOpenedAtKey);
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;

    if (lastOpenedAtMillis != null) {
      final Duration diff = DateTime.fromMillisecondsSinceEpoch(nowMillis).difference(
        DateTime.fromMillisecondsSinceEpoch(lastOpenedAtMillis),
      );
      if (diff.inDays >= kInactivityDays) {
        await resetOnboardingComplete();

        // If user was still signed in, send them back to login/register.
        final SupabaseClient supabase = SupabaseClientProvider.instance.client;
        if (supabase.auth.currentUser != null) {
          await supabase.auth.signOut();
        }
      }
    }
    await prefs.setInt(kLastOpenedAtKey, nowMillis);

    final bool done = await isOnboardingComplete();
    if (!mounted) return;
    setState(() {
      _phase = done ? _IntroPhase.auth : _IntroPhase.onboarding;
    });
  }

  void _onOnboardingComplete() {
    setState(() => _phase = _IntroPhase.auth);
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _IntroPhase.splash:
        return const SplashScreen();
      case _IntroPhase.onboarding:
        return OnboardingScreen(onComplete: _onOnboardingComplete);
      case _IntroPhase.auth:
        return _AuthGate();
    }
  }
}

class _AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = SupabaseClientProvider.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final Session? session = snapshot.data?.session ?? auth.currentSession;
        final bool isSignedIn = session?.user != null;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (!isSignedIn) return const WelcomeScreen();
        final String userId = session!.user.id;
        return UnlockGate(
          isSignedIn: true,
          child: NavigationGuideHost(
            key: ValueKey<String>(userId),
            child: const MainDashboardScreen(),
          ),
        );
      },
    );
  }
}
