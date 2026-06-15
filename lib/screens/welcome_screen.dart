// Welcome / onboarding screen for Pine-Sight / PINE app.
library;

import 'package:flutter/material.dart';

import '../core/supabase_client.dart';
import '../core/theme.dart';
import 'terms_screen.dart';
import 'privacy_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/scan_flow.dart';
import '../utils/terms_consent.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();

  void _onGetStarted(BuildContext context, {bool toRegister = false}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            toRegister ? const RegisterScreen() : const LoginScreen(),
      ),
    );
  }
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _afterTerms(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final bool ok = await ensureTermsAccepted(context);
    if (!ok || !context.mounted) return;
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<Color> gradientColors = <Color>[
      Color.lerp(cs.primary, AppTheme.navy, 0.35)!,
      Color.lerp(cs.primary, cs.secondary, 0.25)!,
    ];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _t,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Spacer(),
                Text(
                  'Welcome to',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w300,
                      ),
                ),
                Text(
                  'PINYA-PIC',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Identify mealybugs in pineapple plants',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onPrimary,
                        ),
                  ),
                ),
                const Spacer(flex: 2),
                OutlinedButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    _afterTerms(context, () async {
                      if (!context.mounted) return;
                      if (SupabaseClientProvider.instance.client.auth
                              .currentSession !=
                          null) {
                        await SupabaseClientProvider.instance.client.auth
                            .signOut();
                      }
                      if (!context.mounted) return;
                      await startFieldFirstScan(context, guestMode: true);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onPrimary,
                    side: BorderSide(color: cs.onPrimary, width: 2),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    'Continue as guest',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Scan only — photos are not saved',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.85),
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    _afterTerms(context, () async {
                      if (!context.mounted) return;
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.onPrimary,
                    foregroundColor: cs.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // ignore: discarded_futures
                    _afterTerms(context, () async {
                      if (!context.mounted) return;
                      widget._onGetStarted(context, toRegister: true);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.onPrimary,
                    side: BorderSide(color: cs.onPrimary, width: 2),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Sign up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final TextStyle? muted =
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onPrimary.withValues(alpha: 0.85),
                            );
                    final TextStyle? link =
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            );
                    return SizedBox(
                      width: c.maxWidth,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 6,
                        children: <Widget>[
                          Text(
                            'You must accept the Terms of Use & Privacy Policy to continue. ',
                            textAlign: TextAlign.center,
                            style: muted,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const TermsScreen(),
                                ),
                              );
                            },
                            child: Text('Terms of Use', style: link),
                          ),
                          Text(' & ', style: muted),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const PrivacyScreen(),
                                ),
                              );
                            },
                            child: Text('Privacy Policy', style: link),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        builder: (BuildContext context, Widget? child) {
          // Subtle “moving” gradient by slowly shifting the begin/end alignments.
          final double v = _t.value;
          final Alignment begin = Alignment.lerp(
                const Alignment(-0.2, -1.0),
                const Alignment(0.2, -0.6),
                v,
              ) ??
              Alignment.topCenter;
          final Alignment end = Alignment.lerp(
                const Alignment(0.2, 1.0),
                const Alignment(-0.2, 0.6),
                v,
              ) ??
              Alignment.bottomCenter;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: gradientColors,
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
