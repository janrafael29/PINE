/// Fuzzy match between a free-text hint (filename, labels) and a field name.
library;

import 'dart:math' as math;

String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  List<int> v0 = List<int>.generate(b.length + 1, (int i) => i);
  List<int> v1 = List<int>.filled(b.length + 1, 0);
  for (int i = 0; i < a.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < b.length; j++) {
      final int cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      v1[j + 1] = math.min(
        v1[j] + 1,
        math.min(v0[j + 1] + 1, v0[j] + cost),
      );
    }
    final List<int> tmp = v0;
    v0 = v1;
    v1 = tmp;
  }
  return v0[b.length];
}

double _levenshteinRatio(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final int d = _levenshtein(a, b);
  final int m = a.length > b.length ? a.length : b.length;
  if (m == 0) return 1;
  return 1.0 - d / m;
}

/// Returns 0..1. Treats multi-word hints by taking the best score vs [fieldName].
double fieldNameSimilarity(String hint, String fieldName) {
  final h0 = _normalize(hint);
  final f0 = _normalize(fieldName);
  if (h0.isEmpty || f0.isEmpty) return 0;
  if (h0 == f0) return 1;
  if (h0.contains(f0) || f0.contains(h0)) return 0.88;

  double best = _levenshteinRatio(h0, f0);

  final Set<String> ht = h0
      .split(' ')
      .where((String e) => e.length > 1)
      .toSet();
  final Set<String> ft = f0
      .split(' ')
      .where((String e) => e.length > 1)
      .toSet();
  if (ht.isNotEmpty && ft.isNotEmpty) {
    int overlap = 0;
    for (final String t in ht) {
      for (final String x in ft) {
        if (x.contains(t) || t.contains(x)) {
          overlap++;
          break;
        }
      }
    }
    if (overlap > 0) {
      final double tokenScore = 0.72 + 0.06 * overlap.clamp(0, 4);
      if (tokenScore > best) {
        best = tokenScore;
      }
    }
  }

  for (final String piece in h0.split(' ').where((String e) => e.length > 2)) {
    final double r = _levenshteinRatio(piece, f0);
    if (r > best) {
      best = r;
    }
  }

  return best.clamp(0.0, 1.0);
}

/// Minimum score to auto-assign a Supabase field from a hint.
const double kFieldNameMatchThreshold = 0.52;

Map<String, dynamic>? bestMatchingFieldRow(
  String hint,
  List<Map<String, dynamic>> fields,
) {
  if (hint.trim().isEmpty || fields.isEmpty) {
    return null;
  }
  double bestScore = 0;
  Map<String, dynamic>? bestRow;
  for (final Map<String, dynamic> row in fields) {
    final String name = row['name']?.toString() ?? '';
    final double s = fieldNameSimilarity(hint, name);
    if (s > bestScore) {
      bestScore = s;
      bestRow = row;
    }
  }
  if (bestRow == null || bestScore < kFieldNameMatchThreshold) {
    return null;
  }
  return bestRow;
}
