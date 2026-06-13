/// Normalize user-entered phone numbers to E.164 for Supabase Auth (e.g. +63...).
library;

/// Best-effort PH-focused normalization. User can also paste full E.164 (+...).
String normalizeToE164(String raw) {
  String s = raw.trim().replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) return s;
  if (s.startsWith('+')) {
    return s.replaceAll(RegExp(r'[^+0-9]'), '');
  }
  // Strip leading 00
  if (s.startsWith('00')) s = s.substring(2);
  // PH mobile: 09xxxxxxxx -> +639xxxxxxxx
  if (s.startsWith('0') && s.length >= 10) {
    return '+63${s.substring(1)}';
  }
  if (s.startsWith('63') && s.length >= 11) {
    return '+$s';
  }
  if (s.startsWith('9') && s.length == 10) {
    return '+63$s';
  }
  // Fallback: assume already country code without +
  if (RegExp(r'^\d{10,15}$').hasMatch(s)) {
    return '+$s';
  }
  return s;
}

bool looksLikeE164(String phone) {
  return RegExp(r'^\+\d{10,15}$').hasMatch(phone);
}
