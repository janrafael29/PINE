// Privacy Policy screen for Pine-Sight / PINE app.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_scaffold.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key, this.showAcceptButton = true});

  final bool showAcceptButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Privacy Policy',
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Privacy Policy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'At Pine-Sight, we respect your privacy and are committed to protecting your personal information. This policy covers how we collect, use, store, and protect information when you use the Pine-Sight application. By using the service, you agree to this policy; if you do not agree, please do not use the service.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    '1. Information We Collect',
                    '• Personal Information: name, email, phone number\n'
                        '• Usage Data: IP address, device info, usage patterns\n'
                        '• Cookies: small files stored on your device',
                  ),
                  _buildSection(
                    context,
                    '2. How We Use Your Information',
                    '• Provide and improve the Service\n'
                        '• Communication: updates and notifications\n'
                        '• Analytics: analyze usage trends',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: showAcceptButton
                        ? ElevatedButton(
                            onPressed: () async {
                              final SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('privacy_accepted', true);
                              if (!context.mounted) return;
                              Navigator.pop(context, true);
                            },
                            child: const Text('Accept & Continue'),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
