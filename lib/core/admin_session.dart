library;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

/// True when Auth [app_metadata] marks this user as full admin (JWT claim).
bool userJwtFullAdmin(User? user) {
  if (user == null) return false;
  final dynamic v = user.appMetadata['admin'];
  if (v is bool) return v;
  if (v is String) {
    final String s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  if (v is num) return v != 0;
  return false;
}

/// True when Auth [app_metadata] marks this user as DA / OMAG staff (not full admin).
bool userJwtDa(User? user) {
  if (user == null) return false;
  if (userJwtFullAdmin(user)) return false;
  final dynamic v = user.appMetadata['da'];
  if (v is bool) return v;
  if (v is String) {
    final String s = v.trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }
  if (v is num) return v != 0;
  final dynamic role = user.appMetadata['role'];
  if (role is String && role.trim().toLowerCase() == 'da') return true;
  return false;
}

/// Org-wide staff: full admin or DA (read all farms + write expert advice).
bool userJwtStaff(User? user) => userJwtFullAdmin(user) || userJwtDa(user);

/// Back-compat alias for full admin checks.
bool userJwtAdmin(User? user) => userJwtFullAdmin(user);

bool currentUserJwtFullAdmin() =>
    userJwtFullAdmin(SupabaseClientProvider.instance.client.auth.currentUser);

bool currentUserJwtDa() =>
    userJwtDa(SupabaseClientProvider.instance.client.auth.currentUser);

bool currentUserJwtStaff() =>
    userJwtStaff(SupabaseClientProvider.instance.client.auth.currentUser);

bool currentUserJwtAdmin() => currentUserJwtFullAdmin();

/// Short label for a Supabase user id (e.g. field list / map sheet).
String shortAppUserIdLabel(String userId) {
  final String t = userId.trim();
  if (t.length <= 10) return t;
  return '${t.substring(0, 8)}…';
}

String _profilePrimaryLabelFromRow(Map<String, dynamic> row) {
  final String id = (row['id'] as String?)?.trim() ?? '';
  final String? dn = (row['display_name'] as String?)?.trim();
  if (dn != null && dn.isNotEmpty) return dn;
  final String? em = (row['email'] as String?)?.trim();
  if (em != null && em.isNotEmpty) return em;
  return shortAppUserIdLabel(id);
}

/// Loads [profiles.display_name] / [profiles.email] for admin owner lines.
///
/// Requires admin JWT RLS (or own rows only). Every [userId] appears in the
/// result; missing profile rows fall back to [shortAppUserIdLabel].
Future<Map<String, String>> fetchProfileOwnerLabelsForUserIds(
  Iterable<String> userIds,
) async {
  final List<String> ids = userIds
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toSet()
      .toList();
  if (ids.isEmpty) return <String, String>{};

  final Map<String, String> out = <String, String>{
    for (final String id in ids) id: shortAppUserIdLabel(id),
  };

  final SupabaseClient client = SupabaseClientProvider.instance.client;
  const int chunk = 80;
  for (int i = 0; i < ids.length; i += chunk) {
    final int end = i + chunk > ids.length ? ids.length : i + chunk;
    final List<String> slice = ids.sublist(i, end);
    try {
      final Object raw = await client
          .from('profiles')
          .select('id, display_name, email')
          .inFilter('id', slice);
      if (raw is! List<dynamic>) continue;
      for (final Object? e in raw) {
        if (e is! Map) continue;
        final Map<String, dynamic> row = Map<String, dynamic>.from(e);
        final String? id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        out[id] = _profilePrimaryLabelFromRow(row);
      }
    } catch (_) {
      // Keep [shortAppUserIdLabel] fallbacks from [out] initialization.
    }
  }
  return out;
}

/// Resolved label for a field owner (after [fetchProfileOwnerLabelsForUserIds]).
String ownerDisplayLabel(String userId, Map<String, String> labels) =>
    labels[userId] ?? shortAppUserIdLabel(userId);

/// Distinct [fields.user_id] values for profile label batch fetch.
List<String> fieldRowOwnerIdsForProfileFetch(
  Iterable<Map<String, dynamic>> fieldRows,
) {
  final Set<String> ids = <String>{};
  for (final Map<String, dynamic> r in fieldRows) {
    final String? u = r['user_id'] as String?;
    if (u != null && u.trim().isNotEmpty) {
      ids.add(u.trim());
    }
  }
  final List<String> out = ids.toList()..sort();
  return out;
}

/// Realtime [fields] stream: own rows, or all rows allowed by RLS when admin.
dynamic fieldsRealtimeStreamOrderedByName({bool ascending = true}) {
  final SupabaseClient client = SupabaseClientProvider.instance.client;
  final String? uid = client.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('fieldsRealtimeStreamOrderedByName requires sign-in');
  }
  dynamic q = client.from('fields').stream(primaryKey: const <String>['id']);
  if (!userJwtStaff(client.auth.currentUser)) {
    q = q.eq('user_id', uid);
  }
  return q.order('name', ascending: ascending);
}

/// Realtime [fields] stream without ordering (caller may chain [.order] if needed).
dynamic fieldsRealtimeStream() {
  final SupabaseClient client = SupabaseClientProvider.instance.client;
  final String? uid = client.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('fieldsRealtimeStream requires sign-in');
  }
  dynamic q = client.from('fields').stream(primaryKey: const <String>['id']);
  if (!userJwtStaff(client.auth.currentUser)) {
    q = q.eq('user_id', uid);
  }
  return q;
}

/// Fetches [fields] rows for the signed-in user, or all visible rows when admin.
Future<List<Map<String, dynamic>>> fieldsSelectForSession() async {
  final SupabaseClient client = SupabaseClientProvider.instance.client;
  final String? uid = client.auth.currentUser?.id;
  if (uid == null) return const <Map<String, dynamic>>[];
  dynamic q = client.from('fields').select();
  if (!userJwtStaff(client.auth.currentUser)) {
    q = q.eq('user_id', uid);
  }
  final Object? raw = await q;
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .map((dynamic e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// [fields.boundary_json] for [fieldId], scoped by [user_id] unless admin.
Future<Map<String, dynamic>?> fieldRowBoundaryById({
  required String fieldId,
  required String uid,
}) async {
  final SupabaseClient client = SupabaseClientProvider.instance.client;
  dynamic q = client
      .from('fields')
      .select('boundary_json')
      .eq('id', fieldId);
  if (!userJwtStaff(client.auth.currentUser)) {
    q = q.eq('user_id', uid);
  }
  final Object? res = await q.maybeSingle();
  if (res is! Map) return null;
  return Map<String, dynamic>.from(res);
}

/// [detections] realtime stream for Diagnose tab: own rows or org-wide for admin.
dynamic detectionsRealtimeStream() {
  final SupabaseClient client = SupabaseClientProvider.instance.client;
  final String? uid = client.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('detectionsRealtimeStream requires sign-in');
  }
  dynamic q =
      client.from('detections').stream(primaryKey: const <String>['id']);
  if (!userJwtStaff(client.auth.currentUser)) {
    q = q.eq('user_id', uid);
  }
  return q;
}
