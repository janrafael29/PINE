/// Renders a capture image with mealybug detection markers to PNG bytes.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../utils/oriented_image.dart';
import '../widgets/detection_markers_painter.dart';

Future<Uint8List?> renderDetectionOverlayPng({
  required Uint8List imageBytes,
  required List<Detection> detections,
}) async {
  try {
    final OrientedImageData? baked = bakeImageBytes(imageBytes);
    final Uint8List displayBytes = baked?.bytes ?? imageBytes;
    final ui.Codec codec = await ui.instantiateImageCodec(displayBytes);
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ui.Image image = frame.image;
    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());

    if (detections.isNotEmpty) {
      final ({Offset offset, double scale, Size drawnSize}) layout =
          detectionOverlayLayout(
        imageSize: imageSize,
        constraints: BoxConstraints.tight(imageSize),
      );
      final DetectionMarkersPainter painter = DetectionMarkersPainter(
        detections: detections,
        imageOffset: layout.offset,
        imageScale: layout.scale,
        drawPulseRing: false,
      );
      painter.paint(canvas, imageSize);
    }

    image.dispose();
    final ui.Picture picture = recorder.endRecording();
    final ui.Image out = await picture.toImage(image.width, image.height);
    final ByteData? bytes =
        await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    return bytes?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
