library;

import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../utils/detection_report_status.dart';

/// Match [DETECTIONS_LIMIT] in admin/app.js so mobile and web report the same totals.
const int kAdminReportsDetectionLimit = 2500;

/// PostgREST `in` filters are chunked to stay under URL/size limits.
const int _expertReplyInFilterBatchSize = 150;

/// One positive farmer report visible to DA/OMAG admin.
class AdminReportItem {
  const AdminReportItem({
    required this.detectionId,
    required this.imageUrl,
    required this.count,
    required this.confidencePct,
    required this.fieldName,
    required this.farmerLabel,
    required this.createdAtIso,
    required this.hasExpertReply,
    this.fieldId,
    this.farmerUserId,
    this.latitude,
    this.longitude,
  });

  final String detectionId;
  final String imageUrl;
  final int count;
  final int confidencePct;
  final String fieldName;
  final String farmerLabel;
  final String createdAtIso;
  final bool hasExpertReply;
  final String? fieldId;
  final String? farmerUserId;
  final double? latitude;
  final double? longitude;
}

/// Report list filter for DA / admin review screens.
enum AdminReportFilter { all, positiveOnly, pendingReply, negativeOnly }

/// Loads org-wide detection reports for JWT admin users.
class AdminReportsService {
  AdminReportsService({SupabaseClientProvider? clientProvider})
      : _client = (clientProvider ?? SupabaseClientProvider.instance).client;

  final dynamic _client;

  Future<List<AdminReportItem>> fetchReports({
    AdminReportFilter filter = AdminReportFilter.all,
    int limit = kAdminReportsDetectionLimit,
  }) async {
    if (!currentUserJwtStaff()) {
      throw StateError('Admin access required');
    }

    final List<Map<String, dynamic>> detections =
        await _fetchDetections(limit: limit);
    List<Map<String, dynamic>> scoped = detections;
    switch (filter) {
      case AdminReportFilter.positiveOnly:
      case AdminReportFilter.pendingReply:
        scoped = detections.where(detectionRowIsPositive).toList();
        break;
      case AdminReportFilter.negativeOnly:
        scoped = detections
            .where((Map<String, dynamic> d) => !detectionRowIsPositive(d))
            .toList();
        break;
      case AdminReportFilter.all:
        break;
    }

    final Set<String> detIds = scoped
        .map((Map<String, dynamic> d) => d['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Set<String> fieldIds = scoped
        .map((Map<String, dynamic> d) => d['field_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Set<String> farmerIds = scoped
        .map((Map<String, dynamic> d) => d['user_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Map<String, String> fieldNames = await _fieldNamesById(fieldIds);
    final Map<String, String> farmerLabels =
        await fetchProfileOwnerLabelsForUserIds(farmerIds.toList());
    final Set<String> repliedIds = await _detectionIdsWithExpertReply(detIds);

    final List<AdminReportItem> out = <AdminReportItem>[];
    for (final Map<String, dynamic> d in scoped) {
      final String? detId = d['id']?.toString();
      final String? imageUrl = d['image_url'] as String?;
      if (detId == null || detId.isEmpty || imageUrl == null || imageUrl.isEmpty) {
        continue;
      }
      final bool isPositive = detectionRowIsPositive(d);
      final bool hasReply = repliedIds.contains(detId);
      if (filter == AdminReportFilter.pendingReply &&
          (!isPositive || hasReply)) {
        continue;
      }

      final String? fieldId = d['field_id']?.toString();
      final String fieldName = fieldId != null && fieldNames.containsKey(fieldId)
          ? fieldNames[fieldId]!
          : 'Field';
      final String? farmerUserId = d['user_id']?.toString();
      final String farmerLabel = farmerUserId == null
          ? 'Farmer'
          : ownerDisplayLabel(farmerUserId, farmerLabels);

      out.add(
        AdminReportItem(
          detectionId: detId,
          imageUrl: imageUrl,
          count: (d['count'] as num?)?.toInt() ?? 0,
          confidencePct: _confidenceToPercent(d['confidence'] as num?),
          fieldName: fieldName,
          farmerLabel: farmerLabel,
          createdAtIso: (d['created_at'] as String?) ?? '',
          hasExpertReply: hasReply,
          fieldId: fieldId,
          farmerUserId: farmerUserId,
          latitude: d['latitude'] == null
              ? null
              : (d['latitude'] as num).toDouble(),
          longitude: d['longitude'] == null
              ? null
              : (d['longitude'] as num).toDouble(),
        ),
      );
    }
    return out;
  }

  /// Positive farmer reports still waiting for expert advice.
  Future<int> countPendingReplyReports({
    int limit = kAdminReportsDetectionLimit,
  }) async {
    if (!currentUserJwtStaff()) return 0;
    final List<AdminReportItem> rows = await fetchReports(
      filter: AdminReportFilter.pendingReply,
      limit: limit,
    );
    return rows.length;
  }

  /// Positive reports only (legacy helper).
  Future<List<AdminReportItem>> fetchPositiveReports({
    bool pendingReplyOnly = false,
    int limit = kAdminReportsDetectionLimit,
  }) {
    return fetchReports(
      filter: pendingReplyOnly
          ? AdminReportFilter.pendingReply
          : AdminReportFilter.positiveOnly,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> fetchDetectionDetail(String detectionId) async {
    final String id = detectionId.trim();
    if (id.isEmpty) return null;
    if (!currentUserJwtStaff()) {
      throw StateError('Admin access required');
    }
    try {
      final Object? raw = await _client
          .from('detections')
          .select(
            'id, user_id, field_id, image_url, latitude, longitude, count, confidence, created_at, detections_json, has_mealybugs',
          )
          .eq('id', id)
          .maybeSingle();
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> _fetchDetections({required int limit}) async {
    try {
      final Object? raw = await _client
          .from('detections')
          .select(
            'id, user_id, field_id, image_url, latitude, longitude, count, confidence, has_mealybugs, created_at',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, String>> _fieldNamesById(Set<String> fieldIds) async {
    if (fieldIds.isEmpty) return <String, String>{};
    try {
      final Object? raw =
          await _client.from('fields').select('id, name').inFilter('id', fieldIds.toList());
      if (raw is! List) return <String, String>{};
      final Map<String, String> out = <String, String>{};
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final Map<String, dynamic> row = Map<String, dynamic>.from(item);
        final String? id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        out[id] = (row['name'] as String?)?.trim().isNotEmpty == true
            ? (row['name'] as String).trim()
            : 'Field';
      }
      return out;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<Set<String>> _detectionIdsWithExpertReply(Set<String> detectionIds) async {
    if (detectionIds.isEmpty) return <String>{};
    final List<String> ids = detectionIds.toList();
    final Set<String> out = <String>{};
    try {
      for (int offset = 0; offset < ids.length; offset += _expertReplyInFilterBatchSize) {
        final int end = offset + _expertReplyInFilterBatchSize;
        final List<String> batch = ids.sublist(
          offset,
          end > ids.length ? ids.length : end,
        );
        final Object? raw = await _client
            .from('expert_responses')
            .select('detection_id, strategy_text')
            .inFilter('detection_id', batch);
        if (raw is! List) continue;
        for (final Object? item in raw) {
          if (item is! Map) continue;
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          final String? detId = row['detection_id']?.toString();
          final String text = (row['strategy_text'] as String?)?.trim() ?? '';
          if (detId != null && detId.isNotEmpty && text.isNotEmpty) {
            out.add(detId);
          }
        }
      }
      return out;
    } catch (_) {
      return out;
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchExpertResponsesByDetectionIds(
    Set<String> detectionIds,
  ) async {
    if (detectionIds.isEmpty) return <String, Map<String, dynamic>>{};
    final List<String> ids = detectionIds.toList();
    final Map<String, Map<String, dynamic>> out = <String, Map<String, dynamic>>{};
    try {
      for (int offset = 0; offset < ids.length; offset += _expertReplyInFilterBatchSize) {
        final int end = offset + _expertReplyInFilterBatchSize;
        final List<String> batch = ids.sublist(
          offset,
          end > ids.length ? ids.length : end,
        );
        final Object? raw = await _client
            .from('expert_responses')
            .select('detection_id, strategy_text, action_type, updated_at')
            .inFilter('detection_id', batch);
        if (raw is! List) continue;
        for (final Object? item in raw) {
          if (item is! Map) continue;
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          final String? detId = row['detection_id']?.toString();
          final String text = (row['strategy_text'] as String?)?.trim() ?? '';
          if (detId == null || detId.isEmpty || text.isEmpty) continue;
          out[detId] = row;
        }
      }
    } catch (_) {}
    return out;
  }

  static int _confidenceToPercent(num? raw) {
    if (raw == null) return 0;
    final double v = raw.toDouble();
    final double pct = v <= 1.0 ? v * 100.0 : v;
    return pct.round().clamp(0, 100);
  }
}

/// One field bucket in the staff farmer-reports queue.
class AdminReportFieldGroup {
  const AdminReportFieldGroup({
    required this.key,
    required this.fieldId,
    required this.fieldName,
    required this.farmerLabel,
    required this.items,
  });

  final String key;
  final String? fieldId;
  final String fieldName;
  final String farmerLabel;
  final List<AdminReportItem> items;

  int get captureCount => items.length;

  int get pendingCount =>
      items.where((AdminReportItem i) => !i.hasExpertReply).length;

  int get reviewedCount =>
      items.where((AdminReportItem i) => i.hasExpertReply).length;

  String get latestCreatedAtIso {
    if (items.isEmpty) return '';
    return items
        .map((AdminReportItem i) => i.createdAtIso)
        .reduce((String a, String b) => a.compareTo(b) > 0 ? a : b);
  }
}

/// Groups flat report rows by field for expandable queue UI.
List<AdminReportFieldGroup> groupAdminReportsByField(
  List<AdminReportItem> items,
) {
  if (items.isEmpty) return <AdminReportFieldGroup>[];
  final Map<String, List<AdminReportItem>> buckets =
      <String, List<AdminReportItem>>{};
  for (final AdminReportItem item in items) {
    final String key = item.fieldId != null && item.fieldId!.isNotEmpty
        ? item.fieldId!
        : 'name:${item.fieldName}|${item.farmerUserId ?? item.farmerLabel}';
    buckets.putIfAbsent(key, () => <AdminReportItem>[]).add(item);
  }
  final List<AdminReportFieldGroup> groups = buckets.entries.map((entry) {
    final List<AdminReportItem> sorted = List<AdminReportItem>.from(entry.value)
      ..sort((AdminReportItem a, AdminReportItem b) =>
          b.createdAtIso.compareTo(a.createdAtIso));
    final AdminReportItem first = sorted.first;
    return AdminReportFieldGroup(
      key: entry.key,
      fieldId: first.fieldId,
      fieldName: first.fieldName,
      farmerLabel: first.farmerLabel,
      items: sorted,
    );
  }).toList();
  groups.sort((AdminReportFieldGroup a, AdminReportFieldGroup b) {
    final int pendingCmp = b.pendingCount.compareTo(a.pendingCount);
    if (pendingCmp != 0) return pendingCmp;
    return b.latestCreatedAtIso.compareTo(a.latestCreatedAtIso);
  });
  return groups;
}
