library;

class DashboardStats {
  const DashboardStats({
    required this.imageCount,
    required this.fieldCount,
    required this.infestationRate,
    required this.last7Days,
    required this.dailyCounts,
  });

  final int imageCount;
  final int fieldCount;
  final int infestationRate;
  final List<DateTime> last7Days;
  final List<int> dailyCounts;
}

class DashboardStatsCalculator {
  const DashboardStatsCalculator._();

  /// Stats from Supabase `detections` rows (snake_case keys).
  static DashboardStats fromDetectionMaps(
    List<Map<String, dynamic>> docs,
  ) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startDay = today.subtract(const Duration(days: 6));
    final DateTime endExclusive = today.add(const Duration(days: 1));

    final List<Map<String, dynamic>> docsLast7Days =
        docs.where((Map<String, dynamic> d) {
      final DateTime? t = _parseCreatedAt(d);
      if (t == null) return false;
      return t.isAfter(startDay.subtract(const Duration(milliseconds: 1))) &&
          t.isBefore(endExclusive);
    }).toList();

    final int imageCount = docsLast7Days.length;

    final Set<String> fieldIds = docsLast7Days
        .map((Map<String, dynamic> d) =>
            d['field_id'] as String? ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();
    final int fieldCount = fieldIds.length;

    final Set<String> infestedFieldIds = docsLast7Days
        .where((Map<String, dynamic> d) => d['has_mealybugs'] == true)
        .map((Map<String, dynamic> d) =>
            d['field_id'] as String? ?? '')
        .where((String id) => id.isNotEmpty)
        .toSet();

    final int infestationRate = fieldCount > 0
        ? ((infestedFieldIds.length / fieldCount) * 100).round()
        : 0;

    final List<DateTime> last7Days = List<DateTime>.generate(7, (int i) {
      final DateTime d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final List<int> dailyCounts = last7Days.map((DateTime date) {
      int sum = 0;
      for (final Map<String, dynamic> d in docsLast7Days) {
        final DateTime? t = _parseCreatedAt(d);
        if (t == null) continue;
        final DateTime day = DateTime(t.year, t.month, t.day);
        if (!day.isAtSameMomentAs(date)) continue;
        sum += (d['count'] as num?)?.toInt() ?? 0;
      }
      return sum;
    }).toList();

    return DashboardStats(
      imageCount: imageCount,
      fieldCount: fieldCount,
      infestationRate: infestationRate,
      last7Days: last7Days,
      dailyCounts: dailyCounts,
    );
  }

  static DateTime? _parseCreatedAt(Map<String, dynamic> d) {
    final dynamic v = d['created_at'] ?? d['timestamp'];
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static DashboardStats fromCapturedPhotos(
    List<Map<String, dynamic>> rows,
  ) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime startDay = today.subtract(const Duration(days: 6));
    final DateTime endExclusive = today.add(const Duration(days: 1));

    final List<Map<String, dynamic>> inRange = rows.where((Map<String, dynamic> r) {
      final dynamic createdAt = r['created_at'];
      if (createdAt == null || createdAt is! String) return false;
      final DateTime? t = DateTime.tryParse(createdAt);
      if (t == null) return false;
      return t.isAfter(startDay.subtract(const Duration(milliseconds: 1))) &&
          t.isBefore(endExclusive);
    }).toList();

    final int imageCount = inRange.length;

    final Set<String> fieldIds = inRange
        .map((Map<String, dynamic> r) {
          final String? fieldId = r['field_id'] as String?;
          final String? fieldName = r['field_name'] as String?;
          return fieldId ?? fieldName ?? '';
        })
        .where((String id) => id.isNotEmpty)
        .toSet();
    final int fieldCount = fieldIds.length;

    final Set<String> infestedFieldIds = inRange
        .where((Map<String, dynamic> r) {
          final num? c = r['count'] as num?;
          return (c ?? 0).toInt() > 0;
        })
        .map((Map<String, dynamic> r) {
          final String? fieldId = r['field_id'] as String?;
          final String? fieldName = r['field_name'] as String?;
          return fieldId ?? fieldName ?? '';
        })
        .where((String id) => id.isNotEmpty)
        .toSet();

    final int infestationRate = fieldCount > 0
        ? ((infestedFieldIds.length / fieldCount) * 100).round()
        : 0;

    final List<DateTime> last7Days = List<DateTime>.generate(7, (int i) {
      final DateTime d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final List<int> dailyCounts = last7Days.map((DateTime date) {
      int sum = 0;
      for (final Map<String, dynamic> r in inRange) {
        final dynamic createdAt = r['created_at'];
        if (createdAt == null || createdAt is! String) continue;
        final DateTime? t = DateTime.tryParse(createdAt);
        if (t == null) continue;
        final DateTime day = DateTime(t.year, t.month, t.day);
        if (!day.isAtSameMomentAs(date)) continue;
        sum += (r['count'] as num?)?.toInt() ?? 0;
      }
      return sum;
    }).toList();

    return DashboardStats(
      imageCount: imageCount,
      fieldCount: fieldCount,
      infestationRate: infestationRate,
      last7Days: last7Days,
      dailyCounts: dailyCounts,
    );
  }
}
