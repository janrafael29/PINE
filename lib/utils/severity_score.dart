library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Returns a normalized severity score in [0,1] from a combo of bug count and
/// confidence percent.
///
/// Uses a saturating curve so extreme values don't create absurdly large glows.
double severity01({
  required int bugCount,
  required int confidencePct,
  double k = 8.0,
}) {
  final int c = confidencePct.clamp(0, 100);
  final int b = math.max(0, bugCount);
  final double raw = b * (c / 100.0);
  if (raw <= 0) return 0.0;
  final double s = 1.0 - math.exp(-raw / k);
  return s.clamp(0.0, 1.0);
}

/// Color ramp for severity score.
Color severityColor(double s) {
  final double v = s.clamp(0.0, 1.0);
  if (v < 0.25) return const Color(0xFF2ECC71); // green
  if (v < 0.55) return const Color(0xFFF1C40F); // yellow
  if (v < 0.8) return const Color(0xFFF39C12); // orange
  return const Color(0xFFE74C3C); // red
}

/// Suggested pixel radius for the glow, scaled by severity.
double glowRadiusPx(double s, {double min = 14, double max = 42}) {
  final double v = s.clamp(0.0, 1.0);
  return min + (max - min) * v;
}

/// Suggested alpha for outer glow.
double glowAlpha(double s, {double min = 0.12, double max = 0.38}) {
  final double v = s.clamp(0.0, 1.0);
  return min + (max - min) * v;
}

