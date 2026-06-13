/// Sliding-window tile layout and NMS on [Detection] in full-image coordinates.
///
/// Used when the full frame is letterboxed to a small tensor: distant pests shrink
/// to a few pixels. Cropping native-resolution tiles restores apparent object size.
library;

import 'dart:math' as math;

import '../models/detection_result.dart';

/// One rectangular region of the source image (pixel coordinates).
class ImageTileSpec {
  const ImageTileSpec({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int x;
  final int y;
  final int width;
  final int height;
}

/// Builds overlapping grid coverage; widens stride until tile count ≤ [maxTiles].
List<ImageTileSpec> planImageTiles({
  required int imageWidth,
  required int imageHeight,
  required int tileSide,
  required double overlapFraction,
  required int maxTiles,
}) {
  if (imageWidth < 1 || imageHeight < 1) {
    return <ImageTileSpec>[];
  }
  final side = tileSide.clamp(64, 4096);
  var stride = math.max(
    1,
    (side * (1.0 - overlapFraction.clamp(0.0, 0.9))).round(),
  );

  List<ImageTileSpec> build(int s) {
    final out = <ImageTileSpec>[];
    for (var y = 0; y < imageHeight; y += s) {
      for (var x = 0; x < imageWidth; x += s) {
        final w = math.min(side, imageWidth - x);
        final h = math.min(side, imageHeight - y);
        if (w >= 32 && h >= 32) {
          out.add(ImageTileSpec(x: x, y: y, width: w, height: h));
        }
      }
    }
    return out;
  }

  var tiles = build(stride);
  while (tiles.length > maxTiles) {
    stride = math.max(stride + 1, (stride * 1.2).ceil());
    final next = build(stride);
    if (next.length >= tiles.length) {
      break;
    }
    tiles = next;
  }
  return tiles;
}

double _detectionIou(Detection a, Detection b) {
  final interLeft = math.max(a.left, b.left);
  final interTop = math.max(a.top, b.top);
  final interRight = math.min(a.right, b.right);
  final interBottom = math.min(a.bottom, b.bottom);
  final iw = (interRight - interLeft).clamp(0.0, double.infinity);
  final ih = (interBottom - interTop).clamp(0.0, double.infinity);
  final inter = iw * ih;
  final union = a.width * a.height + b.width * b.height - inter;
  return union > 0 ? inter / union : 0.0;
}

/// Greedy NMS on axis-aligned boxes in the same coordinate system (full image).
List<Detection> nmsMergedDetections(
  List<Detection> detections,
  double iouThreshold,
  int maxDetections,
) {
  if (detections.isEmpty) return detections;
  final sorted = List<Detection>.from(detections)
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  final kept = <Detection>[];
  for (final d in sorted) {
    if (kept.length >= maxDetections) break;
    var overlap = false;
    for (final k in kept) {
      if (_detectionIou(d, k) > iouThreshold) {
        overlap = true;
        break;
      }
    }
    if (!overlap) kept.add(d);
  }
  return kept;
}
