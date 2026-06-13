// Splash/loading screen: branded logo, PINYA-PIC, tagline, loading bar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// App logo (PNG in placeholder pics folder).
const String kAppLogoAsset = 'assets/placeholder_pics/logo.png';

/// Taglines for the splash screen (first is primary; others available for reuse).
const List<String> kSplashTaglines = <String>[
  'Snap. Detect. Protect.',
  'Take a pic, save your crop.',
  'Pineapple pest detection at your fingertips.',
  'Spot mealybugs in a snap.',
];

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(
                  kAppLogoAsset,
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error,
                      StackTrace? stackTrace) {
                    return const _PineappleMagnifierLogo();
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'PINYA-PIC',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHeading,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kSplashTaglines.first,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textBody,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: double.infinity,
                    height: 6,
                    child: LinearProgressIndicator(
                      backgroundColor: AppTheme.taupe.withValues(alpha: 0.35),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppTheme.olive),
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fallback: stylized pineapple with magnifying glass overlay.
class _PineappleMagnifierLogo extends StatelessWidget {
  const _PineappleMagnifierLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _PineappleMagnifierPainter(),
      ),
    );
  }
}

class _PineappleMagnifierPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double bodyTop = h * 0.28;
    final double bodyBottom = h * 0.92;
    final double bodyHeight = bodyBottom - bodyTop;

    final RRect bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, bodyTop, w * 0.76, bodyHeight),
      const Radius.circular(20),
    );
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          AppTheme.accentYellow,
          AppTheme.accentYellow.withValues(alpha: 0.85),
        ],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    final Paint hexPaint = Paint()
      ..color = AppTheme.olive.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const double hexStep = 14;
    for (double y = bodyTop + 12; y < bodyBottom - 8; y += hexStep * 0.86) {
      for (double x = w * 0.18; x < w * 0.82; x += hexStep) {
        final double dx = (y - bodyTop).floor() ~/ (hexStep * 0.86) % 2 == 0
            ? 0
            : hexStep / 2;
        if (bodyRect.outerRect.contains(Offset(x + dx, y))) {
          canvas.drawCircle(Offset(x + dx, y), 2, hexPaint);
        }
      }
    }

    final Paint crownPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[AppTheme.olive, AppTheme.olive.withValues(alpha: 0.75)],
      ).createShader(Rect.fromLTWH(0, 0, w, bodyTop + 10));
    final Path crownPath = Path();
    crownPath.moveTo(cx - 28, bodyTop + 8);
    crownPath.lineTo(cx - 14, 4);
    crownPath.lineTo(cx, bodyTop);
    crownPath.lineTo(cx + 14, 4);
    crownPath.lineTo(cx + 28, bodyTop + 8);
    crownPath.lineTo(cx + 18, bodyTop + 6);
    crownPath.lineTo(cx, 14);
    crownPath.lineTo(cx - 18, bodyTop + 6);
    crownPath.close();
    canvas.drawPath(crownPath, crownPaint);
    final Paint crownStroke = Paint()
      ..color = AppTheme.olive.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(crownPath, crownStroke);

    final double lensCenterX = cx + 18;
    final double lensCenterY = bodyTop + bodyHeight * 0.35;
    const double lensRadius = 26;
    final Paint lensFramePaint = Paint()
      ..color = AppTheme.taupe
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(
        Offset(lensCenterX, lensCenterY), lensRadius, lensFramePaint);
    final Paint lensFillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
        Offset(lensCenterX, lensCenterY), lensRadius - 2, lensFillPaint);

    const double handleAngle = -math.pi / 4;
    const double handleLength = 32;
    final double handleEndX =
        lensCenterX + math.cos(handleAngle) * (lensRadius + handleLength);
    final double handleEndY =
        lensCenterY + math.sin(handleAngle) * (lensRadius + handleLength);
    final Paint handlePaint = Paint()
      ..color = AppTheme.textBody
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(
        lensCenterX + math.cos(handleAngle) * lensRadius,
        lensCenterY + math.sin(handleAngle) * lensRadius,
      ),
      Offset(handleEndX, handleEndY),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
