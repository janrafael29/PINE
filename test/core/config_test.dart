// Unit tests for AppConfig and factory constructors.

import 'package:flutter_test/flutter_test.dart';
import 'package:pine/core/config.dart';
import 'package:pine/core/constants.dart';

void main() {
  group('AppConfig', () {
    test('default constructor uses AppConstants values', () {
      final config = AppConfig();
      expect(config.inputSize, AppConstants.inputSize);
      expect(config.detectionThreshold, AppConstants.detectionThreshold);
      expect(config.nmsThreshold, AppConstants.nmsThreshold);
      expect(config.confidenceTemperature, AppConstants.confidenceTemperature);
      expect(config.maxDetections, AppConstants.maxDetections);
      expect(config.interpreterThreads, AppConstants.interpreterThreads);
      expect(config.modelPath, AppConstants.modelPath);
    });

    test('lowEnd factory sets expected values for low-end devices', () {
      final config = AppConfig.lowEnd();
      expect(config.inputSize, AppConstants.inputSize);
      expect(config.interpreterThreads, 1);
      expect(config.maxDetections, 30);
    });

    test('balanced factory sets expected values', () {
      final config = AppConfig.balanced();
      expect(config.inputSize, AppConstants.inputSize);
      expect(config.interpreterThreads, 2);
      expect(config.maxDetections, 64);
      // Balanced defaults may be tuned for field performance; keep this test in
      // sync with AppConfig.balanced().
      expect(config.detectionThreshold, AppConstants.inferenceFloorThreshold);
      expect(config.nmsThreshold, AppConstants.nmsThreshold);
    });

    test('custom constructor overrides apply', () {
      final config = AppConfig(
        inputSize: 320,
        detectionThreshold: 0.25,
        modelPath: 'custom/model.tflite',
      );
      expect(config.inputSize, 320);
      expect(config.detectionThreshold, 0.25);
      expect(config.modelPath, 'custom/model.tflite');
    });

    test('accuracy factory favors recall via tiling and looser NMS', () {
      final AppConfig config = AppConfig.accuracy();
      expect(config.detectionThreshold, AppConstants.inferenceFloorThreshold);
      expect(config.nmsThreshold, greaterThan(AppConstants.nmsThreshold));
      expect(config.ttaEnabled, isFalse);
      expect(config.tileNativeSide, 416);
      expect(config.tiledInferenceEnabled, isTrue);
      expect(config.maxDetections, 96);
    });
  });
}
