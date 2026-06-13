library;

import 'package:flutter/material.dart';

import '../utils/severity_score.dart';

/// Radial glow + core pin; avoids multiple [BoxShadow] layers per marker (cheaper on maps).
class _SeverityGlowPainter extends CustomPainter {
  _SeverityGlowPainter({
    required this.severityColor,
    required this.outerRadius,
    required this.innerRadius,
    required this.coreRadius,
    required this.pulseAlpha,
    required this.glowAlpha,
  });

  final Color severityColor;
  final double outerRadius;
  final double innerRadius;
  final double coreRadius;
  final double pulseAlpha;
  final double glowAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height / 2);

    void drawHalo(double radius, double alphaBoost) {
      if (radius <= 0) return;
      final Paint p = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            severityColor.withValues(
              alpha: (glowAlpha * alphaBoost * pulseAlpha).clamp(0.0, 1.0),
            ),
            severityColor.withValues(alpha: 0),
          ],
          stops: const <double>[0.12, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: radius));
      canvas.drawCircle(c, radius, p);
    }

    drawHalo(outerRadius, 1.0);
    drawHalo(innerRadius, 1.15);

    final Paint coreFill = Paint()..color = Colors.white;
    canvas.drawCircle(c, coreRadius, coreFill);
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = severityColor;
    canvas.drawCircle(c, coreRadius, border);
  }

  @override
  bool shouldRepaint(covariant _SeverityGlowPainter oldDelegate) {
    return oldDelegate.severityColor != severityColor ||
        oldDelegate.outerRadius != outerRadius ||
        oldDelegate.innerRadius != innerRadius ||
        oldDelegate.coreRadius != coreRadius ||
        oldDelegate.pulseAlpha != pulseAlpha ||
        oldDelegate.glowAlpha != glowAlpha;
  }
}

class SeverityGlowMarker extends StatefulWidget {
  const SeverityGlowMarker({
    super.key,
    required this.severity01,
    this.baseSize = 18,
    this.pulse = true,
    this.showPinIcon = true,
  });

  final double severity01;
  final double baseSize;
  final bool pulse;
  final bool showPinIcon;

  @override
  State<SeverityGlowMarker> createState() => _SeverityGlowMarkerState();
}

class _SeverityGlowMarkerState extends State<SeverityGlowMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant SeverityGlowMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulse != widget.pulse) {
      if (widget.pulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.severity01.clamp(0.0, 1.0);
    final Color c = severityColor(s);
    final double outerR = glowRadiusPx(s);
    final double a = glowAlpha(s);

    return AnimatedBuilder(
      animation: _t,
      builder: (BuildContext context, Widget? child) {
        final double pulseMul = widget.pulse ? (0.92 + 0.16 * _t.value) : 1.0;
        final double pulseAlpha = widget.pulse ? (0.85 + 0.15 * _t.value) : 1.0;

        final double core = widget.baseSize;
        final double halo1 = outerR * pulseMul;
        final double halo2 = (outerR * 0.68) * pulseMul * 0.98;

        return CustomPaint(
          painter: _SeverityGlowPainter(
            severityColor: c,
            outerRadius: halo1,
            innerRadius: halo2,
            coreRadius: core / 2,
            pulseAlpha: pulseAlpha,
            glowAlpha: a,
          ),
          child: SizedBox(
            width: halo1 * 2,
            height: halo1 * 2,
            child: child,
          ),
        );
      },
      child: widget.showPinIcon
          ? Center(
              child: Icon(
                Icons.place,
                size: widget.baseSize * 0.72,
                color: c,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
