// Terms and Privacy acceptance (full screen or gate before guest / auth).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key, this.gateMode = false});

  /// When true, opened from Welcome — Cancel/Accept pop with false/true.
  final bool gateMode;

  @override
  State<TermsAcceptanceScreen> createState() => _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends State<TermsAcceptanceScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadAcceptance();
  }

  Future<void> _loadAcceptance() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _termsAccepted = prefs.getBool('terms_accepted') ?? false;
      _privacyAccepted = prefs.getBool('privacy_accepted') ??
          (prefs.getBool('terms_accepted') ?? false);
    });
  }

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_accepted', true);
    await prefs.setBool('privacy_accepted', true);
    if (!mounted) return;
    if (widget.gateMode) {
      Navigator.pop(context, true);
      return;
    }
    Navigator.pop(context, true);
  }

  void _onCancel() {
    if (widget.gateMode) {
      Navigator.pop(context, false);
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color.lerp(cs.primary, AppTheme.navy, 0.3)!,
              cs.primary,
              Color.lerp(cs.primary, cs.secondary, 0.2)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const Spacer(flex: 2),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.agriculture, size: 60, color: cs.onPrimary),
                ),
                const SizedBox(height: 24),
                Column(
                  children: <Widget>[
                    Text(
                      'Welcome to',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: cs.onPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PINYA-PIC',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pest Identification on Native Environments',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onPrimary.withValues(alpha: 0.9),
                      ),
                ),
                const Spacer(),
                Card(
                  elevation: 6,
                  shadowColor: cs.shadow.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: <Widget>[
                        Text(
                          'Please accept our Terms & Privacy Policy',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              'I accept the Terms of Use',
                              style: TextStyle(color: cs.onSurface),
                            ),
                            value: _termsAccepted,
                            onChanged: (bool? value) {
                              setState(() => _termsAccepted = value ?? false);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: cs.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CheckboxListTile(
                            title: Text(
                              'I accept the Privacy Policy',
                              style: TextStyle(color: cs.onSurface),
                            ),
                            value: _privacyAccepted,
                            onChanged: (bool? value) {
                              setState(() => _privacyAccepted = value ?? false);
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: cs.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            TextButton(
                              onPressed: () async {
                                final Object? acceptedRaw =
                                    await Navigator.pushNamed(context, '/terms');
                                if (!mounted) return;
                                if (acceptedRaw == true) {
                                  setState(() => _termsAccepted = true);
                                }
                              },
                              child: const Text('View Terms'),
                            ),
                            const Text(' | '),
                            TextButton(
                              onPressed: () async {
                                final Object? acceptedRaw =
                                    await Navigator.pushNamed(context, '/privacy');
                                if (!mounted) return;
                                if (acceptedRaw == true) {
                                  setState(() => _privacyAccepted = true);
                                }
                              },
                              child: const Text('View Privacy'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _onCancel,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.gateMode
                                      ? cs.onSurface
                                      : cs.error,
                                  side: BorderSide(
                                    color: widget.gateMode
                                        ? cs.outline
                                        : cs.error,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  widget.gateMode ? 'Cancel' : 'Deny & Exit',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _termsAccepted && _privacyAccepted
                                    ? _saveAndContinue
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Accept & Continue'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
