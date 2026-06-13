/// In-image markers for saved [Detection] boxes (mealybug pins / bounds).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import '../utils/oriented_image.dart';
import 'detection_markers_painter.dart';

/// Parses JSON from [captured_photo.detections_json] or Supabase `detections_json`.
List<Detection> parseStoredDetectionsJson(dynamic raw) {
  if (raw == null) return const <Detection>[];
  try {
    dynamic decoded = raw;
    if (raw is String) {
      final String s = raw.trim();
      if (s.isEmpty) return const <Detection>[];
      decoded = jsonDecode(s);
    }
    if (decoded is! List) return const <Detection>[];
    final List<dynamic> asList = decoded;
    return asList
        .whereType<Map>()
        .map((Map<dynamic, dynamic> m) => Map<String, dynamic>.from(m))
        .map(
          (Map<String, dynamic> m) => Detection(
            left: (m['left'] as num?)?.toDouble() ?? 0,
            top: (m['top'] as num?)?.toDouble() ?? 0,
            width: (m['width'] as num?)?.toDouble() ?? 0,
            height: (m['height'] as num?)?.toDouble() ?? 0,
            confidence: (m['confidence'] as num?)?.toDouble() ?? 0,
            classIndex: (m['classIndex'] as num?)?.toInt() ?? 0,
            label: m['label'] as String?,
          ),
        )
        .toList();
  } catch (_) {
    return const <Detection>[];
  }
}

/// Letterboxed image with detection boxes / pins overlaid.
class DetectionOverlayImage extends StatefulWidget {
  const DetectionOverlayImage({
    super.key,
    required this.imageBytes,
    required this.detections,
  });

  final Uint8List imageBytes;
  final List<Detection> detections;

  @override
  State<DetectionOverlayImage> createState() => _DetectionOverlayImageState();
}

class _DetectionOverlayImageState extends State<DetectionOverlayImage> {
  Size _decodedSize = const Size(1, 1);
  Uint8List _displayBytes = Uint8List(0);
  bool _decoded = false;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _decodeImageHeader();
  }

  @override
  void didUpdateWidget(covariant DetectionOverlayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      _decoded = false;
      _decodedSize = const Size(1, 1);
      // ignore: discarded_futures
      _decodeImageHeader();
    }
  }

  Future<void> _decodeImageHeader() async {
    try {
      final OrientedImageData? baked = bakeImageBytes(widget.imageBytes);
      if (baked != null && mounted) {
        setState(() {
          _displayBytes = baked.bytes;
          _decodedSize = baked.size;
          _decoded = true;
        });
        return;
      }
      final ui.Codec codec = await ui.instantiateImageCodec(widget.imageBytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final Size s = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      if (mounted) {
        setState(() {
          _displayBytes = widget.imageBytes;
          _decodedSize = s;
          _decoded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayBytes = widget.imageBytes;
          _decodedSize = const Size(1, 1);
          _decoded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_decoded) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final Size imageSize = _decodedSize;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ({Offset offset, double scale, Size drawnSize}) layout =
            detectionOverlayLayout(
          imageSize: imageSize,
          constraints: constraints,
        );
        final int memCacheW =
            (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                .round()
                .clamp(64, 4096);
        return Stack(
          children: <Widget>[
            Positioned(
              left: layout.offset.dx,
              top: layout.offset.dy,
              width: layout.drawnSize.width,
              height: layout.drawnSize.height,
              child: Image.memory(
                _displayBytes,
                fit: BoxFit.fill,
                width: layout.drawnSize.width,
                height: layout.drawnSize.height,
                cacheWidth: memCacheW,
              ),
            ),
            if (widget.detections.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: DetectionMarkersPainter(
                    detections: widget.detections,
                    imageOffset: layout.offset,
                    imageScale: layout.scale,
                    drawPulseRing: false,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
