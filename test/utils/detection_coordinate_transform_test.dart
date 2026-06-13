import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pine/models/detection_result.dart';
import 'package:pine/utils/detection_coordinate_transform.dart';
import 'package:pine/utils/image_preprocessor.dart';

void main() {
  group('isLikelyNormalizedModelBox', () {
    test('detects 0–1 range', () {
      expect(isLikelyNormalizedModelBox(0.5, 0.5, 0.1, 0.1), isTrue);
    });

    test('rejects pixel-scale coords', () {
      expect(isLikelyNormalizedModelBox(320, 240, 50, 50), isFalse);
    });
  });

  group('transformModelBoxesToOriginal', () {
    const int inputSize = 640;

    test('pixel-space box maps through letterbox to original', () {
      // Square 100×100 original → scale 6.4, no letterbox padding.
      final PreprocessResult preprocess = PreprocessResult(
        input: Float32List(0),
        scale: 6.4,
        padLeft: 0.0,
        padTop: 0.0,
        originalWidth: 100,
        originalHeight: 100,
      );

      // Box centered in 640 tensor: 288…352 → 45…55 in original pixels.
      final List<Detection> out = transformModelBoxesToOriginal(
        <ModelBox>[
          const ModelBox(
            cx: 320,
            cy: 320,
            w: 64,
            h: 64,
            confidence: 0.9,
            classIndex: 0,
          ),
        ],
        preprocess,
        inputSize,
        <String>['mealybug'],
      );

      expect(out, hasLength(1));
      expect(out[0].label, 'mealybug');
      expect(out[0].left, closeTo(45.0, 0.01));
      expect(out[0].top, closeTo(45.0, 0.01));
      expect(out[0].width, closeTo(10.0, 0.01));
      expect(out[0].height, closeTo(10.0, 0.01));
    });

    test('normalized box is scaled before inverse letterbox', () {
      final PreprocessResult preprocess = PreprocessResult(
        input: Float32List(0),
        scale: 1.0,
        padLeft: 0.0,
        padTop: 0.0,
        originalWidth: 640,
        originalHeight: 640,
      );

      final List<Detection> out = transformModelBoxesToOriginal(
        <ModelBox>[
          const ModelBox(
            cx: 0.5,
            cy: 0.5,
            w: 0.1,
            h: 0.1,
            confidence: 0.8,
            classIndex: 0,
          ),
        ],
        preprocess,
        inputSize,
        <String>['a'],
      );

      expect(out[0].left, closeTo(288.0, 0.01));
      expect(out[0].top, closeTo(288.0, 0.01));
      expect(out[0].width, closeTo(64.0, 0.01));
      expect(out[0].height, closeTo(64.0, 0.01));
    });
  });
}
