// Blocks the dashboard until staff finish verification after registering as staff.
library;

import 'package:flutter/material.dart';

import '../core/account_intent.dart';
import '../screens/staff_onboarding_screen.dart';

class PostAuthGate extends StatefulWidget {
  const PostAuthGate({super.key, required this.child});

  final Widget child;

  @override
  State<PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<PostAuthGate> {
  final AccountIntentService _service = AccountIntentService();
  PostAuthStep _step = PostAuthStep.loading;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _step = PostAuthStep.loading);
    try {
      final PostAuthStep next = await _service.resolvePostAuthStep();
      if (!mounted) return;
      setState(() => _step = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _step = PostAuthStep.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case PostAuthStep.loading:
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: const Center(child: CircularProgressIndicator()),
        );
      case PostAuthStep.staffOnboarding:
        return StaffOnboardingScreen(onComplete: _refresh);
      case PostAuthStep.dashboard:
        return widget.child;
    }
  }
}
