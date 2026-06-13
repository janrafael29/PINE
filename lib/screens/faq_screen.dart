// Frequently asked questions with expandable answers.
library;

import 'package:flutter/material.dart';

import '../widgets/app_scaffold.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const List<Map<String, String>> _faqs = <Map<String, String>>[
    <String, String>{
      'question': 'How do I create an account?',
      'answer':
          'To create an account, open Sign-Up, enter your email and password (and confirm the password), then agree to the terms. If email confirmation is enabled for your project, check your inbox to verify before signing in.',
    },
    <String, String>{
      'question': 'How can I diagnose plant diseases?',
      'answer':
          'Use the "Diagnose" feature on the app\'s main navigation bar. You can either take a photo of your plant or upload an existing one for analysis. The app will process the image and provide insights, specifically detecting Mealybug Wilt Disease in pineapples.',
    },
    <String, String>{
      'question': 'Can I track multiple fields?',
      'answer':
          'Yes, the "My Fields" feature allows you to manage multiple fields. You can add fields and track data like crop health and survey history for each field.',
    },
    <String, String>{
      'question': 'What sign-in methods are supported?',
      'answer':
          'PINE supports email and password sign-in only. Sign in on the Login page with your registered email and password.',
    },
    <String, String>{
      'question': 'What do I do if I forget my password?',
      'answer':
          'On the Login page, tap "Forgot password?", enter the same email you used to register, then tap "Send reset link". Open the email on your device and follow the link to set a new password.',
    },
    <String, String>{
      'question': 'How do I change the language of the app?',
      'answer':
          'Go to the "Settings" page and select "Language." Choose your preferred language from the list, and the app will update accordingly.',
    },
    <String, String>{
      'question': 'What kind of diseases can this app detect?',
      'answer':
          'Currently, the app specializes in detecting only one disease: Mealybug Wilt Disease in pineapples. Additional disease detection may be introduced in future updates.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      titleWidget: const Text(
        'FAQ – Frequently Asked Questions',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.maybePop(context),
        ),
      ],
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _faqs.length,
        itemBuilder: (BuildContext context, int index) {
          return _buildFaqItem(context, _faqs[index]);
        },
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, Map<String, String> faq) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          faq['question']!,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              faq['answer']!,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
