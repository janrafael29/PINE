/// Tracks which expert replies a farmer has already been notified about.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_client.dart';

const String _seenMapKeyPrefix = 'expert_reply_seen_map';

Future<String> _prefsKeyForCurrentUser() async {
  final String? uid =
      SupabaseClientProvider.instance.client.auth.currentUser?.id;
  final String trimmed = uid?.trim() ?? '';
  if (trimmed.isEmpty) return _seenMapKeyPrefix;
  return '${_seenMapKeyPrefix}_$trimmed';
}

Future<Map<String, String>> _readSeenMap() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = await _prefsKeyForCurrentUser();
  final String raw = (prefs.getString(key) ?? '').trim();
  if (raw.isEmpty) return <String, String>{};
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, String>{};
    return decoded.map(
      (dynamic k, dynamic v) => MapEntry<String, String>(
        k.toString(),
        (v ?? '').toString(),
      ),
    );
  } catch (_) {
    return <String, String>{};
  }
}

Future<void> _writeSeenMap(Map<String, String> map) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = await _prefsKeyForCurrentUser();
  await prefs.setString(key, jsonEncode(map));
}

Future<void> markExpertReplySeen({
  required String detectionId,
  String? updatedAt,
}) async {
  final String id = detectionId.trim();
  if (id.isEmpty) return;
  final Map<String, String> map = await _readSeenMap();
  final String at = (updatedAt ?? '').trim();
  map[id] = at.isEmpty ? '*' : at;
  await _writeSeenMap(map);
}

Future<bool> isExpertReplyUnseen({
  required String detectionId,
  String? updatedAt,
}) async {
  final String id = detectionId.trim();
  if (id.isEmpty) return false;
  final Map<String, String> map = await _readSeenMap();
  if (!map.containsKey(id)) return true;
  final String seenAt = (map[id] ?? '').trim();
  final String currentAt = (updatedAt ?? '').trim();
  if (currentAt.isNotEmpty && seenAt != currentAt) return true;
  return false;
}
