/// Bounding boxes and confidence labels on detection previews.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/detection_result.dart';

/// Paints detection boxes and markers in **display** coordinates (already scaled).
class DetectionMarkersPainter extends CustomPainter {
  DetectionMarkersPainter({
    required this.detections,
    required this.imageOffset,
    required this.imageScale,
    this.manualCheckDetections = const <Detection>[],
    this.pulse = 0.0,
    this.drawPulseRing = false,
  });

  final List<Detection> detections;
  final List<Detection> manualCheckDetections;
  final Offset imageOffset;
  final double imageScale;
  final double pulse;
  final bool drawPulseRing;

  static const Color _boxColor = AppTheme.primaryGreen;
  static const Color _manualColor = Color(0xFFF39C12);

  @override
  void paint(Canvas canvas, Size size) {
    final List<Rect> placedLabels = <Rect>[];

    for (final Detection d in manualCheckDetections) {
      _paintDetection(
        canvas: canvas,
        canvasSize: size,
        detection: d,
        placedLabels: placedLabels,
        boxColor: _manualColor,
        dashed: true,
        labelPrefix: '? ',
      );
    }

    for (final Detection d in detections) {
      final double left = imageOffset.dx + d.left * imageScale;
      final double top = imageOffset.dy + d.top * imageScale;
      final double w = d.width * imageScale;
      final double h = d.height * imageScale;
      if (w < 2 || h < 2) continue;

      final Rect box = Rect.fromLTWH(left, top, w, h);
      _paintDetection(
        canvas: canvas,
        canvasSize: size,
        detection: d,
        placedLabels: placedLabels,
        box: box,
        boxColor: _boxColor,
        dashed: false,
        labelPrefix: '',
      );
    }
  }

  void _paintDetection({
    required Canvas canvas,
    required Size canvasSize,
    required Detection detection,
    required List<Rect> placedLabels,
    required Color boxColor,
    required bool dashed,
    required String labelPrefix,
    Rect? box,
  }) {
    final double left = imageOffset.dx + detection.left * imageScale;
    final double top = imageOffset.dy + detection.top * imageScale;
    final double w = detection.width * imageScale;
    final double h = detection.height * imageScale;
    if (w < 2 || h < 2) return;
    final Rect rect = box ?? Rect.fromLTWH(left, top, w, h);
    _paintBox(canvas, rect, boxColor, dashed: dashed);
    _paintConfidenceLabel(
      canvas: canvas,
      canvasSize: canvasSize,
      detection: detection,
      box: rect,
      placedLabels: placedLabels,
      labelPrefix: labelPrefix,
      labelColor: boxColor,
    );
  }

  void _paintBox(Canvas canvas, Rect box, Color color, {bool dashed = false}) {
    final RRect rbox = RRect.fromRectAndRadius(box, const Radius.circular(6));

    canvas.drawRRect(
      rbox,
      Paint()
        ..color = color.withValues(alpha: dashed ? 0.10 : 0.14)
        ..style = PaintingStyle.fill,
    );
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 2.0 : 1.5;
    if (dashed) {
      stroke.strokeCap = StrokeCap.round;
      _drawDashedRRect(canvas, rbox, stroke);
    } else {
      canvas.drawRRect(
        rbox,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawRRect(rbox, stroke);
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rbox, Paint paint) {
    const double dash = 6;
    const double gap = 4;
    final Path path = Path()..addRRect(rbox);
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final double end = (dist + dash).clamp(0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dash + gap;
      }
    }
  }

  void _paintConfidenceLabel({
    required Canvas canvas,
    required Size canvasSize,
    required Detection detection,
    required Rect box,
    required List<Rect> placedLabels,
    String labelPrefix = '',
    Color labelColor = _boxColor,
  }) {
    final int pct =
        (detection.confidence * 100).round().clamp(0, 100);
    final String text = '$labelPrefix$pct%';

    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double padX = 5;
    const double padY = 3;
    final double bubbleW = tp.width + padX * 2;
    final double bubbleH = tp.height + padY * 2;

    final Rect bubble = _placeLabelNearBox(
      box: box,
      bubbleW: bubbleW,
      bubbleH: bubbleH,
      canvasSize: canvasSize,
      placed: placedLabels,
    );
    placedLabels.add(bubble.inflate(3));

    if (drawPulseRing) {
      final Offset anchor = Offset(box.center.dx, box.top);
      final double ringRadius = 9 + pulse * 8;
      final double alpha = (1.0 - pulse).clamp(0.0, 1.0);
      canvas.drawCircle(
        anchor,
        ringRadius,
        Paint()
          ..color = _boxColor.withValues(alpha: 0.35 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final RRect rrect = RRect.fromRectAndRadius(
      bubble,
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = labelColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(bubble.left + padX, bubble.top + padY));
  }

  /// Places the label near the top-left of the box, and avoids overlaps.
  Rect _placeLabelNearBox({
    required Rect box,
    required double bubbleW,
    required double bubbleH,
    required Size canvasSize,
    required List<Rect> placed,
  }) {
    const double gap = 6;
    final List<Offset> origins = <Offset>[
      // Inside top-left (preferred).
      Offset(box.left + gap, box.top + gap),
      // Just above the box.
      Offset(box.left, box.top - bubbleH - gap),
      // Top-right inside.
      Offset(box.right - bubbleW - gap, box.top + gap),
      // Below the box.
      Offset(box.left, box.bottom + gap),
    ];

    Rect? best;
    double bestDist = double.infinity;

    for (final Offset o in origins) {
      final Rect candidate = _clampRect(
        Rect.fromLTWH(o.dx, o.dy, bubbleW, bubbleH),
        canvasSize,
      );
      if (_overlapsAny(candidate, placed)) continue;
      final double d = (candidate.center - box.topLeft).distance;
      if (d < bestDist) {
        bestDist = d;
        best = candidate;
      }
    }

    if (best != null) return best;

    final Rect fallback = _clampRect(
      Rect.fromLTWH(
        box.left + gap,
        box.top + gap,
        bubbleW,
        bubbleH,
      ),
      canvasSize,
    );
    return fallback;
  }

  Rect _clampRect(Rect r, Size canvasSize) {
    double left = r.left;
    double top = r.top;
    if (left < 4) left = 4;
    if (top < 4) top = 4;
    if (left + r.width > canvasSize.width - 4) {
      left = canvasSize.width - r.width - 4;
    }
    if (top + r.height > canvasSize.height - 4) {
      top = canvasSize.height - r.height - 4;
    }
    return Rect.fromLTWH(left, top, r.width, r.height);
  }

  bool _overlapsAny(Rect r, List<Rect> placed) {
    final Rect inflated = r.inflate(2);
    for (final Rect other in placed) {
      if (inflated.overlaps(other.inflate(2))) return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant DetectionMarkersPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.manualCheckDetections != manualCheckDetections ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.pulse != pulse;
  }
}

/// Letterbox layout for an image of [imageSize] inside [constraints].
({Offset offset, double scale, Size drawnSize}) detectionOverlayLayout({
  required Size imageSize,
  required BoxConstraints constraints,
}) {
  final double scale = math.min(
    constraints.maxWidth / imageSize.width,
    constraints.maxHeight / imageSize.height,
  );
  final double drawnW = imageSize.width * scale;
  final double drawnH = imageSize.height * scale;
  return (
    offset: Offset(
      (constraints.maxWidth - drawnW) / 2,
      (constraints.maxHeight - drawnH) / 2,
    ),
    scale: scale,
    drawnSize: Size(drawnW, drawnH),
  );
}
