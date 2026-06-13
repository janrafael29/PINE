/// Builds a text hint for matching captures to cloud [fields].name on upload.
library;

import 'package:path/path.dart' as p;

String? buildUploadNameHint({
  required String fieldLabel,
  String? originalFilePath,
}) {
  final parts = <String>[];
  final f = fieldLabel.trim();
  if (f.isNotEmpty) {
    final lower = f.toLowerCase();
    if (lower != 'unassigned' &&
        lower != 'walang field' &&
        lower != '—' &&
        lower != '-') {
      parts.add(f);
    }
  }
  if (originalFilePath != null && originalFilePath.isNotEmpty) {
    final base = p.basename(originalFilePath);
    if (base.isNotEmpty) {
      final dot = base.lastIndexOf('.');
      final stem = dot > 0 ? base.substring(0, dot) : base;
      if (stem.isNotEmpty && !stem.toLowerCase().startsWith('detection_')) {
        parts.add(stem);
      }
    }
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}
