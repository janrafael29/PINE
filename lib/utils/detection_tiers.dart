/// Two-tier detection filters: confirmed (count/save) vs manual-check (overlay only).
library;

import '../core/constants.dart';
import '../models/detection_result.dart';

double get detectionThreshold => AppConstants.detectionThreshold;

double get manualCheckThreshold => AppConstants.manualCheckThreshold;

/// Same as [detectionThreshold] (legacy name for count/save call sites).
double get confirmedThreshold => AppConstants.detectionThreshold;

List<Detection> confirmedDetections(
  Iterable<Detection> all, {
  double? minConfidence,
}) {
  final double t = minConfidence ?? detectionThreshold;
  return all.where((d) => d.confidence >= t).toList();
}

/// Low-confidence candidates shown as dashed “inspect manually” boxes.
List<Detection> manualCheckDetections(Iterable<Detection> all) {
  return all
      .where(
        (d) =>
            d.confidence >= manualCheckThreshold &&
            d.confidence < detectionThreshold,
      )
      .toList();
}

/// All boxes drawn on the result image (confirmed + manual-check).
List<Detection> overlayDetections(Iterable<Detection> all) {
  return all.where((d) => d.confidence >= manualCheckThreshold).toList();
}

/// Primary count for severity / save — confirmed tier only.
int confirmedCount(Iterable<Detection> all, {double? minConfidence}) =>
    confirmedDetections(all, minConfidence: minConfidence).length;

int visibleCount(Iterable<Detection> all, {double? minConfidence}) =>
    confirmedCount(all, minConfidence: minConfidence);

List<Detection> filterVisible(
  Iterable<Detection> all, {
  double? minConfidence,
}) =>
    confirmedDetections(all, minConfidence: minConfidence);
