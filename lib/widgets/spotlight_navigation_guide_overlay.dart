// Dims the screen and cuts out spotlight hole(s) over the real bottom navigation.
library;

import 'dart:async';

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../core/dashboard_guide_keys.dart';
import '../core/navigation_guide_content.dart';
import '../core/navigation_guide_sync.dart';
import '../core/theme.dart';
import '../screens/permission_screens.dart' show PhotoSourcePicker;

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.holes,
    required this.overlayColor,
    required this.ringColor,
    required this.enterT,
  });

  final List<RRect> holes;
  final Color overlayColor;
  final Color ringColor;
  final double enterT;

  static RRect _scaleHole(RRect hr, double scale) {
    final Rect o = hr.outerRect;
    final Offset c = o.center;
    final double w = (o.width * scale).clamp(24.0, double.infinity);
    final double h = (o.height * scale).clamp(24.0, double.infinity);
    final Rect r = Rect.fromCenter(center: c, width: w, height: h);
    final double rx = (hr.tlRadiusX * scale).clamp(4.0, 32.0);
    return RRect.fromRectAndRadius(r, Radius.circular(rx));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double curvedEnter = Curves.easeOutCubic.transform(enterT);
    final double enterScale = lerpDouble(0.82, 1.0, curvedEnter) ?? 1.0;

    final List<RRect> scaled = holes
        .map((RRect h) => _scaleHole(h, enterScale))
        .toList(growable: false);

    final Rect full = Offset.zero & size;
    // Performance: avoid repeated Path.combine() calls (very expensive on some
    // Android devices). Even-odd fill creates the same "holes" effect.
    final Path overlayPath = Path()..fillType = PathFillType.evenOdd;
    overlayPath.addRect(full);
    for (final RRect hr in scaled) {
      overlayPath.addRRect(hr);
    }
    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = ringColor;
    for (final RRect hr in scaled) {
      canvas.drawRRect(hr, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.holes != holes ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.enterT != enterT;
  }
}

/// On-dashboard tour: highlights measured widgets while dimming the rest.
class SpotlightNavigationGuideOverlay extends StatefulWidget {
  const SpotlightNavigationGuideOverlay({
    super.key,
    required this.onSkipToPreference,
    required this.onFinishedSteps,
  });

  final VoidCallback onSkipToPreference;
  final VoidCallback onFinishedSteps;

  @override
  State<SpotlightNavigationGuideOverlay> createState() =>
      _SpotlightNavigationGuideOverlayState();
}

class _SpotlightNavigationGuideOverlayState
    extends State<SpotlightNavigationGuideOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _step = 0;
  late final List<NavigationGuideSlide> _slides =
      navigationGuideSlidesForCurrentUser();
  List<RRect>? _holes;
  int _measureAttempts = 0;

  int _seqIndex = 0;
  bool _pageTransitioning = false;
  bool _measuring = false;
  int _measureGen = 0;
  Timer? _autoAdvanceTimer;
  DateTime _autoAdvanceDue = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _pausedAt;
  /// Tour opened [PhotoSourcePicker] so the sync button can be spotlighted.
  bool _guideAddPhotoRouteOpen = false;

  late final AnimationController _enterController;
  late final AnimationController _countdownController;

  static const int _maxMeasureAttempts = 24;
  // User preference: keep 4s per part, minimize animations.
  static const Duration _kSilentPartAdvance = Duration(seconds: 4);
  // Keep transitions smooth but lightweight (avoid “laggy” feel).
  static const Duration _kEnterDuration = Duration(milliseconds: 220);
  static const Duration _kExitDuration = Duration(milliseconds: 140);
  static const Duration _kCardMoveDuration = Duration(milliseconds: 200);

  void _cancelAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _synchronizeAddPhotoRouteWithSpotlightTarget() {
    final List<NavigationGuideSpotlightTarget> targets =
        _targetsForMeasurement();
    final bool wantSyncSpotlight = targets.isNotEmpty &&
        targets.first == NavigationGuideSpotlightTarget.addPhotoSync;

    if (wantSyncSpotlight && !_guideAddPhotoRouteOpen) {
      _guideAddPhotoRouteOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_guideAddPhotoRouteOpen) return;
        Navigator.of(context, rootNavigator: true).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const PhotoSourcePicker(),
          ),
        );
      });
      return;
    }

    if (!wantSyncSpotlight && _guideAddPhotoRouteOpen) {
      _guideAddPhotoRouteOpen = false;
      final NavigatorState? nav =
          Navigator.maybeOf(context, rootNavigator: true);
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
  }

  void _armNextAutoAdvance() {
    _autoAdvanceDue = DateTime.now().add(_kSilentPartAdvance);
    _ensureAutoAdvanceLoop();
    _countdownController.forward(from: 0);
  }

  void _ensureAutoAdvanceLoop() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (!mounted) return;
    Duration wait = _autoAdvanceDue.difference(DateTime.now());
    if (wait.isNegative) {
      wait = Duration.zero;
    }
    _autoAdvanceTimer = Timer(wait, _autoTick);
  }

  bool _holeListsRoughlyEqual(List<RRect> a, List<RRect> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].outerRect.center - b[i].outerRect.center).distance > 1.0) {
        return false;
      }
      if ((a[i].outerRect.width - b[i].outerRect.width).abs() > 1.0) {
        return false;
      }
      if ((a[i].outerRect.height - b[i].outerRect.height).abs() > 1.0) {
        return false;
      }
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
      _countdownController.stop();
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final Duration gap = DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        _autoAdvanceDue = _autoAdvanceDue.add(gap);
      }
      if (_countdownController.value > 0 && _countdownController.value < 1.0) {
        _countdownController.forward();
      }
      _ensureAutoAdvanceLoop();
    }
  }

  void _autoTick() {
    _autoAdvanceTimer = null;
    if (!mounted) return;

    final DateTime now = DateTime.now();
    if (now.isBefore(_autoAdvanceDue)) {
      _autoAdvanceTimer = Timer(_autoAdvanceDue.difference(now), _autoTick);
      return;
    }

    // If we're mid-transition, retry soon (can't advance safely).
    if (_pageTransitioning) {
      _autoAdvanceTimer = Timer(const Duration(milliseconds: 200), _autoTick);
      return;
    }

    // Past the deadline: advance even if measurement isn't stable.
    // This prevents the guide from stalling due to frame drops or user interference.
    if (_holes == null) {
      setState(() => _holes = <RRect>[]);
    }

    // Avoid triggering setState/navigation while Flutter is laying out widgets.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pageTransitioning) return;
      final NavigationGuideSlide liveSlide = _slides[_step];
      final List<NavigationGuideSpotlightTarget> liveSeq =
          liveSlide.spotlightSequence;
      final bool onLastSequencePart =
          liveSeq.isEmpty || _seqIndex >= liveSeq.length - 1;

      // ignore: discarded_futures
      if (!onLastSequencePart) {
        _advanceToNextSequencePart();
      } else {
        _goNext();
      }
    });
  }

  List<NavigationGuideSpotlightTarget> _targetsForMeasurement() {
    final NavigationGuideSlide slide = _slides[_step];
    if (slide.spotlightSequence.isNotEmpty) {
      return <NavigationGuideSpotlightTarget>[
        slide.spotlightSequence[_seqIndex],
      ];
    }
    return slide.spotlightTargets;
  }

  List<GlobalKey> _keysForCurrentTargets() {
    final DashboardGuideKeyHolder? holder = DashboardGuideKeyHolder.attached;
    if (holder == null) return const <GlobalKey>[];
    return holder.keysForTargets(_targetsForMeasurement());
  }

  Future<void> _scrollCurrentTargetsIntoView() async {
    for (final GlobalKey key in _keysForCurrentTargets()) {
      final BuildContext? ctx = key.currentContext;
      if (ctx == null) continue;
      try {
        await Scrollable.ensureVisible(
          ctx,
          // Avoid animated scrolling here: it can flood frames on slower devices
          // and trigger buffer starvation (BLASTBufferQueue).
          duration: Duration.zero,
          alignment: 0.32,
        );
      } catch (_) {
        // No scrollable ancestor (e.g. fixed bar) — safe to ignore.
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enterController = AnimationController(
      vsync: this,
      duration: _kEnterDuration,
    );
    _countdownController = AnimationController(
      vsync: this,
      duration: _kSilentPartAdvance,
    );
    NavigationGuideSync.activeStep.value = _step;
    _armNextAutoAdvance();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleMeasure());
  }

  @override
  void dispose() {
    if (_guideAddPhotoRouteOpen) {
      _guideAddPhotoRouteOpen = false;
      final NavigatorState? nav =
          Navigator.maybeOf(context, rootNavigator: true);
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
    }
    WidgetsBinding.instance.removeObserver(this);
    _cancelAutoAdvanceTimer();
    _enterController.dispose();
    _countdownController.dispose();
    NavigationGuideSync.activeStep.value = null;
    super.dispose();
  }

  void _scheduleMeasure() {
    final int myGen = ++_measureGen;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _synchronizeAddPhotoRouteWithSpotlightTarget();
      if (!mounted) return;
      if (_measuring) return;
      _measuring = true;
      // Keep the auto-advance loop alive even if measuring takes time.
      _ensureAutoAdvanceLoop();
      await _scrollCurrentTargetsIntoView();
      if (!mounted || myGen != _measureGen) {
        _measuring = false;
        return;
      }
      final List<RRect>? measured = _measureCurrentTargets();
      if (measured != null) {
        setState(() {
          _holes = measured;
          _measureAttempts = 0;
        });
        _enterController.forward(from: 0);
        // Keep auto-advance loop alive; timing is controlled by [_armNextAutoAdvance].
        _ensureAutoAdvanceLoop();
        // Re-measure once after the current frame settles. This improves
        // spotlight accuracy after scroll/relayout (common on slower devices).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _pageTransitioning) return;
          final List<RRect>? refined = _measureCurrentTargets();
          if (refined == null) return;
          final List<RRect>? cur = _holes;
          if (cur != null &&
              cur.length == refined.length &&
              _holeListsRoughlyEqual(cur, refined)) {
            return;
          }
          setState(() => _holes = refined);
        });
        _measuring = false;
        return;
      }
      _measureAttempts++;
      if (_measureAttempts < _maxMeasureAttempts) {
        _measuring = false;
        _scheduleMeasure();
      } else if (mounted) {
        // If we can't measure this target, don't stall the tour. Continue with
        // no holes and keep auto-advance running.
        setState(() {
          _holes = <RRect>[];
        });
        _ensureAutoAdvanceLoop();
        _measuring = false;
      }
    });
  }

  List<RRect>? _measureCurrentTargets() {
    final List<GlobalKey> keys = _keysForCurrentTargets();
    final List<RRect> out = <RRect>[];
    for (final GlobalKey key in keys) {
      final BuildContext? ctx = key.currentContext;
      if (ctx == null) return null;
      final RenderObject? ro = ctx.findRenderObject();
      final RenderBox? box = ro is RenderBox ? ro : null;
      if (box == null || !box.hasSize) return null;
      final Offset origin = box.localToGlobal(Offset.zero);
      final Rect r = (origin & box.size).inflate(10);
      out.add(RRect.fromRectAndRadius(r, const Radius.circular(16)));
    }
    return out;
  }

  Future<void> _advanceToNextSequencePart() async {
    final NavigationGuideSlide slide = _slides[_step];
    final List<NavigationGuideSpotlightTarget> seq = slide.spotlightSequence;
    if (seq.isEmpty || _seqIndex >= seq.length - 1) return;

    _pageTransitioning = true;
    try {
      await _enterController.animateTo(
        0,
        duration: _kExitDuration,
        curve: Curves.easeInCubic,
      );
      if (!mounted) return;
      setState(() {
        _seqIndex++;
        _holes = null;
        _measureAttempts = 0;
      });
      _armNextAutoAdvance();
      _scheduleMeasure();
    } finally {
      if (mounted) {
        _pageTransitioning = false;
      }
    }
  }

  Future<void> _goNext() async {
    if (_pageTransitioning) return;
    // Manual taps should not restart the 4s countdown.
    _ensureAutoAdvanceLoop();

    final NavigationGuideSlide slide = _slides[_step];
    final List<NavigationGuideSpotlightTarget> seq = slide.spotlightSequence;
    final bool hasSeq = seq.isNotEmpty;

    if (hasSeq && _seqIndex < seq.length - 1) {
      await _advanceToNextSequencePart();
      return;
    }

    if (_step >= _slides.length - 1) {
      NavigationGuideSync.activeStep.value = null;
      widget.onFinishedSteps();
      return;
    }

    _pageTransitioning = true;
    try {
      await _enterController.animateTo(
        0,
        duration: _kExitDuration,
        curve: Curves.easeInCubic,
      );
      if (!mounted) return;

      setState(() {
        _step++;
        _seqIndex = 0;
        _holes = null;
        _measureAttempts = 0;
      });
      NavigationGuideSync.activeStep.value = _step;
      _armNextAutoAdvance();
      _scheduleMeasure();
    } finally {
      if (mounted) {
        _pageTransitioning = false;
      }
    }
  }

  Future<void> _goBack() async {
    if (_pageTransitioning) return;
    // Manual taps should not restart the 4s countdown.
    _ensureAutoAdvanceLoop();

    final NavigationGuideSlide slide = _slides[_step];
    final List<NavigationGuideSpotlightTarget> seq = slide.spotlightSequence;
    final bool hasSeq = seq.isNotEmpty;

    final bool canActuallyGoBack = (hasSeq && _seqIndex > 0) || _step > 0;
    if (!canActuallyGoBack) {
      return;
    }

    if (hasSeq && _seqIndex > 0) {
      _pageTransitioning = true;
      try {
        await _enterController.animateTo(
          0,
          duration: _kExitDuration,
          curve: Curves.easeInCubic,
        );
        if (!mounted) return;
        setState(() {
          _seqIndex--;
          _holes = null;
          _measureAttempts = 0;
        });
        _armNextAutoAdvance();
        _scheduleMeasure();
      } finally {
        if (mounted) _pageTransitioning = false;
      }
      return;
    }

    _pageTransitioning = true;
    try {
      await _enterController.animateTo(
        0,
        duration: _kExitDuration,
        curve: Curves.easeInCubic,
      );
      if (!mounted) return;

      final int prevStep = _step - 1;
      final NavigationGuideSlide prevSlide = _slides[prevStep];
      final int prevSeqIndex = prevSlide.spotlightSequence.isNotEmpty
          ? prevSlide.spotlightSequence.length - 1
          : 0;

      setState(() {
        _step = prevStep;
        _seqIndex = prevSeqIndex;
        _holes = null;
        _measureAttempts = 0;
      });
      NavigationGuideSync.activeStep.value = _step;
      _armNextAutoAdvance();
      _scheduleMeasure();
    } finally {
      if (mounted) _pageTransitioning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size screenSize = mq.size;
    final NavigationGuideSlide slide = _slides[_step];

    Rect? union;
    if (_holes != null && _holes!.isNotEmpty) {
      union = _holes!.first.outerRect;
      for (int i = 1; i < _holes!.length; i++) {
        union = union!.expandToInclude(_holes![i].outerRect);
      }
    }

    final bool placeCardAbove = union != null &&
        union.center.dy > screenSize.height * 0.52;

    final bool seq = slide.spotlightSequence.isNotEmpty;
    final int seqLen = slide.spotlightSequence.length;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _enterController,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _SpotlightPainter(
                    holes: _holes ?? <RRect>[],
                    overlayColor: Colors.black.withValues(alpha: 0.55),
                    ringColor: Colors.white.withValues(alpha: 0.95),
                    enterT: _enterController.value,
                  ),
                  isComplex: true,
                  willChange: true,
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
          Positioned(
            top: mq.padding.top + 8,
            right: 12,
            child: TextButton(
              onPressed: widget.onSkipToPreference,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.95),
                backgroundColor: Colors.black.withValues(alpha: 0.24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  shadows: <Shadow>[
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: _kCardMoveDuration,
            curve: Curves.linear,
            left: 20,
            right: 20,
            top: placeCardAbove ? mq.padding.top + 52 : null,
            bottom: placeCardAbove ? null : mq.padding.bottom + 24,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _countdownController,
                builder: (BuildContext context, Widget? _) {
                  return _GuideCard(
                    slide: slide,
                    step: _step,
                    sequenceActive: seq,
                    sequenceIndex: _seqIndex,
                    sequenceLength: seqLen,
                    canGoBack: _step > 0 || (seq && _seqIndex > 0),
                    countdownT: _countdownController.value,
                    onBack: () {
                      // ignore: discarded_futures
                      _goBack();
                    },
                    onNext: () {
                      _goNext();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideCardContent extends StatelessWidget {
  const _GuideCardContent({
    required this.slide,
    required this.sequenceActive,
    required this.sequenceIndex,
  });

  final NavigationGuideSlide slide;
  final bool sequenceActive;
  final int sequenceIndex;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hint = Theme.of(context).hintColor;
    final List<({String text, bool highlight})> bodySegments =
        navigationGuideBodyForSpotlightStep(
      slide,
      sequenceActive: sequenceActive,
      sequenceIndex: sequenceIndex,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            slide.icon,
            size: 28,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        NavigationGuideBodyText(
          segments: bodySegments,
          baseStyle: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: hint,
          ),
        ),
        if (slide.icon == Icons.photo_camera) ...<Widget>[
          const SizedBox(height: 12),
          _CaptureTrialSample(),
        ],
      ],
    );
  }
}

/// Lightweight “practice framing” hint for the scan step (not a real camera).
class _CaptureTrialSample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return AspectRatio(
      // Keep this short so the user doesn't have to scroll on smaller screens.
      aspectRatio: 16 / 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.photo_camera_outlined,
              size: 34,
              color: AppTheme.primaryGreen.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 6),
            Text(
              'Quick trial — how to frame',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hint,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Hold steady, let the leaf fill most of the frame, and use good light before you tap capture.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: hint,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.slide,
    required this.step,
    required this.sequenceActive,
    required this.sequenceIndex,
    required this.sequenceLength,
    required this.canGoBack,
    required this.countdownT,
    required this.onBack,
    required this.onNext,
  });

  static const Duration _kSwitcherDuration = Duration(milliseconds: 160);

  final NavigationGuideSlide slide;
  final int step;
  final bool sequenceActive;
  final int sequenceIndex;
  final int sequenceLength;
  final bool canGoBack;
  final double countdownT;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final bool lastMainSlide =
        step >= navigationGuideSlidesForCurrentUser().length - 1;
    final bool morePartsOnSlide =
        sequenceActive && sequenceIndex < sequenceLength - 1;
    final String buttonLabel =
        (lastMainSlide && !morePartsOnSlide) ? 'Continue' : 'Next';

    final bool isCameraStep = slide.icon == Icons.photo_camera;
    final double maxCardHeight =
        MediaQuery.sizeOf(context).height * (isCameraStep ? 0.48 : 0.42);
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxCardHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedSwitcher(
                duration: _kSwitcherDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<String>('guide_${step}_$sequenceIndex'),
                  child: _GuideCardContent(
                    slide: slide,
                    sequenceActive: sequenceActive,
                    sequenceIndex: sequenceIndex,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canGoBack ? onBack : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.65),
                        ),
                        foregroundColor: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  // Drain from full -> empty as we approach auto-advance.
                  value: (1.0 - countdownT).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.55),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
