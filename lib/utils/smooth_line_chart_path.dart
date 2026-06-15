/// Smooth monotonic cubic paths for line charts (no baseline overshoot).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Builds a smooth stroke path through [points] using cubic segments that
/// stay within each segment's Y bounds (prevents dips below flat baselines).
Path buildMonotonicSmoothLinePath(List<Offset> points, {double tension = 5}) {
  final Path path = Path();
  if (points.isEmpty) return path;
  if (points.length == 1) {
    path.moveTo(points.first.dx, points.first.dy);
    return path;
  }
  path.moveTo(points.first.dx, points.first.dy);
  for (int i = 0; i < points.length - 1; i++) {
    final Offset p0 = i > 0 ? points[i - 1] : points[i];
    final Offset p1 = points[i];
    final Offset p2 = points[i + 1];
    final Offset p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
    _appendMonotonicCubic(path, p0, p1, p2, p3, tension: tension);
  }
  return path;
}

/// Closed fill path from [baselineY] up through the smooth line.
Path buildMonotonicSmoothAreaPath(
  List<Offset> points,
  double baselineY, {
  double tension = 5,
}) {
  if (points.isEmpty) return Path();
  final Path area = Path()
    ..moveTo(points.first.dx, baselineY)
    ..lineTo(points.first.dx, points.first.dy);
  for (int i = 0; i < points.length - 1; i++) {
    final Offset p0 = i > 0 ? points[i - 1] : points[i];
    final Offset p1 = points[i];
    final Offset p2 = points[i + 1];
    final Offset p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];
    _appendMonotonicCubic(area, p0, p1, p2, p3, tension: tension);
  }
  area
    ..lineTo(points.last.dx, baselineY)
    ..close();
  return area;
}

void _appendMonotonicCubic(
  Path path,
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3, {
  required double tension,
}) {
  final double t = tension;
  double cp1x = p1.dx + (p2.dx - p0.dx) / t;
  double cp1y = p1.dy + (p2.dy - p0.dy) / t;
  double cp2x = p2.dx - (p3.dx - p1.dx) / t;
  double cp2y = p2.dy - (p3.dy - p1.dy) / t;

  final double minY = math.min(p1.dy, p2.dy);
  final double maxY = math.max(p1.dy, p2.dy);
  cp1y = cp1y.clamp(minY, maxY);
  cp2y = cp2y.clamp(minY, maxY);

  // Flat segment — horizontal tangent keeps the line smooth without wobble.
  if ((p1.dy - p2.dy).abs() < 0.5) {
    cp1y = p1.dy;
    cp2y = p2.dy;
  }

  path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
}

/// Picks a step so at most ~6 x-axis labels are drawn.
int xAxisLabelStep(int pointCount) {
  if (pointCount <= 7) return 1;
  if (pointCount <= 14) return 2;
  if (pointCount <= 30) return 5;
  if (pointCount <= 60) return 10;
  return (pointCount / 6).ceil().clamp(1, pointCount);
}
