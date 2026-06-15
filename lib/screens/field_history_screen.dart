// Per-field local history analytics (offline-first).
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/supabase_client.dart';
import '../services/database_service.dart';
import '../utils/smooth_line_chart_path.dart';
import '../widgets/app_scaffold.dart';

enum HistoryRange { last7, last30, last90, all }

class FieldHistoryScreen extends StatefulWidget {
  const FieldHistoryScreen({
    super.key,
    required this.fieldId,
    required this.fieldName,
  });

  final String fieldId;
  final String fieldName;

  @override
  State<FieldHistoryScreen> createState() => _FieldHistoryScreenState();
}

class _FieldHistoryScreenState extends State<FieldHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  HistoryRange _range = HistoryRange.last30;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _db.initialize();
  }

  DateTime? _parseCreatedAt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final String s = v.toString();
    return DateTime.tryParse(s);
  }

  ({DateTime? start, int days}) _rangeWindow() {
    final DateTime now = DateTime.now();
    switch (_range) {
      case HistoryRange.last7:
        return (start: now.subtract(const Duration(days: 6)), days: 7);
      case HistoryRange.last30:
        return (start: now.subtract(const Duration(days: 29)), days: 30);
      case HistoryRange.last90:
        return (start: now.subtract(const Duration(days: 89)), days: 90);
      case HistoryRange.all:
        return (start: null, days: 30);
    }
  }

  List<DateTime> _lastNDays(DateTime endInclusive, int days) {
    final DateTime end = DateTime(endInclusive.year, endInclusive.month, endInclusive.day);
    return List<DateTime>.generate(
      days,
      (int i) => end.subtract(Duration(days: days - 1 - i)),
    );
  }

  String _rangeLabel(HistoryRange r, {required bool fil}) {
    switch (r) {
      case HistoryRange.last7:
        return fil ? 'Huling 7 araw' : 'Last 7 days';
      case HistoryRange.last30:
        return fil ? 'Huling 30 araw' : 'Last 30 days';
      case HistoryRange.last90:
        return fil ? 'Huling 90 araw' : 'Last 90 days';
      case HistoryRange.all:
        return fil ? 'Lahat' : 'All time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final String? uid = SupabaseClientProvider.instance.client.auth.currentUser?.id;

    return AppScaffold(
      title: fil
          ? 'Kasaysayan: ${widget.fieldName}'
          : 'History: ${widget.fieldName}',
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _db.getCapturedPhotosForField(
          fieldId: widget.fieldId,
          limit: 1000,
          userId: uid,
        ),
        builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<Map<String, dynamic>> rows = snap.data ?? const <Map<String, dynamic>>[];

          final ({DateTime? start, int days}) w = _rangeWindow();
          final DateTime now = DateTime.now();
          final DateTime? start = w.start == null
              ? null
              : DateTime(w.start!.year, w.start!.month, w.start!.day);

          final Iterable<Map<String, dynamic>> filtered = start == null
              ? rows
              : rows.where((row) {
                  final DateTime? dt = _parseCreatedAt(row['created_at']);
                  if (dt == null) return false;
                  return !dt.isBefore(start);
                });

          final List<Map<String, dynamic>> list = filtered.toList();

          final int scans = list.length;
          final int totalBugs = list.fold<int>(
            0,
            (int a, Map<String, dynamic> r) => a + ((r['count'] as num?)?.toInt() ?? 0),
          );
          final double avgBugs = scans == 0 ? 0 : totalBugs / scans;
          final int peakBugs = list.fold<int>(
            0,
            (int a, Map<String, dynamic> r) {
              final int c = ((r['count'] as num?)?.toInt() ?? 0);
              return c > a ? c : a;
            },
          );

          // Build daily counts for the chart.
          final List<DateTime> dates =
              _range == HistoryRange.all ? _lastNDays(now, 30) : _lastNDays(now, w.days);
          final Map<String, int> perDay = <String, int>{};
          for (final r in list) {
            final DateTime? dt = _parseCreatedAt(r['created_at']);
            if (dt == null) continue;
            final DateTime d = DateTime(dt.year, dt.month, dt.day);
            final String key = d.toIso8601String().substring(0, 10);
            perDay[key] = (perDay[key] ?? 0) + (((r['count'] as num?)?.toInt() ?? 0));
          }
          final List<int> dailyCounts = dates
              .map((d) => perDay[d.toIso8601String().substring(0, 10)] ?? 0)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _RangePicker(
                  value: _range,
                  onChanged: (HistoryRange v) => setState(() => _range = v),
                  labelBuilder: (r) => _rangeLabel(r, fil: fil),
                ),
                const SizedBox(height: 12),
                _StatsRow(
                  fil: fil,
                  scans: scans,
                  totalBugs: totalBugs,
                  avgBugs: avgBugs,
                  peakBugs: peakBugs,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  fil: fil,
                  title: fil
                      ? 'Araw-araw na bilang ng mealybug'
                      : 'Daily mealybug counts',
                  subtitle: fil
                      ? 'Base sa saved captures (offline-first)'
                      : 'Based on saved captures (offline-first)',
                  dates: dates,
                  dailyCounts: dailyCounts,
                ),
                const SizedBox(height: 12),
                _RecentList(
                  fil: fil,
                  rows: list.take(10).toList(),
                  parseCreatedAt: _parseCreatedAt,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.value,
    required this.onChanged,
    required this.labelBuilder,
  });

  final HistoryRange value;
  final ValueChanged<HistoryRange> onChanged;
  final String Function(HistoryRange r) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: HistoryRange.values.map((r) {
        final bool selected = r == value;
        return ChoiceChip(
          label: Text(labelBuilder(r)),
          selected: selected,
          onSelected: (_) => onChanged(r),
        );
      }).toList(),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.fil,
    required this.scans,
    required this.totalBugs,
    required this.avgBugs,
    required this.peakBugs,
  });

  final bool fil;
  final int scans;
  final int totalBugs;
  final double avgBugs;
  final int peakBugs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(
            label: fil ? 'Mga scan' : 'Scans',
            value: '$scans',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: fil ? 'Kabuuang bug' : 'Total bugs',
            value: '$totalBugs',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: fil ? 'Avg/scan' : 'Avg/scan',
            value: avgBugs.toStringAsFixed(1),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: fil ? 'Pinakamataas' : 'Peak',
            value: '$peakBugs',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.fil,
    required this.title,
    required this.subtitle,
    required this.dates,
    required this.dailyCounts,
  });

  final bool fil;
  final String title;
  final String subtitle;
  final List<DateTime> dates;
  final List<int> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasData = dailyCounts.any((c) => c > 0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          SizedBox(
            height: 200,
            child: hasData
                ? RepaintBoundary(
                    child: CustomPaint(
                      painter: _CountsLineChartPainter(
                        dates: dates,
                        dailyCounts: dailyCounts,
                        accent: cs.primary,
                        grid: cs.outline.withValues(alpha: 0.20),
                        tick: cs.onSurfaceVariant,
                        dotInner: cs.surface,
                        fil: fil,
                      ),
                      size: Size.infinite,
                    ),
                  )
                : Center(
                    child: Text(
                      fil ? 'Wala pang history para sa range na ito.' : 'No history for this range yet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountsLineChartPainter extends CustomPainter {
  _CountsLineChartPainter({
    required this.dates,
    required this.dailyCounts,
    required this.accent,
    required this.grid,
    required this.tick,
    required this.dotInner,
    required this.fil,
  });

  final List<DateTime> dates;
  final List<int> dailyCounts;
  final Color accent;
  final Color grid;
  final Color tick;
  final Color dotInner;
  final bool fil;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0 || dailyCounts.isEmpty) return;

    const double padLeft = 48;
    const double padRight = 12;
    const double padTop = 14;
    const double padBottom = 38;

    final double chartW = w - padLeft - padRight;
    final double chartH = h - padTop - padBottom;
    if (chartW <= 0 || chartH <= 0) return;

    final int pointCount = math.min(dates.length, dailyCounts.length);
    if (pointCount < 2) return;

    final int maxY = dailyCounts.fold<int>(0, (a, b) => a > b ? a : b);
    final double rangeY = maxY > 0 ? maxY.toDouble() : 1.0;

    final double xStep = chartW / (pointCount - 1);
    final List<Offset> pts = <Offset>[];
    for (int i = 0; i < pointCount; i++) {
      final double x = padLeft + i * xStep;
      final double y = padTop + chartH - (dailyCounts[i] / rangeY) * chartH;
      pts.add(Offset(x, y));
    }

    // Grid + y labels
    const int yTicks = 4;
    for (int i = 0; i <= yTicks; i++) {
      final double t = i / yTicks;
      final double y = padTop + chartH - t * chartH;
      final Paint p = Paint()
        ..color = grid
        ..strokeWidth = 1;
      canvas.drawLine(Offset(padLeft, y), Offset(padLeft + chartW, y), p);

      final double yValue = rangeY * t;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: yValue.round().toString(),
          style: TextStyle(fontSize: 11, color: tick),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padLeft - tp.width - 6, y - tp.height / 2));
    }

    // Smooth line + gradient fill
    final double baselineY = padTop + chartH;
    if (pts.length >= 2) {
      final Path area = buildMonotonicSmoothAreaPath(pts, baselineY);
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              accent.withValues(alpha: 0.18),
              accent.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, padTop, w, chartH)),
      );

      final Path path = buildMonotonicSmoothLinePath(pts);
      canvas.drawPath(
        path,
        Paint()
          ..color = accent
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Dots
    final Paint dotOuter = Paint()..color = accent;
    final Paint dotInnerPaint = Paint()..color = dotInner;
    for (final Offset o in pts) {
      canvas.drawCircle(o, 4.2, dotOuter);
      canvas.drawCircle(o, 2.2, dotInnerPaint);
    }

    // X-axis date labels
    final DateFormat fmt = DateFormat(fil ? 'MMM d' : 'MMM d');
    final int labelStep = xAxisLabelStep(pointCount);
    for (int i = 0; i < pointCount; i++) {
      if (i % labelStep != 0 && i != pointCount - 1) continue;
      final String label = fmt.format(dates[i]);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 9, color: tick),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: 52);
      tp.paint(
        canvas,
        Offset(pts[i].dx - tp.width / 2, baselineY + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountsLineChartPainter oldDelegate) {
    return oldDelegate.dailyCounts != dailyCounts || oldDelegate.dates != dates;
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.fil,
    required this.rows,
    required this.parseCreatedAt,
  });

  final bool fil;
  final List<Map<String, dynamic>> rows;
  final DateTime? Function(dynamic v) parseCreatedAt;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            fil ? 'Kamakailang scan' : 'Recent scans',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Text(
              fil ? 'Wala pang saved scans.' : 'No saved scans yet.',
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            ...rows.map((r) {
              final int c = (r['count'] as num?)?.toInt() ?? 0;
              final int conf = (r['confidence'] as num?)?.toInt() ?? 0;
              final DateTime? dt = parseCreatedAt(r['created_at']);
              final String when = dt == null
                  ? (fil ? 'Hindi alam ang oras' : 'Unknown time')
                  : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.bug_report_outlined, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fil
                            ? 'Bilang: $c · Kumpiyansa: $conf% · $when'
                            : 'Count: $c · Conf: $conf% · $when',
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

