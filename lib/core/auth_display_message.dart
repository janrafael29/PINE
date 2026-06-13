// User-facing strings for Supabase Auth errors (avoids raw JSON in SnackBars).
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Parses GoTrue-style JSON in [AuthException.message] and returns readable copy.
String authErrorMessageForUser(AuthException e) {
  final String raw = e.message.trim();
  String? code;
  String text = raw;

  if (raw.startsWith('{')) {
    try {
      final dynamic j = jsonDecode(raw);
      if (j is Map<dynamic, dynamic>) {
        final Object? c = j['code'];
        if (c != null) code = c.toString();
        final Object? m = j['message'] ?? j['msg'] ?? j['error_description'];
        if (m is String && m.isNotEmpty) text = m;
      }
    } catch (_) {
      /* keep text = raw */
    }
  }

  final String lower = text.toLowerCase();
  final bool recoveryEmailFailed = code == 'unexpected_failure' ||
      lower.contains('recovery email') ||
      lower.contains('error sending');

  if (recoveryEmailFailed) {
    return 'We could not send the password reset email. Please try again in a '
        'few minutes. If it keeps failing, your project admin should check '
        'Supabase → Authentication → Emails (custom SMTP) and add the reset '
        'redirect URL (e.g. pine://reset-password) to the allowed redirect URLs.';
  }

  return text;
}
