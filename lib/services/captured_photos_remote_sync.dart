library;

import 'dart:convert';

import '../core/admin_session.dart';
import '../core/app_logger.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import 'database_service.dart';

/// Pulls detection rows from Supabase into local [captured_photo] so the gallery
/// survives reinstall when the user signs in with the same account.
class CapturedPhotosRemoteSync {
  CapturedPhotosRemoteSync({DatabaseService? databaseService})
      : _db = databaseService ?? DatabaseService();

  final DatabaseService _db;

  /// Fetches remote detections and inserts any missing rows. Idempotent.
  Future<int> pullIntoLocalIfSignedIn({int limit = 500}) async {
    await _db.initialize();
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return 0;
    if (!await NetworkReachability.isOnline()) return 0;

    try {
      final bool jwtStaff = currentUserJwtStaff();
      dynamic detQuery = SupabaseClientProvider.instance.client
          .from('detections')
          .select(
            'id, user_id, image_url, confidence, count, field_id, latitude, longitude, created_at, detections_json, has_mealybugs',
          );
      if (!jwtStaff) {
        detQuery = detQuery.eq('user_id', uid);
      }
      final List<Map<String, dynamic>> remote = List<Map<String, dynamic>>.from(
        await detQuery.order('created_at', ascending: false).limit(limit),
      );

      final List<Map<String, dynamic>> fieldRows;
      if (jwtStaff) {
        fieldRows = await fieldsSelectForSession();
      } else {
        fieldRows = List<Map<String, dynamic>>.from(
          await SupabaseClientProvider.instance.client
              .from('fields')
              .select('id, name')
              .eq('user_id', uid),
        );
      }

      final Map<String, String> fieldNames = <String, String>{};
      for (final Map<String, dynamic> f in fieldRows) {
        final String? id = f['id']?.toString();
        final String? name = f['name'] as String?;
        if (id != null && id.isNotEmpty) {
          fieldNames[id] = name ?? 'Field';
        }
      }

      int inserted = 0;
      for (final Map<String, dynamic> d in remote) {
        final bool added = await _insertDetectionRowIfMissing(
          d: d,
          uid: uid,
          fieldNames: fieldNames,
        );
        if (added) inserted++;
      }
      return inserted;
    } catch (e, st) {
      AppLogger.error('CapturedPhotosRemoteSync.pull failed', e, st);
      return 0;
    }
  }

  /// Farmer-safe fetch of one detection row (RLS + user_id filter).
  Future<Map<String, dynamic>?> fetchDetectionForCurrentUser(
    String detectionId,
  ) async {
    return _fetchDetectionById(
      detectionId,
      farmerOnly: !currentUserJwtStaff(),
    );
  }

  Future<Map<String, dynamic>?> _fetchDetectionById(
    String detectionId, {
    required bool farmerOnly,
  }) async {
    final String id = detectionId.trim();
    if (id.isEmpty) return null;
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return null;
    if (!await NetworkReachability.isOnline()) return null;
    try {
      dynamic query = SupabaseClientProvider.instance.client
          .from('detections')
          .select(
            'id, user_id, image_url, confidence, count, field_id, latitude, longitude, created_at, detections_json, has_mealybugs',
          )
          .eq('id', id);
      if (farmerOnly) {
        query = query.eq('user_id', uid);
      }
      final Object? raw = await query.maybeSingle();
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  /// Ensures a local gallery row exists for [detectionId]. Returns SQLite id.
  Future<int?> ensureLocalCaptureForDetection(String detectionId) async {
    await _db.initialize();
    final String id = detectionId.trim();
    if (id.isEmpty) return null;

    final Map<String, dynamic>? existing =
        await _db.getCapturedPhotoByRemoteId(id);
    if (existing != null) {
      return (existing['id'] as num?)?.toInt();
    }

    if (!await NetworkReachability.isOnline()) return null;

    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return null;

    final Map<String, dynamic>? det = await _fetchDetectionById(
      id,
      farmerOnly: !currentUserJwtStaff(),
    );
    if (det == null) return null;

    final Map<String, String> fieldNames = currentUserJwtStaff()
        ? await _fieldNamesForStaff()
        : await _fieldNamesForUser(uid);
    final bool added = await _insertDetectionRowIfMissing(
      d: det,
      uid: uid,
      fieldNames: fieldNames,
    );
    if (!added) {
      final Map<String, dynamic>? again = await _db.getCapturedPhotoByRemoteId(id);
      return (again?['id'] as num?)?.toInt();
    }
    final Map<String, dynamic>? created =
        await _db.getCapturedPhotoByRemoteId(id);
    return (created?['id'] as num?)?.toInt();
  }

  Future<Map<String, String>> _fieldNamesForStaff() async {
    try {
      final List<Map<String, dynamic>> fieldRows =
          await fieldsSelectForSession();
      final Map<String, String> fieldNames = <String, String>{};
      for (final Map<String, dynamic> f in fieldRows) {
        final String? fid = f['id']?.toString();
        final String? name = f['name'] as String?;
        if (fid != null && fid.isNotEmpty) {
          fieldNames[fid] = name ?? 'Field';
        }
      }
      return fieldNames;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<Map<String, String>> _fieldNamesForUser(String uid) async {
    try {
      final List<Map<String, dynamic>> fieldRows =
          List<Map<String, dynamic>>.from(
        await SupabaseClientProvider.instance.client
            .from('fields')
            .select('id, name')
            .eq('user_id', uid),
      );
      final Map<String, String> fieldNames = <String, String>{};
      for (final Map<String, dynamic> f in fieldRows) {
        final String? fid = f['id']?.toString();
        final String? name = f['name'] as String?;
        if (fid != null && fid.isNotEmpty) {
          fieldNames[fid] = name ?? 'Field';
        }
      }
      return fieldNames;
    } catch (_) {
      return const <String, String>{};
    }
  }

  Future<bool> _insertDetectionRowIfMissing({
    required Map<String, dynamic> d,
    required String uid,
    required Map<String, String> fieldNames,
  }) async {
    final String? rid = d['id']?.toString();
    final String? url = d['image_url'] as String?;
    if (rid == null || rid.isEmpty || url == null || url.isEmpty) {
      return false;
    }
    if (await _db.hasCapturedPhotoForRemoteIdGlobal(rid)) return false;
    if (await _db.hasCapturedPhotoForRemoteImageUrlGlobal(url)) return false;

    final String? ownerId = (d['user_id'] as String?)?.trim();
    final String rowUserId =
        (ownerId != null && ownerId.isNotEmpty) ? ownerId : uid;

    final String? fieldId = d['field_id'] as String?;
    final String fieldName = fieldId != null && fieldNames.containsKey(fieldId)
        ? fieldNames[fieldId]!
        : 'Field';

    final double? lat =
        d['latitude'] == null ? null : (d['latitude'] as num).toDouble();
    final double? lng =
        d['longitude'] == null ? null : (d['longitude'] as num).toDouble();

    final int conf = _remoteConfidenceToPercent(d['confidence'] as num?);
    final int cnt = (d['count'] as num?)?.toInt() ?? 0;
    final DateTime created =
        DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now();

    final dynamic rawDj = d['detections_json'];
    String? djStr;
    if (rawDj != null) {
      djStr = rawDj is String ? rawDj : jsonEncode(rawDj);
    }

    await _db.insertCapturedPhotoFromRemote(
      userId: rowUserId,
      remoteId: rid,
      remoteImageUrl: url,
      fieldName: fieldName,
      confidence: conf,
      count: cnt,
      fieldId: fieldId,
      latitude: lat,
      longitude: lng,
      createdAt: created,
      detectionsJson: djStr,
    );
    return true;
  }

  /// Supabase may store confidence as 0–100 (app uploads) or 0–1 (older rows).
  static int _remoteConfidenceToPercent(num? raw) {
    if (raw == null) return 0;
    final double v = raw.toDouble();
    final double pct = v <= 1.0 ? v * 100.0 : v;
    return pct.round().clamp(0, 100);
  }
}
