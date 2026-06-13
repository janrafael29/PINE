/// Parse [fields.boundary_json] and sample a random point inside the ring.
library;

import 'dart:convert';
import 'dart:math';

class LatLngDeg {
  const LatLngDeg(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

List<LatLngDeg>? parseBoundaryRing(dynamic raw) {
  if (raw == null) return null;
  List<dynamic>? list;
  if (raw is String) {
    final String t = raw.trim();
    if (t.isEmpty) return null;
    try {
      list = jsonDecode(t) as List?;
    } catch (_) {
      return null;
    }
  } else if (raw is List) {
    list = raw;
  }
  if (list == null || list.length < 3) return null;
  final List<LatLngDeg> out = <LatLngDeg>[];
  for (final dynamic e in list) {
    if (e is! Map) continue;
    final Object? lat = e['lat'];
    final Object? lng = e['lng'];
    final double? la = lat is num ? lat.toDouble() : double.tryParse('$lat');
    final double? ln = lng is num ? lng.toDouble() : double.tryParse('$lng');
    if (la != null && ln != null) {
      out.add(LatLngDeg(la, ln));
    }
  }
  if (out.length < 3) return null;
  if (out.length > 3 &&
      out.first.latitude == out.last.latitude &&
      out.first.longitude == out.last.longitude) {
    return out.sublist(0, out.length - 1);
  }
  return out;
}

bool pointInPolygon(double lat, double lng, List<LatLngDeg> ring) {
  bool inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final double yi = ring[i].latitude;
    final double xi = ring[i].longitude;
    final double yj = ring[j].latitude;
    final double xj = ring[j].longitude;
    final bool intersect = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi);
    if (intersect) {
      inside = !inside;
    }
  }
  return inside;
}

LatLngDeg? randomPointInPolygon(List<LatLngDeg> ring, Random rng) {
  if (ring.length < 3) return null;
  double minLat = ring.first.latitude;
  double maxLat = ring.first.latitude;
  double minLng = ring.first.longitude;
  double maxLng = ring.first.longitude;
  for (final LatLngDeg p in ring) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  for (int k = 0; k < 120; k++) {
    final double lat = minLat + rng.nextDouble() * (maxLat - minLat);
    final double lng = minLng + rng.nextDouble() * (maxLng - minLng);
    if (pointInPolygon(lat, lng, ring)) {
      return LatLngDeg(lat, lng);
    }
  }
  double sLat = 0;
  double sLng = 0;
  for (final LatLngDeg p in ring) {
    sLat += p.latitude;
    sLng += p.longitude;
  }
  return LatLngDeg(sLat / ring.length, sLng / ring.length);
}

LatLngDeg? randomPointForFieldBoundary(dynamic boundaryJson, Random rng) {
  final List<LatLngDeg>? ring = parseBoundaryRing(boundaryJson);
  if (ring == null) return null;
  return randomPointInPolygon(ring, rng);
}
