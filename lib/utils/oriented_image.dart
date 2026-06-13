/// Bake EXIF orientation so pixel layout matches inference coordinates.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// JPEG bytes with orientation applied; width/height match [Detection] boxes.
class OrientedImageData {
  const OrientedImageData({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;

  Size get size => Size(width.toDouble(), height.toDouble());
}

/// Returns null when [raw] cannot be decoded.
OrientedImageData? bakeImageBytes(Uint8List raw) {
  final img.Image? decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  final img.Image oriented = img.bakeOrientation(decoded);
  return OrientedImageData(
    bytes: Uint8List.fromList(img.encodeJpg(oriented, quality: 92)),
    width: oriented.width,
    height: oriented.height,
  );
}
