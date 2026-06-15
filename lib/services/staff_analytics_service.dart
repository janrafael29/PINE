/// Org-wide analytics for DA / admin (mirrors PineSight Admin web drawer).
library;

import '../utils/detection_report_status.dart';

enum StaffTrendRange { days7, days30, year1 }

class StaffTopFarmRow {
  const StaffTopFarmRow({
    required this.fieldId,
    required this.fieldName,
    required this.ownerLabel,
    required this.positiveCount,
    this.lastSightingIso,
  });

  final String fieldId;
  final String fieldName;
  final String ownerLabel;
  final int positiveCount;
  final String? lastSightingIso;
}

class StaffTrendSeries {
  const StaffTrendSeries({
    required this.counts,
    required this.labels,
  });

  final List<int> counts;
  final List<String> labels;

  bool get hasData => counts.any((int c) => c > 0);
}

class StaffAnalyticsSnapshot {
  const StaffAnalyticsSnapshot({
    required this.totalPositive,
    required this.totalNegative,
    required this.positive7d,
    required this.positive30d,
    required this.trend7d,
    required this.trend30d,
    required this.trendYear,
    required this.topFarms,
  });

  final int totalPositive;
  final int totalNegative;
  final int positive7d;
  final int positive30d;
  final StaffTrendSeries trend7d;
  final StaffTrendSeries trend30d;
  final StaffTrendSeries trendYear;
  final List<StaffTopFarmRow> topFarms;

  int get totalReports => totalPositive + totalNegative;

  double get positiveRate =>
      totalReports > 0 ? totalPositive / totalReports : 0.0;

  StaffTrendSeries trendFor(StaffTrendRange range) {
    switch (range) {
      case StaffTrendRange.days7:
        return trend7d;
      case StaffTrendRange.days30:
        return trend30d;
      case StaffTrendRange.year1:
        return trendYear;
    }
  }
}

class StaffAnalyticsCalculator {
  static const int _topFarmLimit = 5;

  static StaffAnalyticsSnapshot fromDetections({
    required List<Map<String, dynamic>> detections,
    required List<Map<String, dynamic>> fields,
    required Map<String, String> ownerLabels,
  }) {
    final List<Map<String, dynamic>> positive = detections
        .where(detectionRowIsPositive)
        .toList(growable: false);
    final int totalPositive = positive.length;
    final int totalNegative = detections.length - totalPositive;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime start7 = today.subtract(const Duration(days: 6));
    final DateTime start30 = today.subtract(const Duration(days: 29));

    int positive7d = 0;
    int positive30d = 0;
    for (final Map<String, dynamic> row in positive) {
      final DateTime? created = _parseCreatedAt(row['created_at']);
      if (created == null) continue;
      final DateTime day = DateTime(created.year, created.month, created.day);
      if (!day.isBefore(start7)) positive7d++;
      if (!day.isBefore(start30)) positive30d++;
    }

    final StaffTrendSeries trend7d = _buildDailyTrend(
      positive: positive,
      startDay: start7,
      dayCount: 7,
      labelEvery: 1,
    );
    final StaffTrendSeries trend30d = _buildDailyTrend(
      positive: positive,
      startDay: start30,
      dayCount: 30,
      labelEvery: 5,
    );
    final StaffTrendSeries trendYear = _buildMonthlyTrend(positive: positive);

    final Map<String, String> fieldNames = <String, String>{};
    final Map<String, String> fieldOwners = <String, String>{};
    for (final Map<String, dynamic> field in fields) {
      final String? id = field['id']?.toString();
      if (id == null || id.isEmpty) continue;
      fieldNames[id] = (field['name'] as String?)?.trim().isNotEmpty == true
          ? (field['name'] as String).trim()
          : 'Field';
      final String? ownerId = field['user_id']?.toString();
      if (ownerId != null && ownerId.isNotEmpty) {
        fieldOwners[id] = ownerLabels[ownerId] ?? ownerId;
      }
    }

    final Map<String, ({int count, String last})> farmAgg =
        <String, ({int count, String last})>{};
    for (final Map<String, dynamic> row in positive) {
      final String fid = row['field_id']?.toString() ?? '';
      if (fid.isEmpty) continue;
      final String created = row['created_at']?.toString() ?? '';
      final ({int count, String last}) prev =
          farmAgg[fid] ?? (count: 0, last: '');
      farmAgg[fid] = (
        count: prev.count + 1,
        last: created.compareTo(prev.last) > 0 ? created : prev.last,
      );
    }

    final List<StaffTopFarmRow> topFarms = farmAgg.entries
        .map((MapEntry<String, ({int count, String last})> e) {
          return StaffTopFarmRow(
            fieldId: e.key,
            fieldName: fieldNames[e.key] ?? 'Field',
            ownerLabel: fieldOwners[e.key] ?? '—',
            positiveCount: e.value.count,
            lastSightingIso: e.value.last.isEmpty ? null : e.value.last,
          );
        })
        .toList()
      ..sort((StaffTopFarmRow a, StaffTopFarmRow b) =>
          b.positiveCount.compareTo(a.positiveCount));

    if (topFarms.length > _topFarmLimit) {
      topFarms.removeRange(_topFarmLimit, topFarms.length);
    }

    return StaffAnalyticsSnapshot(
      totalPositive: totalPositive,
      totalNegative: totalNegative,
      positive7d: positive7d,
      positive30d: positive30d,
      trend7d: trend7d,
      trend30d: trend30d,
      trendYear: trendYear,
      topFarms: topFarms,
    );
  }

  static StaffTrendSeries _buildDailyTrend({
    required List<Map<String, dynamic>> positive,
    required DateTime startDay,
    required int dayCount,
    required int labelEvery,
  }) {
    final List<DateTime> days = List<DateTime>.generate(
      dayCount,
      (int i) => startDay.add(Duration(days: i)),
    );
    final List<int> counts = List<int>.filled(dayCount, 0);
    for (final Map<String, dynamic> row in positive) {
      final DateTime? created = _parseCreatedAt(row['created_at']);
      if (created == null) continue;
      final DateTime day =
          DateTime(created.year, created.month, created.day);
      for (int i = 0; i < dayCount; i++) {
        if (day == days[i]) {
          counts[i]++;
          break;
        }
      }
    }
    final List<String> labels = List<String>.generate(dayCount, (int i) {
      if (labelEvery > 1 && i % labelEvery != 0 && i != dayCount - 1) {
        return '';
      }
      final DateTime d = days[i];
      return '${d.month}/${d.day}';
    });
    return StaffTrendSeries(counts: counts, labels: labels);
  }

  static StaffTrendSeries _buildMonthlyTrend({
    required List<Map<String, dynamic>> positive,
  }) {
    final DateTime now = DateTime.now();
    final List<DateTime> months = List<DateTime>.generate(
      12,
      (int i) {
        final DateTime m = DateTime(now.year, now.month - (11 - i), 1);
        return m;
      },
    );
    final List<int> counts = List<int>.filled(12, 0);
    for (final Map<String, dynamic> row in positive) {
      final DateTime? created = _parseCreatedAt(row['created_at']);
      if (created == null) continue;
      final DateTime bucket = DateTime(created.year, created.month, 1);
      for (int i = 0; i < 12; i++) {
        if (bucket == months[i]) {
          counts[i]++;
          break;
        }
      }
    }
    const List<String> monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final List<String> labels = months
        .map((DateTime m) => monthNames[m.month - 1])
        .toList(growable: false);
    return StaffTrendSeries(counts: counts, labels: labels);
  }

  static DateTime? _parseCreatedAt(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
