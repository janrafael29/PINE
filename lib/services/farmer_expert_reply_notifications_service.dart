/// Unseen DA/OMAG expert advice on the signed-in farmer's captures.
library;

import '../core/admin_session.dart';
import '../core/expert_reply_notification_prefs.dart';
import '../core/supabase_client.dart';
import '../utils/detection_report_status.dart';

class FarmerExpertReplyNotice {
  const FarmerExpertReplyNotice({
    required this.detectionId,
    required this.updatedAtIso,
    required this.fieldName,
    required this.strategyPreview,
    this.actionType,
  });

  final String detectionId;
  final String updatedAtIso;
  final String fieldName;
  final String strategyPreview;
  final String? actionType;
}

class FarmerExpertReplyNotificationsService {
  FarmerExpertReplyNotificationsService({SupabaseClientProvider? clientProvider})
      : _client = (clientProvider ?? SupabaseClientProvider.instance).client;

  final dynamic _client;

  Future<List<FarmerExpertReplyNotice>> fetchUnseenForCurrentUser({
    int limit = 50,
  }) async {
    if (currentUserJwtStaff()) return const <FarmerExpertReplyNotice>[];

    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return const <FarmerExpertReplyNotice>[];

    final Object raw = await _client
        .from('detections')
        .select(
          'id, field_id, has_mealybugs, count, confidence, '
          'fields(name), '
          'expert_responses(strategy_text, action_type, updated_at)',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);

    if (raw is! List) return const <FarmerExpertReplyNotice>[];

    final List<FarmerExpertReplyNotice> out = <FarmerExpertReplyNotice>[];
    for (final dynamic row in raw) {
      if (row is! Map) continue;
      final Map<String, dynamic> det = Map<String, dynamic>.from(row);
      if (!detectionRowIsPositive(det)) continue;

      final dynamic expertRaw = det['expert_responses'];
      Map<String, dynamic>? expert;
      if (expertRaw is Map) {
        expert = Map<String, dynamic>.from(expertRaw);
      } else if (expertRaw is List && expertRaw.isNotEmpty) {
        final dynamic first = expertRaw.first;
        if (first is Map) expert = Map<String, dynamic>.from(first);
      }
      if (expert == null) continue;

      final String text = (expert['strategy_text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;

      final String detId = (det['id'] as String?)?.trim() ?? '';
      if (detId.isEmpty) continue;

      final String updatedAt =
          (expert['updated_at'] as String?)?.trim() ?? '';
      final bool unseen = await isExpertReplyUnseen(
        detectionId: detId,
        updatedAt: updatedAt,
      );
      if (!unseen) continue;

      String fieldName = 'your field';
      final dynamic fieldsRaw = det['fields'];
      if (fieldsRaw is Map) {
        final String? name = (fieldsRaw['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) fieldName = name;
      }

      final String preview =
          text.length > 120 ? '${text.substring(0, 117)}…' : text;

      out.add(
        FarmerExpertReplyNotice(
          detectionId: detId,
          updatedAtIso: updatedAt,
          fieldName: fieldName,
          strategyPreview: preview,
          actionType: (expert['action_type'] as String?)?.trim(),
        ),
      );
    }

    out.sort((FarmerExpertReplyNotice a, FarmerExpertReplyNotice b) {
      return b.updatedAtIso.compareTo(a.updatedAtIso);
    });
    return out;
  }

  Future<int> countUnseenForCurrentUser() async {
    final List<FarmerExpertReplyNotice> rows =
        await fetchUnseenForCurrentUser();
    return rows.length;
  }
}
