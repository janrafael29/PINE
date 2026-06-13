/// CustomPainter for drawing detection bounding boxes and labels.
///
/// Overlays detections on the displayed image with proper scaling
/// from model coordinates to screen coordinates.
library;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';

/// Paints bounding boxes and confidence labels on a canvas.
///
/// [detections] are in display coordinates (already scaled to match
/// the painted image size). [imageSize] is the size of the displayed
/// image for layout.
class BoundingBoxPainter extends CustomPainter {
  BoundingBoxPainter({
    required this.detections,
    required this.imageSize,
    this.boxColor = Colors.green,
    this.textColor = Colors.white,
    this.strokeWidth = 2.0,
  });

  final List<Detection> detections;
  final Size imageSize;
  final Color boxColor;
  final Color textColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      _drawBox(canvas, d);
      _drawLabel(canvas, d);
      _drawPinpoint(canvas, d);
    }
  }

  void _drawBox(Canvas canvas, Detection d) {
    final rect = Rect.fromLTWH(d.left, d.top, d.width, d.height);
    final paint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRect(rect, paint);
  }

  /// Center crosshair + small corner ticks for clearer localization.
  void _drawPinpoint(Canvas canvas, Detection d) {
    final double cx = d.left + d.width / 2;
    final double cy = d.top + d.height / 2;
    const double cross = 10.0;
    final Paint crossPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx - cross, cy),
      Offset(cx + cross, cy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - cross),
      Offset(cx, cy + cross),
      crossPaint,
    );

    final double tick = (strokeWidth * 2).clamp(4.0, 6.0);
    final Rect r = Rect.fromLTWH(d.left, d.top, d.width, d.height);
    final Paint tickPaint = Paint()
      ..color = boxColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 0.5
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(r.topLeft, r.topLeft + Offset(tick, 0), tickPaint);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, tick), tickPaint);
    canvas.drawLine(
      r.topRight,
      r.topRight + Offset(-tick, 0),
      tickPaint,
    );
    canvas.drawLine(
      r.topRight,
      r.topRight + Offset(0, tick),
      tickPaint,
    );
    canvas.drawLine(
      r.bottomLeft,
      r.bottomLeft + Offset(tick, 0),
      tickPaint,
    );
    canvas.drawLine(
      r.bottomLeft,
      r.bottomLeft + Offset(0, -tick),
      tickPaint,
    );
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + Offset(-tick, 0),
      tickPaint,
    );
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + Offset(0, -tick),
      tickPaint,
    );
  }

  void _drawLabel(Canvas canvas, Detection d) {
    final label = d.label ?? 'Class ${d.classIndex}';
    final score = (d.confidence * 100).toStringAsFixed(1);
    final text = '$label $score%';

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Background for label
    final bgRect = Rect.fromLTWH(
      d.left,
      d.top - textPainter.height - 4,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    final bgPaint = Paint()..color = boxColor;
    canvas.drawRect(bgRect, bgPaint);

    textPainter.paint(
      canvas,
      Offset(d.left + 4, d.top - textPainter.height - 2),
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageSize != imageSize;
  }
}
