/// Loads per-field aggregates from Supabase [detections] (paginated scan).
library;

import '../core/supabase_client.dart';

/// Counts derived from [detections]: map rows vs rows that include a stored image.
class SupabaseFieldDetectionAggregates {
  const SupabaseFieldDetectionAggregates({
    required this.rowsByField,
    required this.imagesByField,
  });

  /// All rows with a non-empty [field_id] (records shown on the map).
  final Map<String, int> rowsByField;

  /// Rows with non-empty [image_url] — one saved capture image per row.
  final Map<String, int> imagesByField;
}

Future<SupabaseFieldDetectionAggregates>
    fetchSupabaseFieldDetectionAggregatesByFieldId() async {
  final client = SupabaseClientProvider.instance.client;
  const int chunk = 1000;
  final Map<String, int> rowsByField = <String, int>{};
  final Map<String, int> imagesByField = <String, int>{};
  int from = 0;
  while (true) {
    final List<Map<String, dynamic>> res = List<Map<String, dynamic>>.from(
      await client
          .from('detections')
          .select('field_id, image_url')
          .order('id', ascending: true)
          .range(from, from + chunk - 1),
    );
    if (res.isEmpty) break;
    for (final Map<String, dynamic> e in res) {
      final String? fid = e['field_id'] as String?;
      if (fid == null || fid.isEmpty) continue;
      rowsByField[fid] = (rowsByField[fid] ?? 0) + 1;
      final String? url = e['image_url'] as String?;
      if (url != null && url.trim().isNotEmpty) {
        imagesByField[fid] = (imagesByField[fid] ?? 0) + 1;
      }
    }
    if (res.length < chunk) break;
    from += chunk;
  }
  return SupabaseFieldDetectionAggregates(
    rowsByField: rowsByField,
    imagesByField: imagesByField,
  );
}

/// One detection row per [field_id] (includes rows without [image_url]).
Future<Map<String, int>> fetchSupabaseDetectionCountsByFieldId() async {
  final SupabaseFieldDetectionAggregates a =
      await fetchSupabaseFieldDetectionAggregatesByFieldId();
  return a.rowsByField;
}
