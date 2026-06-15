/// Tracks whether the user has seen their latest DA access request outcome.
library;

import 'package:shared_preferences/shared_preferences.dart';

const String _seenStatusKey = 'da_request_seen_status';
const String _seenAtKey = 'da_request_seen_at';

Future<void> markDaRequestStatusSeen({
  required String status,
  String? reviewedAt,
}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(_seenStatusKey, status.trim().toLowerCase());
  await prefs.setString(_seenAtKey, (reviewedAt ?? '').trim());
}

Future<bool> isDaRequestStatusUnseen({
  required String? status,
  String? reviewedAt,
}) async {
  final String normalized = (status ?? '').trim().toLowerCase();
  if (normalized != 'approved' && normalized != 'rejected') {
    return false;
  }
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String seenStatus = (prefs.getString(_seenStatusKey) ?? '').trim();
  final String seenAt = (prefs.getString(_seenAtKey) ?? '').trim();
  final String currentAt = (reviewedAt ?? '').trim();
  if (seenStatus != normalized) return true;
  if (currentAt.isNotEmpty && currentAt != seenAt) return true;
  return false;
}
