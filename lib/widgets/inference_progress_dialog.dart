// Minimum-duration analyzing overlay with a determinate progress bar (no numeric countdown).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/detection_result.dart';
import '../services/inference_service.dart';

/// Runs [InferenceService.runInference], shows a dialog for at least [minimumDisplay],
/// and drives a linear progress bar from 0→1 over that minimum window. If inference
/// takes longer, the bar stays at 100% and a short “still working” hint appears.
Future<DetectionResult> runInferenceWithProgressUi({
  required BuildContext context,
  required InferenceService inferenceService,
  required Uint8List imageBytes,
  required bool filipino,
  Duration minimumDisplay = const Duration(seconds: 5),
  double? detectionThresholdOverride,
}) async {
  final Stopwatch sw = Stopwatch()..start();
  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  final ValueNotifier<bool> stillWorking = ValueNotifier<bool>(true);

  final int minMs = minimumDisplay.inMilliseconds <= 0
      ? 1
      : minimumDisplay.inMilliseconds;
  final Timer ticker = Timer.periodic(const Duration(milliseconds: 120), (_) {
    progress.value =
        (sw.elapsedMilliseconds / minMs).clamp(0.0, 1.0);
  });

  if (!context.mounted) {
    ticker.cancel();
    progress.dispose();
    stillWorking.dispose();
    throw StateError('Context not mounted');
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      return PopScope(
        canPop: false,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (BuildContext context, double p, Widget? _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: stillWorking,
                  builder:
                      (BuildContext context, bool working, Widget? __) {
                    final bool slowHint = p >= 0.99 && working;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          filipino
                              ? 'Ina-analisa ang larawan…'
                              : 'Analyzing picture…',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: p.clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.black.withValues(alpha: 0.08),
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          filipino
                              ? 'Tinitingnan ang mealybugs, pakihintay…'
                              : 'Detecting mealybugs, please wait…',
                          style: const TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (slowHint) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            filipino
                                ? 'Medyo matagal — malaking larawan o mabagal na CPU.'
                                : 'Taking longer — large photo or slower device.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );

  try {
    await inferenceService.initialize();
    final DetectionResult result = await inferenceService.runInference(
      imageBytes,
      detectionThresholdOverride: detectionThresholdOverride,
    );
    stillWorking.value = false;

    final Duration elapsed = sw.elapsed;
    if (elapsed < minimumDisplay) {
      await Future<void>.delayed(minimumDisplay - elapsed);
    }
    progress.value = 1.0;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return result;
  } finally {
    ticker.cancel();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    progress.dispose();
    stillWorking.dispose();
  }
}
