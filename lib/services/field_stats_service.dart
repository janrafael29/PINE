/// Unified field image counts and preview resolution (dashboard + detail).
library;

import '../core/admin_session.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import 'captured_photos_remote_sync.dart';
import 'database_service.dart';
import 'supabase_detection_field_counts.dart';

/// Stats shown on [FieldDetailScreen] and merged into My Fields cards.
class FieldImageStats {
  const FieldImageStats({
    required this.imageCount,
    this.lastUpdated,
    this.previewPath,
  });

  final int imageCount;
  final DateTime? lastUpdated;
  final String? previewPath;
}

DateTime? _maxDateTime(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Same merge as My Fields grid: for farmers, local [captured_photo] rows are the count shown.
Future<List<Map<String, dynamic>>> mergeFieldDocsWithLocalCaptureCounts({
  required DatabaseService db,
  required String userId,
  required List<Map<String, dynamic>> fieldRows,
  bool applyLocalCaptureCounts = true,
}) async {
  if (fieldRows.isEmpty) return fieldRows;

  List<Map<String, dynamic>> working = fieldRows;
  if (applyLocalCaptureCounts) {
    await db.initialize();
    final Map<String, int> localByField =
        await db.countCapturedPhotosGroupedByFieldId(userId: userId);
    working = fieldRows.map((Map<String, dynamic> data) {
      final String id = (data['id'] as String?) ?? '';
      final int local = localByField[id] ?? 0;
      final Map<String, dynamic> copy = Map<String, dynamic>.from(data);
      copy['image_count'] = local;
      return copy;
    }).toList();
    return enrichFieldRowsWithPreviewFallback(db: db, fieldRows: working);
  }

  if (!await NetworkReachability.isOnline()) {
    return enrichFieldRowsWithPreviewFallback(db: db, fieldRows: working);
  }
  try {
    final SupabaseFieldDetectionAggregates agg =
        await fetchSupabaseFieldDetectionAggregatesByFieldId();
    final List<Map<String, dynamic>> withCounts = working.map((Map<String, dynamic> data) {
      final String id = (data['id'] as String?) ?? '';
      final int cur = (data['image_count'] as num?)?.toInt() ?? 0;
      final int remoteImages = agg.imagesByField[id] ?? 0;
      if (remoteImages <= cur) return data;
      final Map<String, dynamic> copy = Map<String, dynamic>.from(data);
      copy['image_count'] = remoteImages;
      return copy;
    }).toList();
    return enrichFieldRowsWithPreviewFallback(db: db, fieldRows: withCounts);
  } catch (_) {
    return enrichFieldRowsWithPreviewFallback(db: db, fieldRows: working);
  }
}

/// Fills empty [preview_image_path] from latest local capture or remote detection thumb.
Future<List<Map<String, dynamic>>> enrichFieldRowsWithPreviewFallback({
  required DatabaseService db,
  required List<Map<String, dynamic>> fieldRows,
}) async {
  if (fieldRows.isEmpty) return fieldRows;
  await db.initialize();

  final List<String> needPreview = <String>[];
  for (final Map<String, dynamic> row in fieldRows) {
    final String? p = row['preview_image_path'] as String?;
    if (p != null && p.trim().isNotEmpty) continue;
    final String id = (row['id'] as String?) ?? '';
    if (id.isNotEmpty) needPreview.add(id);
  }
  if (needPreview.isEmpty) return fieldRows;

  final Map<String, String> local =
      await db.latestCapturePreviewPathByFieldIds(needPreview);

  Map<String, String> remote = const <String, String>{};
  if (await NetworkReachability.isOnline()) {
    try {
      remote = await fetchLatestDetectionImageUrlByFieldIds(needPreview);
    } catch (_) {}
  }

  return fieldRows.map((Map<String, dynamic> row) {
    final String? existing = row['preview_image_path'] as String?;
    if (existing != null && existing.trim().isNotEmpty) return row;
    final String id = (row['id'] as String?) ?? '';
    final String? path = local[id] ?? remote[id];
    if (path == null || path.trim().isEmpty) return row;
    final Map<String, dynamic> copy = Map<String, dynamic>.from(row);
    copy['preview_image_path'] = path.trim();
    return copy;
  }).toList();
}

/// Loads image count / last updated / preview for one field (detail screen).
Future<FieldImageStats> loadFieldImageStats({
  required String fieldId,
  required String? viewerUserId,
}) async {
  final DatabaseService db = DatabaseService();
  await db.initialize();

  final bool jwtStaff = currentUserJwtStaff();
  final bool countLocal = viewerUserId != null && !jwtStaff;

  int imageCount = 0;
  DateTime? lastUpdated;
  String? previewPath;

  if (countLocal) {
    if (await NetworkReachability.isOnline()) {
      try {
        await CapturedPhotosRemoteSync(databaseService: db)
            .pullIntoLocalIfSignedIn(limit: 500);
      } catch (_) {}
    }
    final ({int count, DateTime? latest}) local =
        await db.getCapturedPhotoStatsForField(
      fieldId: fieldId,
      userId: viewerUserId,
    );
    imageCount = local.count;
    lastUpdated = local.latest;

    final List<Map<String, dynamic>> latestRows =
        await db.getCapturedPhotosForField(
      fieldId: fieldId,
      limit: 1,
      userId: viewerUserId,
    );
    if (latestRows.isNotEmpty) {
      previewPath = _previewFromCaptureRow(latestRows.first);
    }
  } else {
    final Map<String, dynamic>? cached =
        await db.getCachedFieldByIdOnly(fieldId: fieldId);
    if (cached != null) {
      imageCount = (cached['image_count'] as num?)?.toInt() ?? 0;
      final String? cachedPreview = cached['preview_image_path'] as String?;
      if (cachedPreview != null && cachedPreview.trim().isNotEmpty) {
        previewPath = cachedPreview.trim();
      }
      final String? updatedRaw = cached['updated_at']?.toString();
      lastUpdated = updatedRaw == null ? null : DateTime.tryParse(updatedRaw);
    }

    if (await NetworkReachability.isOnline()) {
      try {
        final ({int count, DateTime? latest, String? imageUrl}) remote =
            await _fetchRemoteFieldImageStats(fieldId);
        if (remote.count > imageCount) imageCount = remote.count;
        lastUpdated = _maxDateTime(lastUpdated, remote.latest);
        final String? remoteUrl = remote.imageUrl?.trim();
        if ((previewPath == null || previewPath.trim().isEmpty) &&
            remoteUrl != null &&
            remoteUrl.isNotEmpty) {
          previewPath = remoteUrl;
        }
      } catch (_) {}
    }
  }

  if (previewPath == null || previewPath.trim().isEmpty) {
    final Map<String, String> localOnly =
        await db.latestCapturePreviewPathByFieldIds(<String>[fieldId]);
    previewPath = localOnly[fieldId];
  }

  return FieldImageStats(
    imageCount: imageCount,
    lastUpdated: lastUpdated,
    previewPath: previewPath,
  );
}

String? _previewFromCaptureRow(Map<String, dynamic> row) {
  final String? remote = row['remote_image_url'] as String?;
  if (remote != null && remote.trim().isNotEmpty) return remote.trim();
  final String? local = row['local_image_path'] as String?;
  if (local == null ||
      local.isEmpty ||
      local == DatabaseService.remoteOnlyLocalPath) {
    return null;
  }
  return local;
}

Future<({int count, DateTime? latest, String? imageUrl})>
    _fetchRemoteFieldImageStats(String fieldId) async {
  final client = SupabaseClientProvider.instance.client;
  final List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from(
    await client
        .from('detections')
        .select('image_url, created_at')
        .eq('field_id', fieldId)
        .order('created_at', ascending: false)
        .limit(1000),
  );
  int withImage = 0;
  DateTime? latest;
  String? newestUrl;
  for (final Map<String, dynamic> e in res) {
    final DateTime? created =
        DateTime.tryParse(e['created_at']?.toString() ?? '');
    latest = _maxDateTime(latest, created);
    final String? url = e['image_url'] as String?;
    if (url == null || url.trim().isEmpty) continue;
    withImage++;
    newestUrl ??= url.trim();
  }
  return (count: withImage, latest: latest, imageUrl: newestUrl);
}

/// Latest [image_url] per field (for card thumbnails when preview was never set).
Future<Map<String, String>> fetchLatestDetectionImageUrlByFieldIds(
  List<String> fieldIds,
) async {
  if (fieldIds.isEmpty) return const <String, String>{};
  final client = SupabaseClientProvider.instance.client;
  final List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from(
    await client
        .from('detections')
        .select('field_id, image_url, created_at')
        .inFilter('field_id', fieldIds)
        .order('created_at', ascending: false)
        .limit(2000),
  );
  final Map<String, String> out = <String, String>{};
  for (final Map<String, dynamic> e in res) {
    final String? fid = e['field_id'] as String?;
    if (fid == null || fid.isEmpty || out.containsKey(fid)) continue;
    final String? url = e['image_url'] as String?;
    if (url == null || url.trim().isEmpty) continue;
    out[fid] = url.trim();
  }
  return out;
}
