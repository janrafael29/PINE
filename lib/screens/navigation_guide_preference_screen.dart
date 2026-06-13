// Shown after the on-dashboard spotlight tour to set repeat vs one-time prefs.
library;

import 'package:flutter/material.dart';

import '../core/navigation_guide_content.dart';
import '../core/navigation_guide_prefs.dart';
import '../core/theme.dart';

/// Content for “show every time” vs “once” (embedded in modal guide or full screen).
class NavigationGuidePreferencePanel extends StatelessWidget {
  const NavigationGuidePreferencePanel({super.key});

  Future<void> _chooseRepeat(BuildContext context, bool eachSession) async {
    await setNavigationGuidePreference(showEachSession: eachSession);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'How should we show this guide?',
            textAlign: TextAlign.center,
            style: (textTheme.titleLarge ?? const TextStyle()).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: hint,
              ),
              children: const <TextSpan>[
                TextSpan(
                  text: 'Choose one option. You can change your mind later in ',
                ),
                TextSpan(
                  text: 'Settings',
                  style: kNavigationGuideBodyHighlightStyle,
                ),
                TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: () => _chooseRepeat(context, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
              padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Show every time I open the app',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'The guide appears after you sign in until you turn this off.',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => _chooseRepeat(context, false),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Show only once',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Don’t show this guide automatically again. You can still open it from Settings.',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 13,
                    height: 1.35,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationGuidePreferenceScreen extends StatelessWidget {
  const NavigationGuidePreferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App guide'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: const SingleChildScrollView(
        child: NavigationGuidePreferencePanel(),
      ),
    );
  }
}
