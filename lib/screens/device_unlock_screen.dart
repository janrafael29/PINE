/// Device unlock screen (biometric or device PIN) shown when a session exists.
library;

import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../widgets/app_scaffold.dart';
import '../services/biometric_service.dart';

class DeviceUnlockScreen extends StatefulWidget {
  const DeviceUnlockScreen({
    super.key,
    required this.onUnlocked,
  });

  final VoidCallback onUnlocked;

  @override
  State<DeviceUnlockScreen> createState() => _DeviceUnlockScreenState();
}

class _DeviceUnlockScreenState extends State<DeviceUnlockScreen> {
  bool _busy = false;
  String? _error;
  bool _autoPromptAttempted = false;

  @override
  void initState() {
    super.initState();
    // Wait for the first frame + brief delay so the biometric sheet opens reliably.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 520), () {
        if (!mounted || _autoPromptAttempted) return;
        _autoPromptAttempted = true;
        // ignore: discarded_futures
        _unlock(fromAutoPrompt: true);
      });
    });
  }

  Future<void> _unlock({bool fromAutoPrompt = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final BiometricService bio = ServiceLocator.instance.get<BiometricService>();
      final bool ok = await bio.authenticateWithCredentials(
        reason: 'Unlock PINYA-PIC to continue',
      );
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
        return;
      }
      if (!fromAutoPrompt) {
        setState(() => _error = 'Unlock was cancelled. Tap Unlock to try again.');
      }
    } catch (e) {
      if (!mounted) return;
      if (!fromAutoPrompt) {
        setState(() => _error = 'Could not unlock. Tap Unlock to try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Unlock',
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: <Widget>[
              // Keep the block in the upper third so biometrics sheets cover less of it.
              const SizedBox(height: 28),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_rounded,
                  size: 46,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Unlock',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use your fingerprint/face or your device PIN to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _unlock,
                  child: _busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text(
                          'Unlock',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

