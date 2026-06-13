/// Heuristics to drop obvious non–mealybug boxes (faces, posters, huge regions).
library;

import '../models/detection_result.dart';

/// Max box width/height as a fraction of image size (field close-ups).
///
/// Mealybugs are small; face-sized boxes on selfies are typically >8%.
const double kMaxBoxSideFraction = 0.075;

/// Max box area as a fraction of full image (rejects large background blobs).
const double kMaxBoxAreaFraction = 0.04;

/// Drops boxes that are too large to plausibly be a mealybug instance.
List<Detection> filterPlausibleMealybugBoxes(
  List<Detection> detections, {
  required int imageWidth,
  required int imageHeight,
}) {
  if (imageWidth <= 0 || imageHeight <= 0 || detections.isEmpty) {
    return detections;
  }
  final double iw = imageWidth.toDouble();
  final double ih = imageHeight.toDouble();
  final double imgArea = iw * ih;

  return detections.where((Detection d) {
    if (d.width <= 0 || d.height <= 0) return false;
    final double rw = d.width / iw;
    final double rh = d.height / ih;
    if (rw > kMaxBoxSideFraction || rh > kMaxBoxSideFraction) {
      return false;
    }
    final double areaFrac = (d.width * d.height) / imgArea;
    if (areaFrac > kMaxBoxAreaFraction) return false;
    return true;
  }).toList();
}
