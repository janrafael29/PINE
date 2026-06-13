library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/detection_result.dart';

Future<void> showDetectionShowcaseDialog({
  required BuildContext context,
  required bool filipino,
  required String? imagePath,
  required Uint8List? imageBytes,
  required List<Detection> detections,
  required int? originalImageWidth,
  required int? originalImageHeight,
  required int overallConfidencePct,
  required int count,
  required String insightsTitle,
  required String insightsBody,
}) async {
  if (!context.mounted) return;
  await showGeneralDialog<void>(
    context: context,
    // Dismissing by tapping the barrier can race with the auto-advance timer and
    // AnimatedSwitcher transitions, which can destabilize semantics/layout in
    // some Flutter builds. Keep dismissal explicit via the Skip button.
    barrierDismissible: false,
    barrierLabel: 'Detection showcase',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (BuildContext dialogContext, _, __) {
      // Some Flutter builds can hit semantics/layout assertion loops when an
      // animated full-screen dialog is presented while the underlying route is
      // still settling. Excluding semantics for this decorative onboarding
      // overlay avoids that unstable codepath.
      return ExcludeSemantics(
        child: _DetectionShowcaseDialog(
          filipino: filipino,
          imagePath: imagePath,
          imageBytes: imageBytes,
          detections: detections,
          originalImageWidth: originalImageWidth,
          originalImageHeight: originalImageHeight,
          overallConfidencePct: overallConfidencePct,
          count: count,
          insightsTitle: insightsTitle,
          insightsBody: insightsBody,
        ),
      );
    },
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _DetectionShowcaseDialog extends StatefulWidget {
  const _DetectionShowcaseDialog({
    required this.filipino,
    required this.imagePath,
    required this.imageBytes,
    required this.detections,
    required this.originalImageWidth,
    required this.originalImageHeight,
    required this.overallConfidencePct,
    required this.count,
    required this.insightsTitle,
    required this.insightsBody,
  });

  final bool filipino;
  final String? imagePath;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final int? originalImageWidth;
  final int? originalImageHeight;
  final int overallConfidencePct;
  final int count;
  final String insightsTitle;
  final String insightsBody;

  @override
  State<_DetectionShowcaseDialog> createState() =>
      _DetectionShowcaseDialogState();
}

class _DetectionShowcaseDialogState extends State<_DetectionShowcaseDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pinPulse;
  late final AnimationController _cardMotion;
  late final PageController _pageController;
  Timer? _autoTimer;

  int _step = 0; // 0=image, 1=stats, 2=insights
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _pinPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _cardMotion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _pageController = PageController(initialPage: _step);
    _scheduleNext();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pinPulse.dispose();
    _cardMotion.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleNext() {
    _autoTimer?.cancel();
    _autoTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _closing) return;
      _advance();
    });
  }

  Future<void> _advance() async {
    if (_step >= 2) {
      await _close();
      return;
    }
    if (!mounted) return;
    final int next = _step + 1;
    // Animate current card down+shrink, swap page, then restore.
    try {
      await _cardMotion.forward(from: 0);
      if (!mounted) return;
      setState(() => _step = next);
      _pageController.jumpToPage(next);
      await _cardMotion.reverse(from: 1);
    } catch (_) {
      if (!mounted) return;
      setState(() => _step = next);
      _pageController.jumpToPage(next);
      _cardMotion.value = 0;
    }
    _scheduleNext();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _autoTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double maxW = math.min(420, screen.width - 32);
    final double maxH = math.min(620, screen.height - 80);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _cardMotion,
                      builder: (context, child) {
                        final double t =
                            Curves.easeInOutCubic.transform(_cardMotion.value);
                        final double scale = lerpDouble(1.0, 0.86, t)!;
                        final double dy = lerpDouble(0.0, 140.0, t)!;
                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        );
                      },
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: <Widget>[
                          Align(
                            alignment: Alignment.center,
                            child: _buildStepAt(context, 0),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: _buildStepAt(context, 1),
                          ),
                          Align(
                            alignment: Alignment.center,
                            child: _buildStepAt(context, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              child: _SkipButton(
                onPressed: _close,
                label: widget.filipino ? 'Laktawan' : 'Skip',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepAt(BuildContext context, int step) {
    switch (step) {
      case 0:
        return _StepCardShell(
          title: widget.filipino ? 'Nakita ang mealybugs' : 'Mealybugs pinpointed',
          subtitle: widget.filipino
              ? 'Tinitingnan ang larawan…'
              : 'Reviewing the detected spots…',
          child: _ShowcaseDetectionImage(
            imagePath: widget.imagePath,
            imageBytes: widget.imageBytes,
            detections: widget.detections,
            originalImageWidth: widget.originalImageWidth,
            originalImageHeight: widget.originalImageHeight,
            pulse: _pinPulse,
          ),
        );
      case 1:
        return _StepCardShell(
          title: widget.filipino ? 'Resulta ng scan' : 'Scan results',
          subtitle: widget.filipino
              ? 'Kumpiyansa at bilang ng nakita.'
              : 'Confidence and detected count.',
          child: _StatsCard(
            confidencePct: widget.overallConfidencePct,
            count: widget.count,
            filipino: widget.filipino,
          ),
        );
      default:
        return _StepCardShell(
          title: widget.insightsTitle,
          subtitle: widget.filipino
              ? 'Mga rekomendasyon pagkatapos ng scan.'
              : 'What to do next after the scan.',
          child: _InsightsCard(body: widget.insightsBody),
        );
    }
  }
}

class _StepCardShell extends StatelessWidget {
  const _StepCardShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ShowcaseDetectionImage extends StatelessWidget {
  const _ShowcaseDetectionImage({
    required this.imagePath,
    required this.imageBytes,
    required this.detections,
    required this.originalImageWidth,
    required this.originalImageHeight,
    required this.pulse,
  });

  final String? imagePath;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final int? originalImageWidth;
  final int? originalImageHeight;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double containerW = constraints.maxWidth;
            final double containerH = constraints.maxHeight;
            final double imageW = (originalImageWidth ?? 1).toDouble();
            final double imageH = (originalImageHeight ?? 1).toDouble();
            final double scale = math.min(containerW / imageW, containerH / imageH);
            final double drawnW = imageW * scale;
            final double drawnH = imageH * scale;
            final double offsetX = (containerW - drawnW) / 2;
            final double offsetY = (containerH - drawnH) / 2;

            final Widget imgWidget = imageBytes != null
                ? Image.memory(
                    imageBytes!,
                    fit: BoxFit.contain,
                    width: drawnW,
                    height: drawnH,
                    filterQuality: FilterQuality.medium,
                  )
                : (imagePath != null && imagePath!.isNotEmpty)
                    ? Image.file(
                        File(imagePath!),
                        fit: BoxFit.contain,
                        width: drawnW,
                        height: drawnH,
                        filterQuality: FilterQuality.medium,
                      )
                    : const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Icon(Icons.image_not_supported)),
                      );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.04),
                    child: Center(
                      child: SizedBox(width: drawnW, height: drawnH, child: imgWidget),
                    ),
                  ),
                ),
                if (detections.isNotEmpty)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _PinpointPainter(
                            detections: detections,
                            imageOffset: Offset(offsetX, offsetY),
                            imageScale: scale,
                            pulse: pulse.value,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinpointPainter extends CustomPainter {
  _PinpointPainter({
    required this.detections,
    required this.imageOffset,
    required this.imageScale,
    required this.pulse,
  });

  final List<Detection> detections;
  final Offset imageOffset;
  final double imageScale;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final Rect box = Rect.fromLTWH(
        imageOffset.dx + d.left * imageScale,
        imageOffset.dy + d.top * imageScale,
        d.width * imageScale,
        d.height * imageScale,
      );
      final Paint boxOutline = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        boxOutline,
      );

      final double cx = imageOffset.dx + (d.left + d.width / 2) * imageScale;
      final double cy = imageOffset.dy + (d.top + d.height / 2) * imageScale;
      final double ringRadius = 10 + pulse * 9;
      final double alpha = (1.0 - pulse).clamp(0.0, 1.0);

      final Paint ring = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.42 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      canvas.drawCircle(Offset(cx, cy), ringRadius, ring);

      final Paint dot = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), 4.8, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PinpointPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.imageOffset != imageOffset ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.pulse != pulse;
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.confidencePct,
    required this.count,
    required this.filipino,
  });

  final int confidencePct;
  final int count;
  final bool filipino;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppTheme.primaryGreen,
            AppTheme.secondaryGreen,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            filipino ? 'Kumpiyansa' : 'Confidence',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '$confidencePct%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 44,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.bug_report, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  filipino ? 'Bilang: $count' : 'Count: $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.body});

  final String body;

  @override
  Widget build(BuildContext context) {
    final Color bg = AppTheme.primaryGreen.withValues(alpha: 0.06);
    // Cap scroll height so the card hugs content instead of filling the PageView.
    final double maxScrollH =
        math.min(280.0, MediaQuery.sizeOf(context).height * 0.38);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bg,
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.20),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxScrollH),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Text(
            body,
            style: TextStyle(
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

