library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

/// DA/OMAG expert advice stored in Supabase `expert_responses`.
class ExpertFeedbackService {
  ExpertFeedbackService({SupabaseClientProvider? clientProvider})
      : _client = (clientProvider ?? SupabaseClientProvider.instance).client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> getResponseForDetection(
    String detectionId,
  ) async {
    final String id = detectionId.trim();
    if (id.isEmpty) return null;
    try {
      final Object? raw = await _client
          .from('expert_responses')
          .select()
          .eq('detection_id', id)
          .maybeSingle();
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  Future<void> upsertResponse({
    required String detectionId,
    required String strategyText,
    String? actionType,
  }) async {
    final String detId = detectionId.trim();
    final String text = strategyText.trim();
    if (detId.isEmpty || text.isEmpty) {
      throw ArgumentError('detectionId and strategyText are required');
    }
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in required');
    }
    final Map<String, dynamic> row = <String, dynamic>{
      'detection_id': detId,
      'author_id': uid,
      'strategy_text': text,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final String? action = actionType?.trim();
    if (action != null && action.isNotEmpty) {
      row['action_type'] = action;
    }
    await _client.from('expert_responses').upsert(
          row,
          onConflict: 'detection_id',
        );
  }
}
