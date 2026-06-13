// In-app feedback form (meant to submit into a Google Sheet).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/supabase_client.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/action_popup.dart';

class FeedbackFormScreen extends StatefulWidget {
  const FeedbackFormScreen({super.key});

  @override
  State<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends State<FeedbackFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  Future<void> _prefillName() async {
    // Don't overwrite if the user already started typing.
    if (_nameController.text.trim().isNotEmpty) return;

    final client = SupabaseClientProvider.instance.clientOrNull;
    if (client == null) return;

    final currentUser = client.auth.currentUser;
    if (currentUser == null) return;

    String? displayName;
    try {
      final Map<String, dynamic>? row = await client
          .from('profiles')
          .select('display_name')
          .eq('id', currentUser.id)
          .maybeSingle();
      displayName = row?['display_name'] as String?;
    } catch (_) {
      // Ignore profile fetch errors; fall back to auth data below.
    }

    final String? fallback = <String?>[
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : null,
      currentUser.phone?.trim().isNotEmpty == true
          ? currentUser.phone!.trim()
          : null,
      currentUser.email?.trim().isNotEmpty == true
          ? currentUser.email!.trim()
          : null,
    ].firstWhere((v) => v != null, orElse: () => null);

    if (fallback == null || fallback.isEmpty) return;
    if (!mounted) return;

    _nameController.text = fallback;
  }

  // Google Apps Script Web App: implement doPost(e) and JSON.parse(e.postData.contents)
  // for keys name, email, message (avoid putting feedback in URL query strings).
  static const String kGoogleSheetWebAppUrl =
      'https://script.google.com/macros/s/AKfycbxN77qNVQ41S5ldnVh8uWNxC6x8u8v2BK--xJYgQeyl4GVecooOhMVyTPK5xk-1_e8zGw/exec';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String message = _messageController.text.trim();

    if (name.isEmpty) {
      if (!mounted) return;
      await ActionPopup.showError(
        context,
        message: 'Please enter your name.',
      );
      return;
    }

    if (message.length < 5) {
      if (!mounted) return;
      await ActionPopup.showError(
        context,
        message: 'Please enter a feedback message.',
      );
      return;
    }

    if (kGoogleSheetWebAppUrl.isEmpty) {
      if (!mounted) return;
      await ActionPopup.showError(
        context,
        message:
            'Feedback endpoint not configured yet (Google Sheet URL missing).',
      );
      return;
    }

    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    final ActionPopupController popup = ActionPopupController();
    try {
      popup.showBlockingProgress(
        context,
        message: 'Submitting feedback…',
      );
      final Uri endpoint = Uri.parse(kGoogleSheetWebAppUrl);
      final http.Response res = await http
          .post(
            endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, String>{
              'name': name,
              'email': email,
              'message': message,
            }),
          )
          .timeout(const Duration(seconds: 20));
      popup.close();
      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        await ActionPopup.showSuccess(
          context,
          message: 'Submitted successfully.',
        );
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        await ActionPopup.showError(
          context,
          message: 'Submission failed (HTTP ${res.statusCode}). Please try again.',
        );
      }
    } catch (e) {
      popup.close();
      if (!mounted) return;
      await ActionPopup.showError(
        context,
        message: 'Failed to submit: $e',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Feedback Form',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _messageController,
              minLines: 6,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: Text(
                  _submitting ? 'Submitting...' : 'Submit Feedback',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

