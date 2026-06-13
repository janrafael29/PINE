/// Gating widget that requires device authentication once per app launch.
library;

import 'package:flutter/material.dart';

import '../core/security_prefs.dart';
import '../screens/device_unlock_screen.dart';

class UnlockGate extends StatefulWidget {
  const UnlockGate({
    super.key,
    required this.child,
    required this.isSignedIn,
  });

  final Widget child;
  final bool isSignedIn;

  @override
  State<UnlockGate> createState() => _UnlockGateState();
}

class _UnlockGateState extends State<UnlockGate> {
  static bool _unlockedThisRun = false;

  bool _loading = true;
  bool _shouldGate = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load() async {
    final bool hasLogin = await SecurityPrefs.hasSuccessfulLogin();
    final bool requireUnlock = await SecurityPrefs.requireDeviceUnlock();

    if (!mounted) return;
    setState(() {
      _shouldGate =
          widget.isSignedIn && hasLogin && requireUnlock && !_unlockedThisRun;
      _loading = false;
    });
  }

  void _onUnlocked() {
    _unlockedThisRun = true;
    if (!mounted) return;
    setState(() {
      _shouldGate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_shouldGate) {
      return DeviceUnlockScreen(onUnlocked: _onUnlocked);
    }
    return widget.child;
  }
}

