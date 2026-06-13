/// Maps model-space boxes (letterboxed tensor) to original image pixels.
library;

import '../models/detection_result.dart';
import 'image_preprocessor.dart';

/// Raw box in model input space (typically letterboxed [inputSize]×[inputSize]).
///
/// [cx], [cy], [w], [h] may be in pixel space (0…[inputSize]) or normalized 0…1
/// depending on export; [transformModelBoxesToOriginal] detects normalized outputs.
class ModelBox {
  const ModelBox({
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    required this.confidence,
    required this.classIndex,
  });

  final double cx;
  final double cy;
  final double w;
  final double h;
  final double confidence;
  final int classIndex;
}

/// Heuristic: Ultralytics TFLite often exports xywh in 0…1 relative to input.
bool isLikelyNormalizedModelBox(double cx, double cy, double w, double h) {
  final double m = [cx, cy, w, h].reduce(
    (double a, double b) => a > b ? a : b,
  );
  return m <= 1.5;
}

/// Converts NMS outputs to [Detection]s in original image coordinates.
List<Detection> transformModelBoxesToOriginal(
  List<ModelBox> raw,
  PreprocessResult preprocess,
  int inputSize,
  List<String> classLabels,
) {
  final double scale = preprocess.scale;
  final double padLeft = preprocess.padLeft;
  final double padTop = preprocess.padTop;
  final double origW = preprocess.originalWidth.toDouble();
  final double origH = preprocess.originalHeight.toDouble();

  return raw.map((ModelBox r) {
    var cx = r.cx;
    var cy = r.cy;
    var width = r.w;
    var height = r.h;

    if (isLikelyNormalizedModelBox(cx, cy, width, height)) {
      cx *= inputSize;
      cy *= inputSize;
      width *= inputSize;
      height *= inputSize;
    }

    var left = cx - width / 2;
    var top = cy - height / 2;

    left = (left - padLeft) / scale;
    top = (top - padTop) / scale;
    width = width / scale;
    height = height / scale;

    left = left.clamp(0.0, origW);
    top = top.clamp(0.0, origH);
    width = width.clamp(0.0, origW - left);
    height = height.clamp(0.0, origH - top);

    final String label = r.classIndex < classLabels.length
        ? classLabels[r.classIndex]
        : 'Class ${r.classIndex}';

    return Detection(
      left: left,
      top: top,
      width: width,
      height: height,
      confidence: r.confidence,
      classIndex: r.classIndex,
      label: label,
    );
  }).toList();
}
