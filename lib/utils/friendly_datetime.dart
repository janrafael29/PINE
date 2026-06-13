library;

import 'package:intl/intl.dart';

/// Friendly timestamp format used across the app UI.
///
/// Example: `Mar, 09, 2026 / 10:09 AM`
final DateFormat _kFriendlyDt = DateFormat('MMM, dd, yyyy / hh:mm a');

String formatFriendlyDateTime(DateTime dt) {
  return _kFriendlyDt.format(dt.toLocal());
}

/// Best-effort parse + format for ISO8601 timestamps stored in DB/Supabase.
/// Returns the original string if parsing fails.
String formatFriendlyIso(String iso) {
  final DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return formatFriendlyDateTime(dt);
}

