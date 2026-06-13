// Unit tests for ImagePreprocessor (scale computation and preprocessing output shape).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pine/utils/image_preprocessor.dart';

void main() {
  group('ImagePreprocessor', () {
    const int inputSize = 640;

    test('preprocessFromBytes throws on invalid image bytes', () async {
      final preprocessor = ImagePreprocessor(inputSize: inputSize);
      final invalidBytes = Uint8List.fromList(<int>[0, 1, 2, 3]);
      expect(
        preprocessor.preprocessFromBytes(invalidBytes),
        throwsA(anything),
      );
    });

    test('preprocessFromImage produces correct buffer size and metadata', () async {
      final preprocessor = ImagePreprocessor(inputSize: inputSize);
      // Small test image 100x50
      final image = img.Image(width: 100, height: 50);
      for (var y = 0; y < 50; y++) {
        for (var x = 0; x < 100; x++) {
          image.setPixel(x, y, img.ColorRgb8(128, 128, 128));
        }
      }

      final result = await preprocessor.preprocessFromImage(image);

      expect(result.input.length, inputSize * inputSize * 3);
      expect(result.originalWidth, 100);
      expect(result.originalHeight, 50);
      expect(result.scale, greaterThan(0));
      expect(result.padLeft, greaterThanOrEqualTo(0));
      expect(result.padTop, greaterThanOrEqualTo(0));
    });

    test('preprocessFromImage normalizes pixel values to 0-1', () async {
      final preprocessor = ImagePreprocessor(inputSize: 32);
      final image = img.Image(width: 32, height: 32);
      for (var i = 0; i < 32 * 32; i++) {
        image.setPixel(i % 32, i ~/ 32, img.ColorRgb8(255, 0, 0));
      }

      final result = await preprocessor.preprocessFromImage(image);

      expect(result.input.length, 32 * 32 * 3);
      expect(result.input[0], closeTo(1.0, 0.01));
      expect(result.input[1], closeTo(0.0, 0.01));
      expect(result.input[2], closeTo(0.0, 0.01));
    });
  });

  group('PreprocessResult', () {
    test('holds transform metadata', () {
      final result = PreprocessResult(
        input: Float32List(0),
        scale: 0.5,
        padLeft: 10,
        padTop: 20,
        originalWidth: 100,
        originalHeight: 200,
      );
      expect(result.scale, 0.5);
      expect(result.padLeft, 10);
      expect(result.padTop, 20);
      expect(result.originalWidth, 100);
      expect(result.originalHeight, 200);
    });
  });
}
