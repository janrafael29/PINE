// Send feedback via email, form, or rate the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import 'feedback_form_screen.dart';

class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Feedback'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppTheme.primaryGreen.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            const SizedBox(height: 20),
            _buildFeedbackCard(
              context,
              icon: Icons.email,
              title: 'Send via Email',
              subtitle: 'p1ny4p1c@gmail.com',
              color: const Color(0xFF1A73E8),
              onTap: () => _launchEmail(context),
            ),
            const SizedBox(height: 16),
            _buildFeedbackCard(
              context,
              icon: Icons.assignment,
              title: 'Feedback Form',
              subtitle: 'Fill out our feedback form',
              color: AppTheme.primaryGreen,
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FeedbackFormScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      color: Color.lerp(color, Colors.black, 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    const String email = 'p1ny4p1c@gmail.com';
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: <String, String>{
        'subject': 'PINE App Feedback',
      },
    );
    try {
      // `canLaunchUrl` can be unreliable for `mailto:` on some platforms,
      // so we attempt launch and handle the result.
      final bool launched =
          await launchUrl(emailUri, mode: LaunchMode.externalApplication);

      if (!launched && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Email'),
            content: const Text(
              'No email app handler found. Copy this address and send your feedback:',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(const ClipboardData(text: email));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Copy Email'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Email'),
            content: Text('Error launching email app: $e'),
            actions: <Widget>[
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: email),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: const Text('Copy Email'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  
}
