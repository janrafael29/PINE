/// Data models for object detection results.
///
/// Represents a single detection (bounding box + class + confidence)
/// and batch results from inference.
library;

/// A single detected object with bounding box and metadata.
class Detection {
  const Detection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.confidence,
    required this.classIndex,
    this.label,
  });

  /// Left coordinate of bounding box (in display coordinates).
  final double left;

  /// Top coordinate of bounding box (in display coordinates).
  final double top;

  /// Width of bounding box.
  final double width;

  /// Height of bounding box.
  final double height;

  /// Confidence score [0.0, 1.0].
  final double confidence;

  /// Class index from model output.
  final int classIndex;

  /// Human-readable label (e.g., "mealybug").
  final String? label;

  /// Right edge of bounding box.
  double get right => left + width;

  /// Bottom edge of bounding box.
  double get bottom => top + height;

  Detection copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
    double? confidence,
    int? classIndex,
    String? label,
  }) {
    return Detection(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      confidence: confidence ?? this.confidence,
      classIndex: classIndex ?? this.classIndex,
      label: label ?? this.label,
    );
  }
}

/// Container for all detections from a single inference run.
class DetectionResult {
  const DetectionResult({
    required this.detections,
    this.inferenceTimeMs,
    this.originalWidth,
    this.originalHeight,
    this.rawDetectionsCount,
    this.maxRawConfidence,
    this.outputShape,
    this.outputSample,
  });

  /// List of detections after NMS and threshold filtering.
  final List<Detection> detections;

  /// Inference duration in milliseconds (for profiling).
  final double? inferenceTimeMs;

  /// Original image width (for coordinate scaling).
  final int? originalWidth;

  /// Original image height (for coordinate scaling).
  final int? originalHeight;

  /// Number of detections before NMS/thresholding (debug).
  final int? rawDetectionsCount;

  /// Maximum confidence observed before thresholding (debug).
  final double? maxRawConfidence;

  /// Model output tensor shape (debug).
  final List<int>? outputShape;

  /// First few raw output values (debug).
  final List<double>? outputSample;
}
