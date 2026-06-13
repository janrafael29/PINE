/// Camera service for capturing images for pest detection.
///
/// Handles camera initialization, image capture, and format conversion
/// for the inference pipeline.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

/// Manages camera lifecycle and image capture.
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  /// Whether the camera is initialized and ready.
  bool get isInitialized =>
      _controller != null && _controller!.value.isInitialized;

  /// The active camera controller.
  CameraController? get controller => _controller;

  /// Available cameras on the device.
  List<CameraDescription>? get cameras => _cameras;

  /// Initializes the camera. Prefer back camera for field use.
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    // Prefer back camera for outdoor/field pest detection
    final camera = _cameras!.length > 1
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first,
          )
        : _cameras!.first;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  /// Captures a photo and returns JPEG bytes for inference.
  Future<Uint8List> takePicture() async {
    if (!isInitialized) {
      throw StateError('Camera not initialized');
    }

    final file = await _controller!.takePicture();
    return file.readAsBytes();
  }

  /// Disposes the camera controller.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
