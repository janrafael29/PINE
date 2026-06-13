/// Application-wide constants for the PINE pest detection app.
///
/// Centralizes magic numbers and strings for maintainability
/// and academic defensibility of design decisions.
library;

/// Model and inference constants.
abstract final class AppConstants {
  AppConstants._();

  /// Path to the TFLite model in assets.
  /// Export from Ultralytics YOLO (e.g. YOLO26); prefer float32 `.tflite` if float16 fails on-device (see export folder).
  static const String modelPath = 'assets/model/best.tflite';

  /// Shipped detector checkpoint (for support logs / thesis alignment).
  /// Source: `runs/retrain/mealybug_v16_selffix/weights/best.pt` → TFLite @ 640.
  static const String shippedModelId = 'mealybug_v16_selffix';

  /// YOLO inference input size. Must match TFLite export (`--export-imgsz 1280`).
  /// v16 trained @ 1280; shipped `best.tflite` is exported @ 1280 (see assets/model/README.md).
  static const int inputSize = 1280;

  /// Minimum confidence to show a detection and include it in the mealybug count.
  ///
  /// Confirmed tier: count, severity, save, and solid overlay boxes.
  static const double detectionThreshold = 0.25;

  /// Manual-check tier: dashed overlay only (0.12–0.24); not counted or saved.
  static const double manualCheckThreshold = 0.12;

  /// Minimum score returned from TFLite inference (enables two-tier UI).
  static const double inferenceFloorThreshold = 0.12;

  /// IoU threshold for Non-Max Suppression (NMS).
  /// Removes overlapping duplicate boxes. 0.45 is the standard YOLO default and
  /// matches the previous V2 build; higher values risk failing to suppress
  /// near-duplicate boxes, while much lower values can merge adjacent instances.
  static const double nmsThreshold = 0.45;

  /// Post-hoc **temperature scaling** on each box probability before NMS/threshold.
  ///
  /// - `1.0` = no change (default).
  /// - `T < 1.0` sharpens (higher confidences).
  /// - `T > 1.0` softens.
  ///
  /// Fit **T** on a labeled validation set (e.g. via calibration tooling); do not
  /// tune arbitrarily to force “90%” without data.
  static const double confidenceTemperature = 1.0;

  /// Maximum number of detections to return per inference.
  /// Limits memory and UI overhead on low-end devices.
  static const int maxDetections = 50;

  /// Number of threads for TFLite interpreter.
  /// Limited to avoid overwhelming 3GB RAM devices.
  static const int interpreterThreads = 2;

  /// Label for unknown class index (fallback).
  static const String unknownLabel = 'Unknown';

  // --- Sliding-window inference (train/serve scale mismatch) ---

  /// If true and the photo is large enough, run the model on overlapping
  /// **native-resolution crops** instead of only a full-frame letterbox.
  /// Helps when training used zoomed (large) pests but field photos show tiny pests.
  // Tiling massively increases compute (many crops). Keep it OFF by default for speed,
  // and enable only in "accuracy" mode or when explicitly needed.
  static const bool tiledInferenceEnabled = false;

  /// Minimum shorter side (px) of the decoded image to enable tiling.
  static const int tiledInferenceMinShortSide = 640;

  /// Crop size in **original image pixels** before letterboxing to [inputSize].
  /// Smaller crops = more upscaling into the tensor (better for very small pests).
  static const int tileNativeSide = 480;

  /// Overlap between adjacent tiles (0.2 = 20%).
  static const double tileOverlapFraction = 0.22;

  /// Cap tiles per photo for latency and RAM on mid-range phones.
  static const int maxTilesPerImage = 24;

  /// Per-tile NMS cap before merging (merged list is capped by [maxDetections]).
  static const int maxDetectionsPerTile = 48;

  /// Test-time augmentation: extra forward on H-flip (see [AppConfig.accuracy]).
  static const bool ttaEnabledDefault = false;
}
