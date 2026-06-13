/// Geo-fencing service: point-in-polygon for land boundary matching.
///
/// All computation on-device. No cloud. Determines whether a
/// detection (lat, lng) falls inside any defined land polygon.
library;

import '../models/land.dart';

/// Ray-casting point-in-polygon ([latitude], [longitude]) vs [polygon] vertices.
/// Ring may be open or closed (duplicate first/last point).
bool pointInPolygonForRing(
  double latitude,
  double longitude,
  List<LatLngPoint> polygon,
) {
  if (polygon.length < 3) return false;

  var inside = false;
  final int n = polygon.length;
  var j = n - 1;

  for (var i = 0; i < n; i++) {
    final double xi = polygon[i].longitude;
    final double yi = polygon[i].latitude;
    final double xj = polygon[j].longitude;
    final double yj = polygon[j].latitude;

    if (((yi > latitude) != (yj > latitude)) &&
        (longitude < (xj - xi) * (latitude - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
    j = i;
  }

  return inside;
}

bool _sameLatLngPoint(LatLngPoint a, LatLngPoint b) {
  return (a.latitude - b.latitude).abs() < 1e-8 &&
      (a.longitude - b.longitude).abs() < 1e-8;
}

/// Drops a closing duplicate of the first vertex when present.
List<LatLngPoint> openFieldBoundaryRing(List<LatLngPoint> ring) {
  if (ring.length < 4) return List<LatLngPoint>.from(ring);
  if (_sameLatLngPoint(ring.first, ring.last)) {
    return ring.sublist(0, ring.length - 1);
  }
  return List<LatLngPoint>.from(ring);
}

LatLngPoint _ringCentroid(List<LatLngPoint> ring) {
  double slat = 0;
  double slng = 0;
  for (final LatLngPoint p in ring) {
    slat += p.latitude;
    slng += p.longitude;
  }
  final double inv = 1.0 / ring.length;
  return LatLngPoint(slat * inv, slng * inv);
}

/// True when two segments cross in their relative interiors (not at shared endpoints only).
bool _segmentsCrossStrict(
  LatLngPoint a1,
  LatLngPoint a2,
  LatLngPoint b1,
  LatLngPoint b2,
) {
  const double eps = 1e-10;
  final double x1 = a1.longitude;
  final double y1 = a1.latitude;
  final double x2 = a2.longitude;
  final double y2 = a2.latitude;
  final double x3 = b1.longitude;
  final double y3 = b1.latitude;
  final double x4 = b2.longitude;
  final double y4 = b2.latitude;
  final double rxd = x2 - x1;
  final double ryd = y2 - y1;
  final double sxd = x4 - x3;
  final double syd = y4 - y3;
  final double den = rxd * syd - ryd * sxd;
  if (den.abs() < 1e-14) {
    return false;
  }
  final double qpx = x3 - x1;
  final double qpy = y3 - y1;
  final double t = (qpx * syd - qpy * sxd) / den;
  final double u = (qpx * ryd - qpy * rxd) / den;
  return t > eps && t < 1 - eps && u > eps && u < 1 - eps;
}

/// True when two simple field rings have overlapping interiors.
///
/// Lat/lng are treated as a flat plane, which is acceptable for small parcels.
/// Touching only along an edge or at a corner is treated as non-overlap.
bool fieldBoundaryRingsOverlap(List<LatLngPoint> a, List<LatLngPoint> b) {
  if (a.length < 3 || b.length < 3) {
    return false;
  }
  final List<LatLngPoint> ra = openFieldBoundaryRing(a);
  final List<LatLngPoint> rb = openFieldBoundaryRing(b);
  if (ra.length < 3 || rb.length < 3) {
    return false;
  }

  final LatLngPoint cA = _ringCentroid(ra);
  final LatLngPoint cB = _ringCentroid(rb);
  if (pointInPolygonForRing(cA.latitude, cA.longitude, rb)) {
    return true;
  }
  if (pointInPolygonForRing(cB.latitude, cB.longitude, ra)) {
    return true;
  }

  for (final LatLngPoint p in ra) {
    if (pointInPolygonForRing(p.latitude, p.longitude, rb)) {
      return true;
    }
  }
  for (final LatLngPoint p in rb) {
    if (pointInPolygonForRing(p.latitude, p.longitude, ra)) {
      return true;
    }
  }

  for (int i = 0; i < ra.length; i++) {
    final LatLngPoint p1 = ra[i];
    final LatLngPoint p2 = ra[(i + 1) % ra.length];
    for (int j = 0; j < rb.length; j++) {
      final LatLngPoint q1 = rb[j];
      final LatLngPoint q2 = rb[(j + 1) % rb.length];
      if (_segmentsCrossStrict(p1, p2, q1, q2)) {
        return true;
      }
    }
  }
  return false;
}

/// Result of geo-fence lookup.
class GeoFenceResult {
  const GeoFenceResult({
    this.land,
    this.landId,
    this.isInside = false,
  });

  final Land? land;
  final int? landId;
  final bool isInside;
}

/// Service for point-in-polygon geo-fencing.
class GeoFenceService {
  /// Finds which land (if any) contains the given point.
  ///
  /// Returns [GeoFenceResult] with land when inside a boundary,
  /// or isInside=false when outside all boundaries.
  GeoFenceResult findLandForPoint(
    double latitude,
    double longitude,
    List<Land> lands,
  ) {
    for (final land in lands) {
      if (_pointInPolygon(latitude, longitude, land.polygonCoordinates)) {
        return GeoFenceResult(
          land: land,
          landId: land.id,
          isInside: true,
        );
      }
    }
    return const GeoFenceResult(isInside: false);
  }

  /// Public helper for checking a single polygon.
  bool isPointInsideLand(double latitude, double longitude, Land land) {
    return _pointInPolygon(latitude, longitude, land.polygonCoordinates);
  }

  /// Ray-casting point-in-polygon algorithm.
  /// Returns true if (lat, lng) is inside the polygon.
  bool _pointInPolygon(
    double lat,
    double lng,
    List<LatLngPoint> polygon,
  ) {
    return pointInPolygonForRing(lat, lng, polygon);
  }
}
