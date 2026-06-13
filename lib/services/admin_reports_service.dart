library;

import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../utils/detection_report_status.dart';

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

/// Loads org-wide positive detection reports for JWT admin users.
class AdminReportsService {
  AdminReportsService({SupabaseClientProvider? clientProvider})
      : _client = (clientProvider ?? SupabaseClientProvider.instance).client;

  final dynamic _client;

  Future<List<AdminReportItem>> fetchPositiveReports({
    bool pendingReplyOnly = false,
    int limit = 300,
  }) async {
    if (!currentUserJwtStaff()) {
      throw StateError('Admin access required');
    }

    final List<Map<String, dynamic>> detections =
        await _fetchDetections(limit: limit);
    final List<Map<String, dynamic>> positive = detections
        .where(detectionRowIsPositive)
        .toList(growable: false);

    final Set<String> detIds = positive
        .map((Map<String, dynamic> d) => d['id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Set<String> fieldIds = positive
        .map((Map<String, dynamic> d) => d['field_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Set<String> farmerIds = positive
        .map((Map<String, dynamic> d) => d['user_id']?.toString() ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final Map<String, String> fieldNames = await _fieldNamesById(fieldIds);
    final Map<String, String> farmerLabels =
        await fetchProfileOwnerLabelsForUserIds(farmerIds.toList());
    final Set<String> repliedIds = await _detectionIdsWithExpertReply(detIds);

    final List<AdminReportItem> out = <AdminReportItem>[];
    for (final Map<String, dynamic> d in positive) {
      final String? detId = d['id']?.toString();
      final String? imageUrl = d['image_url'] as String?;
      if (detId == null || detId.isEmpty || imageUrl == null || imageUrl.isEmpty) {
        continue;
      }
      final bool hasReply = repliedIds.contains(detId);
      if (pendingReplyOnly && hasReply) continue;

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
    try {
      final Object? raw = await _client
          .from('expert_responses')
          .select('detection_id, strategy_text')
          .inFilter('detection_id', detectionIds.toList());
      if (raw is! List) return <String>{};
      final Set<String> out = <String>{};
      for (final Object? item in raw) {
        if (item is! Map) continue;
        final Map<String, dynamic> row = Map<String, dynamic>.from(item);
        final String? detId = row['detection_id']?.toString();
        final String text = (row['strategy_text'] as String?)?.trim() ?? '';
        if (detId != null && detId.isNotEmpty && text.isNotEmpty) {
          out.add(detId);
        }
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  static int _confidenceToPercent(num? raw) {
    if (raw == null) return 0;
    final double v = raw.toDouble();
    final double pct = v <= 1.0 ? v * 100.0 : v;
    return pct.round().clamp(0, 100);
  }
}
