library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brighter center pin (teardrop) on top of the hex tint.
Color hexMarkerPinTint(Color base) {
  final HSLColor hsl = HSLColor.fromColor(base);
  return hsl
      .withSaturation((hsl.saturation + 0.12).clamp(0.0, 1.0))
      .withLightness((hsl.lightness + 0.10).clamp(0.2, 0.92))
      .toColor();
}

/// Hex-framed location pin (satellite-style): soft fill, dark outline, solid icon.
///
/// When [pulse] is true, only the hex outline/fill breathes slightly — no blur halo.
class HexPulseMarker extends StatefulWidget {
  const HexPulseMarker({
    super.key,
    required this.color,
    this.size = 26,
    this.pulse = true,
    this.icon,
  });

  final Color color;
  final double size;
  final bool pulse;
  final IconData? icon;

  @override
  State<HexPulseMarker> createState() => _HexPulseMarkerState();
}

class _HexPulseMarkerState extends State<HexPulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulse) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant HexPulseMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final double t = widget.pulse ? _c.value : 0.0;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _HexSatellitePinPainter(
            color: widget.color,
            t: t,
            pulse: widget.pulse,
          ),
          child: Center(
            child: Icon(
              widget.icon ?? Icons.location_on,
              size: widget.size * 0.56,
              color: hexMarkerPinTint(widget.color),
            ),
          ),
        );
      },
    );
  }
}

class _HexSatellitePinPainter extends CustomPainter {
  _HexSatellitePinPainter({
    required this.color,
    required this.t,
    required this.pulse,
  });

  final Color color;
  final double t;
  final bool pulse;

  Path _hexPath(Size size, double scale) {
    final Offset c = size.center(Offset.zero);
    final double r = (size.shortestSide / 2) * scale;
    final Path p = Path();
    for (int i = 0; i < 6; i++) {
      final double a = (math.pi / 3.0) * i - (math.pi / 2);
      final Offset pt = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double breathe = pulse ? (0.02 * math.sin(t * math.pi * 2)) : 0.0;
    final double hexScale = (0.88 + breathe).clamp(0.84, 0.92);
    final Path hex = _hexPath(size, hexScale);

    final Color borderColor =
        Color.lerp(color, const Color(0xFF152210), 0.42) ?? color;

    final double fillAlpha = (0.22 + (pulse ? 0.05 * (0.5 + 0.5 * math.sin(t * math.pi * 2)) : 0.0))
        .clamp(0.14, 0.34);
    final Paint fill = Paint()
      ..color = color.withValues(alpha: fillAlpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hex, fill);

    final Paint border = Paint()
      ..color = borderColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.15
      ..isAntiAlias = true;
    canvas.drawPath(hex, border);

    // Thin highlight on top half of hex (reads on aerial imagery like the reference).
    final Paint rim = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawPath(_hexPath(size, hexScale * 0.93), rim);
  }

  @override
  bool shouldRepaint(covariant _HexSatellitePinPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.t != t ||
        oldDelegate.pulse != pulse;
  }
}
