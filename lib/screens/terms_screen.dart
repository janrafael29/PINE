// Terms of Use screen for Pine-Sight / PINE app.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_scaffold.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key, this.showAcceptButton = true});

  final bool showAcceptButton;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Terms of Use',
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
                    'Terms of Use',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By accessing or using this website/application, you agree to be bound by the following terms and conditions (\'Terms of Use\'). If you do not agree to these Terms of Use, please do not use this site or application.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    context,
                    '1. Acceptance of Terms',
                    'By accessing or using Pine-Sight (the Service), you agree to comply with and be bound by these Terms of Use. If you do not agree with any part of these terms, you must not use the Service.',
                  ),
                  _buildSection(
                    context,
                    '2. Use of Service',
                    'You agree to use the Service only for lawful purposes and in accordance with these Terms of Use. You are responsible for your content and use of the Service.',
                  ),
                  _buildSection(
                    context,
                    '3. Account Registration',
                    'You may be required to create an account. You agree to provide accurate information and maintain confidentiality of your credentials.',
                  ),
                  _buildSection(
                    context,
                    '4. Prohibited Activities',
                    'You agree not to: use the Service for illegal or unauthorized purposes; attempt to interfere with the proper working of the Service; or upload, post, or transmit harmful, offensive, or inappropriate content.',
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: showAcceptButton
                        ? ElevatedButton(
                            onPressed: () async {
                              final SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('terms_accepted', true);
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
