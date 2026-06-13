// Terms / privacy consent helpers (required before guest, login, or sign-up).
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/terms_acceptance_screen.dart';

Future<bool> hasTermsAndPrivacyAccepted() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool termsAccepted = prefs.getBool('terms_accepted') ?? false;
  final bool privacyAccepted =
      prefs.getBool('privacy_accepted') ?? termsAccepted;
  return termsAccepted && privacyAccepted;
}

/// If terms are already accepted, returns true. Otherwise shows the acceptance
/// screen and returns whether the user agreed.
Future<bool> ensureTermsAccepted(BuildContext context) async {
  if (await hasTermsAndPrivacyAccepted()) return true;
  if (!context.mounted) return false;
  final bool? accepted = await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => const TermsAcceptanceScreen(gateMode: true),
    ),
  );
  return accepted == true;
}
