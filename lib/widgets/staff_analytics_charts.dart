/// Custom chart painters for staff analytics (donut, line, horizontal bar).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/smooth_line_chart_path.dart';

const Color kStaffAnalyticsOlive = Color(0xFF76944C);
const Color kStaffAnalyticsTaupe = Color(0xFFC0B6AC);

class StaffDonutChart extends StatelessWidget {
  const StaffDonutChart({
    super.key,
    required this.positive,
    required this.negative,
    required this.centerLabel,
    required this.centerValue,
  });

  final int positive;
  final int negative;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(positive: positive, negative: negative),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              centerValue,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              centerLabel,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.positive, required this.negative});

  final int positive;
  final int negative;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = (positive + negative).toDouble();
    if (total <= 0) {
      final Paint empty = Paint()
        ..color = kStaffAnalyticsTaupe.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: math.min(size.width, size.height) / 2 - 8,
        ),
        0,
        math.pi * 2,
        false,
        empty,
      );
      return;
    }

    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - 8,
    );
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    double start = -math.pi / 2;
    final double posSweep = (positive / total) * math.pi * 2;
    if (positive > 0) {
      paint.color = kStaffAnalyticsOlive;
      canvas.drawArc(rect, start, posSweep, false, paint);
      start += posSweep;
    }
    if (negative > 0) {
      paint.color = kStaffAnalyticsTaupe;
      canvas.drawArc(rect, start, math.pi * 2 - posSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.positive != positive || oldDelegate.negative != negative;
}

class StaffLineTrendChart extends StatelessWidget {
  const StaffLineTrendChart({
    super.key,
    required this.counts,
    required this.labels,
    required this.accentColor,
    required this.emptyLabel,
  });

  final List<int> counts;
  final List<String> labels;
  final Color accentColor;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final bool hasData = counts.any((int c) => c > 0);
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 180,
      child: hasData
          ? CustomPaint(
              painter: _LineTrendPainter(
                counts: counts,
                labels: labels,
                accentColor: accentColor,
                gridColor: cs.outline.withValues(alpha: 0.15),
                labelColor: cs.onSurfaceVariant,
                surfaceColor: cs.surface,
              ),
              size: Size.infinite,
            )
          : Center(
              child: Text(
                emptyLabel,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ),
    );
  }
}

class _LineTrendPainter extends CustomPainter {
  _LineTrendPainter({
    required this.counts,
    required this.labels,
    required this.accentColor,
    required this.gridColor,
    required this.labelColor,
    required this.surfaceColor,
  });

  final List<int> counts;
  final List<String> labels;
  final Color accentColor;
  final Color gridColor;
  final Color labelColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    const double padL = 32;
    const double padR = 10;
    const double padT = 12;
    const double padB = 26;
    final double w = size.width - padL - padR;
    final double h = size.height - padT - padB;
    final double baselineY = padT + h;

    final int maxVal = counts.fold<int>(0, math.max).clamp(1, 999999);
    final double stepX = counts.length <= 1 ? w : w / (counts.length - 1);

    for (int g = 0; g <= 3; g++) {
      final double y = padT + h * g / 3;
      canvas.drawLine(
        Offset(padL, y),
        Offset(size.width - padR, y),
        Paint()..color = gridColor..strokeWidth = 1,
      );
    }

    final List<Offset> points = <Offset>[];
    for (int i = 0; i < counts.length; i++) {
      final double x = padL + stepX * i;
      final double y = padT + h * (1 - counts[i] / maxVal);
      points.add(Offset(x, y));
    }

    if (points.length >= 2) {
      final Path area = buildMonotonicSmoothAreaPath(points, baselineY);
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              accentColor.withValues(alpha: 0.22),
              accentColor.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(0, padT, size.width, h)),
      );

      final Path line = buildMonotonicSmoothLinePath(points);
      canvas.drawPath(
        line,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      final Paint dotOuter = Paint()..color = accentColor;
      final Paint dotInner = Paint()..color = surfaceColor;
      for (final Offset p in points) {
        canvas.drawCircle(p, 3.5, dotOuter);
        canvas.drawCircle(p, 2, dotInner);
      }
    }

    final int labelStep = xAxisLabelStep(labels.length);
    for (int i = 0; i < labels.length; i++) {
      if (labels[i].isEmpty) continue;
      if (i % labelStep != 0 && i != labels.length - 1) continue;
      final double x = padL + stepX * i;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 9, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 44);
      tp.paint(canvas, Offset(x - tp.width / 2, baselineY + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineTrendPainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.labels != labels;
}

class StaffHorizontalBarChart extends StatelessWidget {
  const StaffHorizontalBarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.accentColor,
    required this.emptyLabel,
  });

  final List<String> labels;
  final List<int> values;
  final Color accentColor;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty || !values.any((int v) => v > 0)) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            emptyLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final int maxVal = values.fold<int>(0, math.max).clamp(1, 999999);
    return Column(
      children: List<Widget>.generate(labels.length, (int i) {
        final double share = values[i] / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 72,
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 18,
                    backgroundColor:
                        accentColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 32,
                child: Text(
                  '${values[i]}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
