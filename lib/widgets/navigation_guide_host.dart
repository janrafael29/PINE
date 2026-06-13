/// Presents the navigation guide after unlock when prefs require it.
library;

import 'package:flutter/material.dart';

import '../core/navigation_guide_prefs.dart';
import '../screens/navigation_guide_preference_screen.dart';
import 'spotlight_navigation_guide_overlay.dart';

class NavigationGuideHost extends StatefulWidget {
  const NavigationGuideHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NavigationGuideHost> createState() => _NavigationGuideHostState();
}

class _NavigationGuideHostState extends State<NavigationGuideHost> {
  /// After biometric unlock the gate swaps from [DeviceUnlockScreen] to this
  /// subtree, which re-runs [initState]. Without this guard the tour would show
  /// again on every unlock even though the user only "logged in" once per app run.
  static bool _presentedGuideThisProcess = false;

  bool _spotlightVisible = false;
  bool _completedOrSkipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _maybePresentGuide();
    });
  }

  Future<void> _maybePresentGuide() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final bool show = await shouldShowNavigationGuide();
    if (!mounted || !show) return;
    if (_presentedGuideThisProcess) return;
    _presentedGuideThisProcess = true;
    setState(() => _spotlightVisible = true);
  }

  Future<void> _goToPreference() async {
    if (!mounted) return;
    _completedOrSkipped = true;
    setState(() => _spotlightVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            const NavigationGuidePreferenceScreen(),
      ),
    );
  }

  @override
  void dispose() {
    // First-login can cause a fast rebuild ("reload") of the post-login subtree.
    // If the overlay was visible but the user never finished/skipped, allow the
    // guide to present again after the rebuild.
    if (_spotlightVisible && !_completedOrSkipped) {
      _presentedGuideThisProcess = false;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        widget.child,
        if (_spotlightVisible)
          SpotlightNavigationGuideOverlay(
            onSkipToPreference: _goToPreference,
            onFinishedSteps: _goToPreference,
          ),
      ],
    );
  }
}
