/// Runtime configuration for the PINE pest detection app.
///
/// Separates configurable behavior from constants.
/// Enables easy tuning for different device capabilities.
library;

import 'constants.dart';

/// Application configuration.
class AppConfig {
  AppConfig({
    this.inputSize = AppConstants.inputSize,
    this.detectionThreshold = AppConstants.detectionThreshold,
    this.nmsThreshold = AppConstants.nmsThreshold,
    this.confidenceTemperature = AppConstants.confidenceTemperature,
    this.maxDetections = AppConstants.maxDetections,
    this.interpreterThreads = AppConstants.interpreterThreads,
    this.modelPath = AppConstants.modelPath,
    this.tiledInferenceEnabled = AppConstants.tiledInferenceEnabled,
    this.tiledInferenceMinShortSide = AppConstants.tiledInferenceMinShortSide,
    this.tileNativeSide = AppConstants.tileNativeSide,
    this.tileOverlapFraction = AppConstants.tileOverlapFraction,
    this.maxTilesPerImage = AppConstants.maxTilesPerImage,
    this.maxDetectionsPerTile = AppConstants.maxDetectionsPerTile,
    this.ttaEnabled = AppConstants.ttaEnabledDefault,
  });

  AppConfig copyWith({
    int? inputSize,
    double? detectionThreshold,
    double? nmsThreshold,
    double? confidenceTemperature,
    int? maxDetections,
    int? interpreterThreads,
    String? modelPath,
    bool? tiledInferenceEnabled,
    int? tiledInferenceMinShortSide,
    int? tileNativeSide,
    double? tileOverlapFraction,
    int? maxTilesPerImage,
    int? maxDetectionsPerTile,
    bool? ttaEnabled,
  }) {
    return AppConfig(
      inputSize: inputSize ?? this.inputSize,
      detectionThreshold: detectionThreshold ?? this.detectionThreshold,
      nmsThreshold: nmsThreshold ?? this.nmsThreshold,
      confidenceTemperature: confidenceTemperature ?? this.confidenceTemperature,
      maxDetections: maxDetections ?? this.maxDetections,
      interpreterThreads: interpreterThreads ?? this.interpreterThreads,
      modelPath: modelPath ?? this.modelPath,
      tiledInferenceEnabled: tiledInferenceEnabled ?? this.tiledInferenceEnabled,
      tiledInferenceMinShortSide:
          tiledInferenceMinShortSide ?? this.tiledInferenceMinShortSide,
      tileNativeSide: tileNativeSide ?? this.tileNativeSide,
      tileOverlapFraction: tileOverlapFraction ?? this.tileOverlapFraction,
      maxTilesPerImage: maxTilesPerImage ?? this.maxTilesPerImage,
      maxDetectionsPerTile: maxDetectionsPerTile ?? this.maxDetectionsPerTile,
      ttaEnabled: ttaEnabled ?? this.ttaEnabled,
    );
  }

  /// Model input size (width and height).
  final int inputSize;

  /// Minimum confidence for detections.
  final double detectionThreshold;

  /// IoU threshold for NMS.
  final double nmsThreshold;

  /// Temperature scaling for box confidences (1.0 = off).
  final double confidenceTemperature;

  /// Maximum detections per inference.
  final int maxDetections;

  /// TFLite interpreter threads.
  final int interpreterThreads;

  /// Path to TFLite model asset.
  final String modelPath;

  /// Enable sliding-window inference on large photos.
  final bool tiledInferenceEnabled;

  /// Shorter side threshold (px) for enabling tiling.
  final int tiledInferenceMinShortSide;

  /// Tile size in original-image pixels.
  final int tileNativeSide;

  /// Tile overlap fraction.
  final double tileOverlapFraction;

  /// Maximum tiles per image.
  final int maxTilesPerImage;

  /// Max boxes kept per tile before global merge.
  final int maxDetectionsPerTile;

  /// Horizontal-flip test-time augmentation (identity + flip, merged with NMS).
  final bool ttaEnabled;

  /// Higher recall preset: tiled crops on large photos (stricter score floor).
  /// TTA off for ~2× speed; cap 24 tiles.
  factory AppConfig.accuracy() {
    return AppConfig(
      inputSize: AppConstants.inputSize,
      interpreterThreads: 2,
      maxDetections: 96,
      detectionThreshold: AppConstants.inferenceFloorThreshold,
      nmsThreshold: 0.50,
      tiledInferenceEnabled: true,
      tiledInferenceMinShortSide: 800,
      tileNativeSide: 416,
      tileOverlapFraction: 0.22,
      maxTilesPerImage: 24,
      maxDetectionsPerTile: 48,
      ttaEnabled: false,
    );
  }

  /// Creates a config optimized for low-end devices (3GB RAM).
  factory AppConfig.lowEnd() {
    return AppConfig(
      inputSize: AppConstants.inputSize,
      interpreterThreads: 1,
      maxDetections: 30,
      tiledInferenceEnabled: false,
      maxTilesPerImage: 16,
      maxDetectionsPerTile: 24,
      ttaEnabled: false,
    );
  }

  /// Creates a config for balanced devices.
  factory AppConfig.balanced() {
    return AppConfig(
      inputSize: AppConstants.inputSize,
      interpreterThreads: 2,
      maxDetections: 64,
      detectionThreshold: AppConstants.inferenceFloorThreshold,
      nmsThreshold: AppConstants.nmsThreshold,
    );
  }
}
