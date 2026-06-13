/// Saves detection results and images to Supabase (Storage + Postgres).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../utils/field_name_similarity.dart';
import '../utils/polygon_random_point.dart';

class DetectionService {
  DetectionService({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.instance.client;

  final SupabaseClient _client;

  /// Saves a detection: uploads image to Storage, writes metadata to `detections`.
  ///
  /// When [fieldNameHint] is set (e.g. filename stem + UI field label), it is
  /// fuzzy-matched against the user's Supabase [fields].name. On a strong match,
  /// [fieldId] is filled if it was empty, and coordinates are placed at a random
  /// point inside [fields].boundary_json] when that polygon exists.
  Future<Map<String, dynamic>> saveDetection({
    required File imageFile,
    required Map<String, dynamic> detectionResult,
    String? fieldId,
    double? latitude,
    double? longitude,
    String? fieldNameHint,
    String? detectionsJson,
  }) async {
    try {
      final String? uid = _client.auth.currentUser?.id;
      if (uid == null) {
        return <String, dynamic>{
          'success': false,
          'message': 'User not authenticated',
        };
      }
      String? effectiveFieldId = fieldId?.trim();
      double? useLat = latitude;
      double? useLng = longitude;
      bool matchedFieldFromHint = false;

      List<Map<String, dynamic>> cloudFields = <Map<String, dynamic>>[];
      try {
        final Object raw = await _client
            .from('fields')
            .select('id, name, boundary_json')
            .eq('user_id', uid);
        if (raw is List) {
          for (final Object? item in raw) {
            if (item is Map<String, dynamic>) {
              cloudFields.add(item);
            } else if (item is Map) {
              cloudFields.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {
        cloudFields = <Map<String, dynamic>>[];
      }

      final String? hint = fieldNameHint?.trim();
      if (hint != null &&
          hint.isNotEmpty &&
          cloudFields.isNotEmpty &&
          (effectiveFieldId == null || effectiveFieldId.isEmpty)) {
        final Map<String, dynamic>? row =
            bestMatchingFieldRow(hint, cloudFields);
        if (row != null) {
          final String? id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            effectiveFieldId = id;
            matchedFieldFromHint = true;
          }
        }
      }

      if (effectiveFieldId != null && effectiveFieldId.isNotEmpty) {
        Map<String, dynamic>? rowForField;
        for (final Map<String, dynamic> r in cloudFields) {
          if (r['id']?.toString() == effectiveFieldId) {
            rowForField = r;
            break;
          }
        }
        final dynamic boundary =
            rowForField == null ? null : rowForField['boundary_json'];
        final LatLngDeg? randomPt =
            randomPointForFieldBoundary(boundary, Random());
        if (randomPt != null) {
          final bool needRandom =
              matchedFieldFromHint || useLat == null || useLng == null;
          if (needRandom) {
            useLat = randomPt.latitude;
            useLng = randomPt.longitude;
          }
        }
      }

      final String path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('detections').upload(
            path,
            imageFile,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final String imageUrl =
          _client.storage.from('detections').getPublicUrl(path);

      final int count = (detectionResult['count'] as num?)?.toInt() ?? 0;
      final bool hasMealybugs = count > 0;

      final Map<String, dynamic> row = <String, dynamic>{
        'user_id': uid,
        'image_url': imageUrl,
        'confidence': detectionResult['confidence'],
        'count': count,
        'has_mealybugs': hasMealybugs,
      };
      if (effectiveFieldId != null && effectiveFieldId.isNotEmpty) {
        row['field_id'] = effectiveFieldId;
      }
      if (useLat != null && useLng != null) {
        row['latitude'] = useLat;
        row['longitude'] = useLng;
      }

      final String? dj = detectionsJson?.trim();
      if (dj != null && dj.isNotEmpty) {
        try {
          row['detections_json'] = jsonDecode(dj);
        } catch (_) {
          row['detections_json'] = dj;
        }
      }

      final Map<String, dynamic> inserted = await _client
          .from('detections')
          .insert(row)
          .select('id, image_url')
          .single();

      if (effectiveFieldId != null && effectiveFieldId.isNotEmpty) {
        // Avoid client-side non-atomic counters (can drift when multiple uploads
        // happen quickly or offline reassignment occurs). UI derives counts from
        // actual detections / local history.
        await _client.from('fields').update(<String, dynamic>{
          'last_detection': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', effectiveFieldId);
      }

      return <String, dynamic>{
        'success': true,
        'message': effectiveFieldId != null && effectiveFieldId.isNotEmpty
            ? 'Detection saved successfully'
            : 'Detection saved (not linked to a field)',
        'detection_id': inserted['id']?.toString(),
        'image_url': inserted['image_url']?.toString() ?? imageUrl,
      };
    } on StorageException catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Storage error: ${e.message}',
      };
    } on PostgrestException catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Database error: ${e.message}',
      };
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Error saving detection: $e',
      };
    }
  }

  /// Updates which field a saved detection is linked to (RLS: own rows only).
  Future<void> updateDetectionFieldAssignment({
    required String detectionId,
    String? fieldId,
  }) async {
    await _client.from('detections').update(<String, dynamic>{
      'field_id': fieldId,
    }).eq('id', detectionId);
  }

  /// Deletes a detection row (Storage object may remain).
  Future<void> deleteDetection({
    required String detectionId,
  }) async {
    await _client.from('detections').delete().eq('id', detectionId);
  }

  /// Stream of detection rows for a field, newest first (by `created_at`).
  Stream<List<Map<String, dynamic>>> getDetectionsForField(String fieldId) {
    return _client
        .from('detections')
        .stream(primaryKey: const <String>['id'])
        .eq('field_id', fieldId)
        .order('created_at', ascending: false);
  }
}
