/// Tracks which fields the user opened most recently for list ordering.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _kFieldLastOpenedJson = 'field_last_opened_millis_v1';

Future<Map<String, int>> loadFieldRecencyMillis() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String? raw = prefs.getString(_kFieldLastOpenedJson);
  if (raw == null || raw.isEmpty) return <String, int>{};
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map) return <String, int>{};
    final Map<String, int> out = <String, int>{};
    decoded.forEach((Object? key, Object? value) {
      final String id = key?.toString() ?? '';
      if (id.isEmpty) return;
      if (value is num) {
        out[id] = value.toInt();
      }
    });
    return out;
  } catch (_) {
    return <String, int>{};
  }
}

Future<void> recordFieldOpened(String fieldId) async {
  final String id = fieldId.trim();
  if (id.isEmpty) return;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final Map<String, int> map = await loadFieldRecencyMillis();
  map[id] = DateTime.now().millisecondsSinceEpoch;
  await prefs.setString(_kFieldLastOpenedJson, jsonEncode(map));
}

List<Map<String, dynamic>> sortFieldDocsByRecency(
  List<Map<String, dynamic>> docs,
  Map<String, int> recencyMillisByFieldId,
) {
  if (docs.length <= 1) return docs;
  final List<Map<String, dynamic>> sorted =
      List<Map<String, dynamic>>.from(docs);
  sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final String aId = a['id']?.toString() ?? '';
    final String bId = b['id']?.toString() ?? '';
    final int aT = recencyMillisByFieldId[aId] ?? 0;
    final int bT = recencyMillisByFieldId[bId] ?? 0;
    if (aT != bT) return bT.compareTo(aT);
    final String aName = (a['name'] as String?) ?? '';
    final String bName = (b['name'] as String?) ?? '';
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  });
  return sorted;
}

List<Map<String, dynamic>> sortFieldDisplayMapsByRecency(
  List<Map<String, dynamic>> fields,
  Map<String, int> recencyMillisByFieldId,
) {
  if (fields.length <= 1) return fields;
  final List<Map<String, dynamic>> sorted =
      List<Map<String, dynamic>>.from(fields);
  sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final String aId = a['fieldId']?.toString() ?? '';
    final String bId = b['fieldId']?.toString() ?? '';
    final int aT = recencyMillisByFieldId[aId] ?? 0;
    final int bT = recencyMillisByFieldId[bId] ?? 0;
    if (aT != bT) return bT.compareTo(aT);
    final String aName = (a['name'] as String?) ?? '';
    final String bName = (b['name'] as String?) ?? '';
    return aName.toLowerCase().compareTo(bName.toLowerCase());
  });
  return sorted;
}
