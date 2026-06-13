library;

/// Whether a Supabase `detections` row counts as a positive mealybug report.
bool detectionRowIsPositive(Map<String, dynamic> row) {
  final dynamic hm = row['has_mealybugs'];
  if (hm is bool) return hm;
  return ((row['count'] as num?)?.toInt() ?? 0) > 0;
}

/// User-facing label for capture / report lists.
String detectionStatusLabel(Map<String, dynamic> row, {bool filipino = false}) {
  if (detectionRowIsPositive(row)) {
    return filipino ? 'Positibo' : 'Positive';
  }
  return filipino ? 'Negatibo' : 'Negative';
}

/// Local SQLite [captured_photo] row (count only).
bool capturedPhotoRowIsPositive(Map<String, dynamic> row) =>
    ((row['count'] as num?)?.toInt() ?? 0) > 0;

String capturedPhotoStatusLabel(Map<String, dynamic> row, {bool filipino = false}) {
  if (capturedPhotoRowIsPositive(row)) {
    return filipino ? 'Positibo' : 'Positive';
  }
  return filipino ? 'Negatibo' : 'Negative';
}
