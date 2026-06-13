library;

import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';

double? _gpsRatiosToDecimal(IfdValues? values) {
  if (values == null || values is! IfdRatios) return null;
  double sum = 0;
  double unit = 1;
  for (final Ratio v in values.ratios) {
    sum += v.toDouble() * unit;
    unit /= 60;
  }
  return sum;
}

String? _compassRef(IfdTag? tag) {
  if (tag == null) return null;
  final String s = tag.printable.trim();
  if (s.isEmpty) return null;
  return s[0].toUpperCase();
}

/// Reads GPS latitude/longitude from JPEG/PNG/WebP/HEIC EXIF when present.
Future<({double lat, double lng})?> readGpsFromImage({
  Uint8List? bytes,
  String? path,
}) async {
  Uint8List? data = bytes;
  if (data == null || data.isEmpty) {
    final String? p = path?.trim();
    if (p == null || p.isEmpty) return null;
    final File f = File(p);
    if (!await f.exists()) return null;
    data = await f.readAsBytes();
  }
  if (data.isEmpty) return null;

  try {
    final Map<String, IfdTag> exif = await readExifFromBytes(data);
    if (exif.isEmpty) return null;

    final String? latRef = _compassRef(exif['GPS GPSLatitudeRef']);
    final String? lngRef = _compassRef(exif['GPS GPSLongitudeRef']);
    final double? latVal = _gpsRatiosToDecimal(exif['GPS GPSLatitude']?.values);
    final double? lngVal = _gpsRatiosToDecimal(exif['GPS GPSLongitude']?.values);

    if (latRef == null ||
        lngRef == null ||
        latVal == null ||
        lngVal == null) {
      return null;
    }
    if (latRef != 'N' && latRef != 'S') return null;
    if (lngRef != 'E' && lngRef != 'W') return null;

    double lat = latVal;
    double lng = lngVal;
    if (latRef == 'S') lat = -lat;
    if (lngRef == 'W') lng = -lng;

    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat.abs() > 90 || lng.abs() > 180) return null;

    return (lat: lat, lng: lng);
  } catch (_) {
    return null;
  }
}
