/// Pending registration metadata when email confirmation delays sign-in.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'account_intent.dart';

const String _pendingKey = 'pending_registration_setup_v2';

class PendingRegistrationSetup {
  const PendingRegistrationSetup({
    required this.email,
    required this.intent,
    this.fullName,
    this.organization,
    this.companyLocation,
    this.position,
    this.note,
  });

  final String email;
  final AccountIntent intent;
  final String? fullName;
  final String? organization;
  final String? companyLocation;
  final String? position;
  final String? note;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'intent': intent.name,
        if (fullName != null) 'full_name': fullName,
        if (organization != null) 'organization': organization,
        if (companyLocation != null) 'company_location': companyLocation,
        if (position != null) 'position': position,
        if (note != null) 'note': note,
      };

  factory PendingRegistrationSetup.fromJson(Map<String, dynamic> json) {
    return PendingRegistrationSetup(
      email: (json['email'] as String?)?.trim() ?? '',
      intent: AccountIntentService.parse(json['intent'] as String?) ??
          AccountIntent.farmer,
      fullName: (json['full_name'] as String?)?.trim(),
      organization: (json['organization'] as String?)?.trim(),
      companyLocation: (json['company_location'] as String?)?.trim(),
      position: (json['position'] as String?)?.trim(),
      note: (json['note'] as String?)?.trim(),
    );
  }
}

Future<void> savePendingRegistrationSetup(
  PendingRegistrationSetup pending,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingKey, jsonEncode(pending.toJson()));
}

Future<PendingRegistrationSetup?> consumePendingRegistrationSetup(
  String email,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? raw = prefs.getString(_pendingKey);
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final PendingRegistrationSetup pending = PendingRegistrationSetup.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (pending.email.trim().toLowerCase() !=
        email.trim().toLowerCase()) {
      return null;
    }
    await prefs.remove(_pendingKey);
    return pending;
  } catch (_) {
    return null;
  }
}

Future<void> clearPendingRegistrationSetup() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.remove(_pendingKey);
}
