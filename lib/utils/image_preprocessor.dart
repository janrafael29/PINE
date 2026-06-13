/// Image preprocessing utilities for TFLite inference.
///
/// Handles resizing, normalization, and format conversion
/// required by YOLO TFLite models. Critical for small-object
/// detection accuracy.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Preprocesses images for YOLO TFLite input.
///
/// Pipeline:
/// 1. Resize to [inputSize]x[inputSize] (preserving aspect ratio with letterboxing)
/// 2. Normalize pixel values to [0, 1] or model-specific range
/// 3. Convert to Float32List in NCHW or NHWC format
///
/// Letterboxing avoids excessive compression that degrades small-object detection.
class ImagePreprocessor {
  ImagePreprocessor({required this.inputSize});

  /// Target input size (e.g., 640 for YOLO).
  final int inputSize;

  /// Preprocesses a [Uint8List] image (e.g., from camera) for inference.
  ///
  /// Returns (preprocessed Float32List, scale factor, padding offsets)
  /// for post-processing coordinate transformation.
  Future<PreprocessResult> preprocessFromBytes(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image');
    }
    final img.Image oriented = img.bakeOrientation(decoded);
    return preprocessFromImage(oriented);
  }

  /// Preprocesses an [img.Image] for inference.
  Future<PreprocessResult> preprocessFromImage(img.Image image) async {
    final originalWidth = image.width;
    final originalHeight = image.height;

    // Letterbox resize: fit image into inputSize x inputSize
    // while preserving aspect ratio. Reduces distortion for small objects.
    final scale = _computeScale(originalWidth, originalHeight);
    final scaledWidth = (originalWidth * scale).round();
    final scaledHeight = (originalHeight * scale).round();

    final resized = img.copyResize(
      image,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Create padded canvas (inputSize x inputSize)
    //
    // Ultralytics YOLO letterbox commonly pads with 114-gray. Matching that here
    // helps keep inference preprocessing aligned with training/validation.
    final padded = img.Image(width: inputSize, height: inputSize);
    const int padV = 114;
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        padded.setPixel(x, y, img.ColorRgb8(padV, padV, padV));
      }
    }
    final double padLeftRaw = (inputSize - scaledWidth) / 2.0;
    final double padTopRaw = (inputSize - scaledHeight) / 2.0;
    // compositeImage takes integer offsets; use the same rounded values for the
    // inverse transform so boxes align with the preview overlay.
    final int padLeftPx = padLeftRaw.round();
    final int padTopPx = padTopRaw.round();
    final double padLeft = padLeftPx.toDouble();
    final double padTop = padTopPx.toDouble();

    img.compositeImage(
      padded,
      resized,
      dstX: padLeftPx,
      dstY: padTopPx,
    );

    // Convert to Float32 NHWC, normalized to [0, 1]
    // YOLO TFLite typically expects normalized input.
    final floatBuffer = Float32List(inputSize * inputSize * 3);
    for (var y = 0; y < inputSize; y++) {
      for (var x = 0; x < inputSize; x++) {
        final pixel = padded.getPixel(x, y);
        final idx = (y * inputSize + x) * 3;
        floatBuffer[idx] = pixel.r / 255.0;
        floatBuffer[idx + 1] = pixel.g / 255.0;
        floatBuffer[idx + 2] = pixel.b / 255.0;
      }
    }

    return PreprocessResult(
      input: floatBuffer,
      scale: scale,
      padLeft: padLeft,
      padTop: padTop,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  double _computeScale(int w, int h) {
    final scaleW = inputSize / w;
    final scaleH = inputSize / h;
    return scaleW < scaleH ? scaleW : scaleH;
  }
}

/// Result of preprocessing, including transform metadata for post-processing.
class PreprocessResult {
  const PreprocessResult({
    required this.input,
    required this.scale,
    required this.padLeft,
    required this.padTop,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// Float32 input buffer (NHWC, normalized 0-1).
  final Float32List input;

  /// Scale factor applied during resize.
  final double scale;

  /// Left padding in letterbox (pixels, may be fractional for inverse transform).
  final double padLeft;

  /// Top padding in letterbox (pixels, may be fractional for inverse transform).
  final double padTop;

  /// Original image width.
  final int originalWidth;

  /// Original image height.
  final int originalHeight;
}
