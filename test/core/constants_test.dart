// Unit tests for AppConstants.

import 'package:flutter_test/flutter_test.dart';
import 'package:pine/core/constants.dart';

void main() {
  group('AppConstants', () {
    test('modelPath is non-empty and points to assets', () {
      expect(AppConstants.modelPath, isNotEmpty);
      expect(AppConstants.modelPath, contains('assets/model'));
    });

    test('inputSize matches shipped v16 TFLite export', () {
      expect(AppConstants.inputSize, 1280);
    });

    test('detectionThreshold is in 0-1 range', () {
      expect(AppConstants.detectionThreshold, inInclusiveRange(0.0, 1.0));
    });

    test('nmsThreshold is in 0-1 range', () {
      expect(AppConstants.nmsThreshold, inInclusiveRange(0.0, 1.0));
    });

    test('maxDetections and interpreterThreads are positive', () {
      expect(AppConstants.maxDetections, greaterThan(0));
      expect(AppConstants.interpreterThreads, greaterThan(0));
    });

    test('unknownLabel is non-empty', () {
      expect(AppConstants.unknownLabel, isNotEmpty);
    });
  });
}
