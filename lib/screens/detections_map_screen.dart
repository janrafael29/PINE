library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/admin_session.dart';
import '../core/map_tiles.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import '../models/detection_result.dart';
import '../models/land.dart';
import '../services/database_service.dart';
import '../services/geo_fence_service.dart';
import '../services/supabase_detection_field_counts.dart';
import '../widgets/app_scaffold.dart';
import '../screens/captured_photo_detail_screen.dart';
import '../utils/severity_score.dart';
import '../widgets/esri_imagery_tile_layer.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/detection_overlay_image.dart';
import '../widgets/hex_pulse_marker.dart';
import '../widgets/online_required_dialog.dart';
import '../utils/detection_report_status.dart';

class _FieldsSheetAgg {
  const _FieldsSheetAgg({
    required this.labels,
    required this.detectionsByField,
    required this.imagesByField,
  });

  final Map<String, String> labels;
  final Map<String, int> detectionsByField;
  final Map<String, int> imagesByField;
}

Future<_FieldsSheetAgg> _loadFieldsSheetAgg(List<String> ownerIds) async {
  final Map<String, String> labels = currentUserJwtStaff()
      ? await fetchProfileOwnerLabelsForUserIds(ownerIds)
      : const <String, String>{};
  try {
    final SupabaseFieldDetectionAggregates agg =
        await fetchSupabaseFieldDetectionAggregatesByFieldId();
    return _FieldsSheetAgg(
      labels: labels,
      detectionsByField: agg.rowsByField,
      imagesByField: agg.imagesByField,
    );
  } catch (_) {
    return _FieldsSheetAgg(
      labels: labels,
      detectionsByField: const <String, int>{},
      imagesByField: const <String, int>{},
    );
  }
}

/// Parses "lat, lng" or "lat lng" into [LatLng], or null if not a coordinate pair.
LatLng? _parseDetectionsMapLatLngQuery(String raw) {
  final String s = raw.trim();
  if (s.isEmpty) return null;
  final List<String> byComma = s.split(',');
  if (byComma.length == 2) {
    final double? lat = double.tryParse(byComma[0].trim());
    final double? lng = double.tryParse(byComma[1].trim());
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }
  }
  final RegExp twoNums = RegExp(
    r'^(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)$',
  );
  final RegExpMatch? m = twoNums.firstMatch(s);
  if (m != null) {
    final double? lat = double.tryParse(m.group(1)!);
    final double? lng = double.tryParse(m.group(2)!);
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return LatLng(lat, lng);
    }
  }
  return null;
}

class DetectionsMapScreen extends StatefulWidget {
  const DetectionsMapScreen({
    super.key,
    this.fieldId,
    this.fieldName,
    this.initialShowGeoFence = true,
    this.initialShowGrid = false,
    this.initialMapCenter,
    this.focusInitialCenter = false,
  });

  final String? fieldId;
  final String? fieldName;
  final bool initialShowGeoFence;
  final bool initialShowGrid;

  /// When set (e.g. after a new scan save), center the map on this point once.
  final LatLng? initialMapCenter;

  /// If true with [initialMapCenter], zooms to the pin after the first frame.
  final bool focusInitialCenter;

  @override
  State<DetectionsMapScreen> createState() => _DetectionsMapScreenState();
}

class _DetectionsMapScreenState extends State<DetectionsMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late bool _showGrid;
  final double _cellSizeM = 25.0;
  late bool _showGeoFence;
  String? _selectedFieldId;
  String? _selectedFieldName;

  /// When true, show only detections with null `field_id` (full stream, filtered in UI).
  bool _unassignedOnly = false;

  /// After picking a Fields filter, fit the map to pins (or fence / default) once.
  bool _pendingFitToPins = false;

  /// Avoids overlapping async fits when [StreamBuilder] fires repeatedly.
  bool _selectionCameraFitInFlight = false;

  final DatabaseService _db = DatabaseService();
  final GeoFenceService _geoFence = GeoFenceService();
  late Future<List<Land>> _landsFuture;

  /// Memoize heatmap polygons so pan/zoom rebuilds don't re-aggregate every frame.
  int? _cachedGridSig;
  List<Polygon> _cachedGridPolys = <Polygon>[];

  /// Current map zoom (updated from [MapOptions.onPositionChanged]) for marker sizing.
  double _mapLiveZoom = 15;

  /// Below this zoom: field heatmap only; at/above: individual positive pins.
  static const double _pinZoomThreshold = 15.0;

  /// Supabase field rows (id + name) for field-level heatmap tinting.
  List<Map<String, dynamic>> _fieldsRows = <Map<String, dynamic>>[];

  static const double _earthRadiusM = 6378137.0;

  /// Smaller pins when zoomed in; larger minimum so captures stay visible on phones.
  static double _pinPixelSizeForZoom(double zoom) {
    const double zRef = 15.25;
    const double base = 26;
    final double z = zoom.clamp(3.0, 22.0);
    final double s = base * math.pow(2, zRef - z);
    return s.clamp(18.0, 42.0);
  }

  static double _markerHitBoxForPinSize(double pinSize) =>
      (pinSize * 2.35).clamp(38.0, 82.0);

  void _onDetectionsMapPositionChanged(MapPosition pos, bool hasGesture) {
    final double? z = pos.zoom;
    if (z == null) return;
    if ((_mapLiveZoom - z).abs() < 0.035) return;
    setState(() => _mapLiveZoom = z);
  }

  /// Convert meters north/south to delta-lat degrees.
  double _metersToLatDeg(double meters) =>
      (meters / _earthRadiusM) * (180.0 / 3.141592653589793);

  /// Convert meters east/west to delta-lng degrees at a given latitude.
  double _metersToLngDeg(double meters, double atLatDeg) {
    final double latRad = atLatDeg * (3.141592653589793 / 180.0);
    final double denom =
        _earthRadiusM * (math.cos(latRad)).clamp(0.000001, 1.0);
    return (meters / denom) * (180.0 / 3.141592653589793);
  }

  /// Equirectangular approximation: degrees -> meters around a reference lat.
  Offset _latLngToMeters({
    required double lat,
    required double lng,
    required double refLat,
    required double refLng,
  }) {
    final double dLat = (lat - refLat) * (3.141592653589793 / 180.0);
    final double dLng = (lng - refLng) * (3.141592653589793 / 180.0);
    final double refLatRad = refLat * (3.141592653589793 / 180.0);
    final double x = _earthRadiusM * dLng * math.cos(refLatRad);
    final double y = _earthRadiusM * dLat;
    return Offset(x, y);
  }

  Color _heatColor(double s01) {
    final double s = s01.clamp(0.0, 1.0);
    // High-contrast green → yellow → red (readable on satellite tiles).
    final int r = (56 + (231 - 56) * math.pow(s, 0.85)).round();
    final int g = (192 + (76 - 192) * s).round();
    final int b = (100 + (60 - 100) * s).round();
    return Color.fromARGB(255, r, g, b);
  }

  @override
  void initState() {
    super.initState();
    _showGrid = widget.initialShowGrid;
    _showGeoFence = widget.initialShowGeoFence;
    _selectedFieldId = widget.fieldId?.trim().isNotEmpty == true
        ? widget.fieldId?.trim()
        : null;
    _selectedFieldName = widget.fieldName?.trim().isNotEmpty == true
        ? widget.fieldName?.trim()
        : null;
    if ((_selectedFieldId?.trim().isNotEmpty ?? false) ||
        (_selectedFieldName?.trim().isNotEmpty ?? false)) {
      _pendingFitToPins = true;
    }
    _landsFuture = _loadLands();
    if (widget.focusInitialCenter && widget.initialMapCenter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(widget.initialMapCenter!, 17);
      });
    }
  }

  LatLng? _highlightedFenceCenter(List<Land> lands, {String? fieldName}) {
    final String? targetName = fieldName?.trim();
    if (targetName == null || targetName.isEmpty) return null;
    final Land? land = lands.cast<Land?>().firstWhere(
          (l) =>
              l != null &&
              l.landName.trim().toLowerCase() == targetName.toLowerCase() &&
              l.polygonCoordinates.length >= 3,
          orElse: () => null,
        );
    if (land == null) return null;
    double latSum = 0;
    double lngSum = 0;
    int n = 0;
    for (final p in land.polygonCoordinates) {
      latSum += p.latitude;
      lngSum += p.longitude;
      n++;
    }
    if (n == 0) return null;
    return LatLng(latSum / n, lngSum / n);
  }

  Future<List<Land>> _loadLands() async {
    await _db.initialize();
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid != null && await NetworkReachability.isOnline()) {
      try {
        final List<Map<String, dynamic>> rows = await fieldsSelectForSession();
        _fieldsRows = rows;
        final List<Map<String, dynamic>> slim = rows
            .map(
              (Map<String, dynamic> r) => <String, dynamic>{
                'name': r['name'],
                'boundary_json': r['boundary_json'],
              },
            )
            .toList();
        await _db.importFieldBoundariesFromSupabaseRows(slim);
      } catch (_) {
        // Local land rows still used if fetch fails.
      }
    }
    return _db.getAllLands();
  }

  Future<void> _animateToCamera({
    required LatLng center,
    required double zoom,
    Duration duration = const Duration(milliseconds: 450),
    Curve curve = Curves.easeInOutCubic,
  }) async {
    final MapCamera from = _mapController.camera;
    final double fromZoom = from.zoom;
    final LatLng fromCenter = from.center;

    final AnimationController controller =
        AnimationController(vsync: this, duration: duration);
    final Animation<double> t =
        CurvedAnimation(parent: controller, curve: curve);

    void tick() {
      final double v = t.value;
      final double z = fromZoom + (zoom - fromZoom) * v;
      final LatLng c = LatLng(
        fromCenter.latitude + (center.latitude - fromCenter.latitude) * v,
        fromCenter.longitude + (center.longitude - fromCenter.longitude) * v,
      );
      _mapController.move(c, z);
    }

    controller.addListener(tick);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.removeListener(tick);
        controller.dispose();
      }
    });

    tick();
    await controller.forward();
  }

  Future<void> _fitCameraAnimated(CameraFit fit) async {
    final MapCamera from = _mapController.camera;

    // Use flutter_map's fit algorithm to compute the final camera.
    _mapController.fitCamera(fit);
    final MapCamera to = _mapController.camera;

    // If nothing really changed, don't animate.
    final double dLat = (to.center.latitude - from.center.latitude).abs();
    final double dLng = (to.center.longitude - from.center.longitude).abs();
    final double dZoom = (to.zoom - from.zoom).abs();
    if (dLat < 1e-8 && dLng < 1e-8 && dZoom < 1e-6) return;

    // Return to the starting camera and animate to the target.
    _mapController.move(from.center, from.zoom);
    await _animateToCamera(center: to.center, zoom: to.zoom);
  }

  /// Fence vertices for the field filter (local land rows), if any.
  List<LatLng> _fenceRingLatLngsFromLands(List<Land> lands) {
    if (_unassignedOnly) return <LatLng>[];
    final String? id = _selectedFieldId?.trim();
    final String? name = _selectedFieldName?.trim();
    if (id == null || id.isEmpty || name == null || name.isEmpty) {
      return <LatLng>[];
    }
    for (final Land l in lands) {
      if (l.landName.trim().toLowerCase() == name.toLowerCase() &&
          l.polygonCoordinates.length >= 2) {
        return l.polygonCoordinates
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
      }
    }
    return <LatLng>[];
  }

  /// When the polygon is missing locally, pull [fields.boundary_json] once and cache it.
  Future<List<LatLng>> _tryFetchAndCacheBoundaryForSelectedField() async {
    final String? id = _selectedFieldId?.trim();
    final String? name = _selectedFieldName?.trim();
    if (id == null ||
        id.isEmpty ||
        name == null ||
        name.isEmpty ||
        _unassignedOnly) {
      return <LatLng>[];
    }
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return <LatLng>[];
    try {
      final Map<String, dynamic>? row =
          await fieldRowBoundaryById(fieldId: id, uid: uid);
      if (row == null) return <LatLng>[];
      final List<LatLngPoint>? pts =
          DatabaseService.parseFieldsBoundaryJson(row['boundary_json']);
      if (pts == null || pts.length < 3) return <LatLng>[];
      await _db.upsertLandPolygonForFieldName(fieldName: name, coords: pts);
      return pts.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (_) {
      return <LatLng>[];
    }
  }

  void _scheduleFitForCurrentView(List<_DetectionPoint> pts) {
    if (!_pendingFitToPins || _selectionCameraFitInFlight) {
      return;
    }
    _selectionCameraFitInFlight = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _selectionCameraFitInFlight = false;
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (!mounted || !_pendingFitToPins) {
            return;
          }

          final List<Land> lands = await _landsFuture;
          List<LatLng> fenceCoords = _fenceRingLatLngsFromLands(lands);
          if (fenceCoords.isEmpty &&
              _selectedFieldId?.trim().isNotEmpty == true &&
              !_unassignedOnly) {
            fenceCoords = await _tryFetchAndCacheBoundaryForSelectedField();
          }

          final bool fieldOnly =
              _selectedFieldId?.trim().isNotEmpty == true && !_unassignedOnly;

          final List<LatLng> pinCoords =
              pts.map((p) => LatLng(p.lat!, p.lng!)).toList();

          // When a field is selected, prefer fitting the boundary so the map
          // zooms to that parcel (pins alone can span a huge bbox).
          List<LatLng> fitCoords;
          if (fieldOnly && fenceCoords.length >= 3) {
            fitCoords = List<LatLng>.from(fenceCoords);
            final LatLng a = fitCoords.first;
            final LatLng b = fitCoords.last;
            final bool ringOpen = (a.latitude - b.latitude).abs() > 1e-9 ||
                (a.longitude - b.longitude).abs() > 1e-9;
            if (ringOpen) {
              fitCoords.add(fitCoords.first);
            }
          } else {
            fitCoords = <LatLng>[...fenceCoords, ...pinCoords];
          }

          if (fitCoords.isEmpty) {
            if (fieldOnly) {
              final LatLng? cen = _highlightedFenceCenter(
                lands,
                fieldName: _selectedFieldName,
              );
              if (cen != null) {
                await _animateToCamera(center: cen, zoom: 17);
              } else {
                await _animateToCamera(
                  center: const LatLng(6.2167, 125.0667),
                  zoom: 11.5,
                );
              }
            } else {
              await _animateToCamera(
                center: const LatLng(6.2167, 125.0667),
                zoom: 11.5,
              );
            }
            _pendingFitToPins = false;
            return;
          }

          await _fitCameraAnimated(
            CameraFit.coordinates(
              coordinates: fitCoords,
              padding: fieldOnly
                  ? const EdgeInsets.fromLTRB(28, 28, 28, 96)
                  : const EdgeInsets.fromLTRB(40, 40, 40, 100),
              maxZoom: MapTiles.maxZoomSatellite.toDouble(),
              minZoom: 3,
            ),
          );
          _pendingFitToPins = false;
        } finally {
          _selectionCameraFitInFlight = false;
        }
      });
    });
  }

  List<Polygon> _buildGeoFencePolygons(
    BuildContext context,
    List<Land> lands,
    Land? highlight, {
    Map<String, int>? positiveCounts,
  }) {
    if (!_showGeoFence || lands.isEmpty) return <Polygon>[];

    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool focusOne = _selectedFieldId?.trim().isNotEmpty == true;
    final String? targetName = _selectedFieldName?.trim().toLowerCase();

    final List<Polygon> out = <Polygon>[];
    for (final land in lands) {
      if (land.polygonCoordinates.length < 3) continue;
      final List<LatLng> ring = land.polygonCoordinates
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      if (ring.isNotEmpty) ring.add(ring.first);

      final bool hi = targetName != null && targetName.isNotEmpty
          ? land.landName.trim().toLowerCase() == targetName
          : (highlight != null && land.id == highlight.id);
      if (focusOne && !hi) continue;

      final int posCount = positiveCounts == null
          ? 0
          : _positiveCountForLand(
              land,
              positiveCounts,
              focusOne: focusOne,
            );

      Color border;
      Color fill;
      double borderWidth;
      if (posCount > 0) {
        final Color heat = _heatColor(0.72);
        border = heat.withValues(alpha: 0.98);
        fill = heat.withValues(alpha: hi ? 0.34 : 0.24);
        borderWidth = hi ? 4.5 : 3.5;
      } else {
        border = hi
            ? cs.primary.withValues(alpha: 0.95)
            : cs.primary.withValues(alpha: 0.55);
        fill = hi
            ? cs.primary.withValues(alpha: 0.22)
            : cs.primary.withValues(alpha: 0.12);
        borderWidth = hi ? 4.0 : 3.0;
      }

      out.add(
        Polygon(
          points: ring,
          isFilled: true,
          color: fill,
          borderColor: border,
          borderStrokeWidth: borderWidth,
        ),
      );
    }
    return out;
  }

  Map<String, int> _positiveCountByFieldId(
    List<Map<String, dynamic>> positiveDocs,
  ) {
    final Map<String, int> out = <String, int>{};
    for (final Map<String, dynamic> d in positiveDocs) {
      final String? fid = (d['field_id'] as String?)?.trim();
      if (fid == null || fid.isEmpty) continue;
      out[fid] = (out[fid] ?? 0) + 1;
    }
    return out;
  }

  String? _fieldIdForLandName(String landName) {
    final String key = landName.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final Map<String, dynamic> r in _fieldsRows) {
      final String? name = (r['name'] as String?)?.trim().toLowerCase();
      if (name == key) return r['id'] as String?;
    }
    return null;
  }

  int _positiveCountForLand(
    Land land,
    Map<String, int> counts, {
    required bool focusOne,
  }) {
    final String? selectedId = _selectedFieldId?.trim();
    if (focusOne && selectedId != null && selectedId.isNotEmpty) {
      final String? targetName = _selectedFieldName?.trim().toLowerCase();
      if (targetName != null &&
          land.landName.trim().toLowerCase() == targetName) {
        return counts[selectedId] ?? 0;
      }
      return 0;
    }
    final String? fid = _fieldIdForLandName(land.landName);
    if (fid == null) return 0;
    return counts[fid] ?? 0;
  }

  LatLng? _ringCentroid(List<LatLng> ring) {
    if (ring.length < 3) return null;
    double latSum = 0;
    double lngSum = 0;
    for (final LatLng p in ring) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / ring.length, lngSum / ring.length);
  }

  /// Field polygons tinted by positive report count (zoomed-out heatmap).
  List<Polygon> _buildFieldHeatmapPolygons(
    BuildContext context,
    List<Land> lands,
    List<Map<String, dynamic>> positiveDocs,
  ) {
    if (lands.isEmpty) return <Polygon>[];

    final Map<String, int> counts = _positiveCountByFieldId(positiveDocs);
    int maxCount = 1;
    for (final int c in counts.values) {
      if (c > maxCount) maxCount = c;
    }

    final bool focusOne = _selectedFieldId?.trim().isNotEmpty == true;
    final String? targetName = _selectedFieldName?.trim().toLowerCase();
    final List<Polygon> out = <Polygon>[];

    for (final Land land in lands) {
      if (land.polygonCoordinates.length < 3) continue;
      final List<LatLng> ring = land.polygonCoordinates
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      if (ring.isNotEmpty) ring.add(ring.first);

      final bool hi = targetName != null && targetName.isNotEmpty
          ? land.landName.trim().toLowerCase() == targetName
          : false;
      if (focusOne && !hi) continue;

      final int posCount =
          _positiveCountForLand(land, counts, focusOne: focusOne);

      if (posCount > 0) {
        final double sev = (posCount / maxCount).clamp(0.0, 1.0);
        final Color heat = _heatColor(sev);
        out.add(
          Polygon(
            points: ring,
            isFilled: true,
            color: heat.withValues(alpha: 0.58 + sev * 0.14),
            borderColor: heat.withValues(alpha: 0.98),
            borderStrokeWidth: hi ? 4.5 : 3.5,
          ),
        );
      } else {
        out.add(
          Polygon(
            points: ring,
            isFilled: true,
            color: Colors.white.withValues(alpha: 0.14),
            borderColor: Colors.white.withValues(alpha: 0.62),
            borderStrokeWidth: hi ? 3.0 : 2.25,
          ),
        );
      }
    }
    return out;
  }

  List<Marker> _buildFieldHeatBadges(
    List<Land> lands,
    List<Map<String, dynamic>> positiveDocs,
  ) {
    final Map<String, int> counts = _positiveCountByFieldId(positiveDocs);
    if (counts.isEmpty) return <Marker>[];

    int maxCount = 1;
    for (final int c in counts.values) {
      if (c > maxCount) maxCount = c;
    }

    final bool focusOne = _selectedFieldId?.trim().isNotEmpty == true;
    final String? targetName = _selectedFieldName?.trim().toLowerCase();
    final List<Marker> out = <Marker>[];

    for (final Land land in lands) {
      if (land.polygonCoordinates.length < 3) continue;
      final bool hi = targetName != null && targetName.isNotEmpty
          ? land.landName.trim().toLowerCase() == targetName
          : false;
      if (focusOne && !hi) continue;

      final int posCount =
          _positiveCountForLand(land, counts, focusOne: focusOne);
      if (posCount <= 0) continue;

      final List<LatLng> ring = land.polygonCoordinates
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      final LatLng? centroid = _ringCentroid(ring);
      if (centroid == null) continue;

      final double sev = (posCount / maxCount).clamp(0.0, 1.0);
      out.add(
        Marker(
          point: centroid,
          width: 132,
          height: 34,
          alignment: Alignment.bottomCenter,
          child: _FieldHeatBadge(
            name: land.landName,
            count: posCount,
            color: _heatColor(sev),
          ),
        ),
      );
    }
    return out;
  }

  /// Stable hash when detection rows, grid toggle, or cell size are unchanged.
  int _heatmapSignature(
    List<Map<String, dynamic>> docs,
    List<_DetectionPoint> pts,
    LatLng center,
  ) {
    if (!_showGrid) return 0;
    int h = Object.hash(
      docs.length,
      pts.length,
      _cellSizeM,
      _showGrid,
      center.latitude,
      center.longitude,
    );
    for (final Map<String, dynamic> d in docs) {
      h = Object.hash(
        h,
        d['id'],
        d['latitude'],
        d['longitude'],
        d['count'],
        d['confidence'],
      );
    }
    return h;
  }

  List<Polygon> _buildHeatmapGrid(
    List<_DetectionPoint> pts,
    LatLng center,
  ) {
    final List<Polygon> gridPolys = <Polygon>[];
    final Map<math.Point<int>, double> cellSumW = {};
    final Map<math.Point<int>, double> cellSumWS = {};
    final double refLat = center.latitude;
    final double refLng = center.longitude;

    for (final _DetectionPoint p in pts) {
      final int bugCount = p.count ?? 0;
      final int confidencePct = p.confidencePct ?? 0;
      final double sev =
          severity01(bugCount: bugCount, confidencePct: confidencePct);
      final double w = math.max(
        1e-6,
        bugCount * (confidencePct.clamp(0, 100) / 100.0),
      );
      final Offset m = _latLngToMeters(
        lat: p.lat!,
        lng: p.lng!,
        refLat: refLat,
        refLng: refLng,
      );
      final int cx = (m.dx / _cellSizeM).floor();
      final int cy = (m.dy / _cellSizeM).floor();
      final math.Point<int> key = math.Point<int>(cx, cy);
      cellSumW[key] = (cellSumW[key] ?? 0.0) + w;
      cellSumWS[key] = (cellSumWS[key] ?? 0.0) + (w * sev);
    }

    for (final MapEntry<math.Point<int>, double> entry in cellSumW.entries) {
      final int cx = entry.key.x;
      final int cy = entry.key.y;
      final double sumW = entry.value;
      final double sumWS = cellSumWS[entry.key] ?? 0.0;
      final double sev = sumW <= 0 ? 0.0 : (sumWS / sumW);

      final double x0 = cx * _cellSizeM;
      final double y0 = cy * _cellSizeM;
      final double x1 = x0 + _cellSizeM;
      final double y1 = y0 + _cellSizeM;

      final double lat0 = refLat + _metersToLatDeg(y0);
      final double lat1 = refLat + _metersToLatDeg(y1);
      final double lng0 = refLng + _metersToLngDeg(x0, refLat);
      final double lng1 = refLng + _metersToLngDeg(x1, refLat);

      final Color fill = _heatColor(sev).withValues(alpha: 0.42);
      final Color stroke = _heatColor(sev).withValues(alpha: 0.82);

      gridPolys.add(
        Polygon(
          points: <LatLng>[
            LatLng(lat0, lng0),
            LatLng(lat0, lng1),
            LatLng(lat1, lng1),
            LatLng(lat1, lng0),
          ],
          isFilled: true,
          color: fill,
          borderColor: stroke,
          borderStrokeWidth: 1.5,
        ),
      );
    }
    return gridPolys;
  }

  @override
  Widget build(BuildContext context) {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;

    return AppScaffold(
      usePatternBackground: false,
      titleWidget: Text(
        _unassignedOnly
            ? 'Detections Map • Unassigned'
            : (_selectedFieldName?.trim().isNotEmpty == true)
                ? 'Detections Map • $_selectedFieldName'
                : 'Detections Map',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: uid == null
          ? null
          : <Widget>[
              IconButton(
                tooltip: 'Search by location or field name',
                icon: const Icon(Icons.search),
                onPressed: () => _openLocationSearch(context, uid),
              ),
            ],
      body: uid == null
          ? const Center(child: Text('Sign in to view detections map.'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: () {
                final String? f = _selectedFieldId?.trim();
                // Unassigned filter uses the full stream; rows filtered below.
                if (f != null && f.isNotEmpty && !_unassignedOnly) {
                  // Apply filters before ordering; the stream builder type only
                  // exposes filter methods before order() is called.
                  return SupabaseClientProvider.instance.client
                      .from('detections')
                      .stream(primaryKey: const <String>['id'])
                      .eq('field_id', f)
                      .order('created_at', ascending: false);
                }
                // RLS already scopes rows to the signed-in user, so we don't
                // need a user_id filter here.
                return SupabaseClientProvider.instance.client
                    .from('detections')
                    .stream(primaryKey: const <String>['id']).order(
                        'created_at',
                        ascending: false);
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load detections: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<Map<String, dynamic>> docs = _unassignedOnly
                    ? snapshot.data!
                        .where(
                            (Map<String, dynamic> d) => d['field_id'] == null)
                        .toList()
                    : snapshot.data!;
                final List<Map<String, dynamic>> positiveDocs = docs
                    .where(detectionRowIsPositive)
                    .toList();
                final List<_DetectionPoint> positivePts = positiveDocs
                    .map((d) => _DetectionPoint.fromRow(d))
                    .whereType<_DetectionPoint>()
                    .where((p) => p.lat != null && p.lng != null)
                    .toList();

                _scheduleFitForCurrentView(positivePts);

                final bool showPositivePins =
                    _mapLiveZoom >= _pinZoomThreshold && positivePts.isNotEmpty;
                final bool showFieldHeatmap =
                    _mapLiveZoom < _pinZoomThreshold && positiveDocs.isNotEmpty;

                if (positivePts.isEmpty && docs.isEmpty) {
                  // Still show the field boundaries even if no detections exist yet.
                  return FutureBuilder<List<Land>>(
                    future: _landsFuture,
                    builder: (context, landSnap) {
                      final List<Land> lands = landSnap.data ?? const <Land>[];
                      final List<Polygon> fencePolys =
                          _buildGeoFencePolygons(context, lands, null);
                      final LatLng initial = _highlightedFenceCenter(
                            lands,
                            fieldName: _selectedFieldName,
                          ) ??
                          const LatLng(6.2167, 125.0667);
                      return Stack(
                        children: <Widget>[
                          RepaintBoundary(
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: initial,
                                initialZoom: (!_unassignedOnly &&
                                        (_selectedFieldId?.trim().isNotEmpty ??
                                            false))
                                    ? 16.8
                                    : 11.8,
                                maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                minZoom: 3,
                                onMapReady: () {
                                  if (!mounted) return;
                                  setState(() => _mapLiveZoom =
                                      _mapController.camera.zoom);
                                },
                                onPositionChanged:
                                    _onDetectionsMapPositionChanged,
                              ),
                              children: <Widget>[
                                EsriImageryTileLayer(
                                  maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                  maxNativeZoom:
                                      MapTiles.maxNativeZoomSatellite,
                                ),
                                if (fencePolys.isNotEmpty)
                                  PolygonLayer(polygons: fencePolys),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FloatingActionButton.extended(
                              heroTag: 'fieldsFabEmpty',
                              onPressed: () => _openFieldsSheet(context, uid),
                              icon: const Icon(Icons.crop_square),
                              label: const Text('Fields'),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _unassignedOnly
                                    ? 'No unassigned detections yet.'
                                    : 'No detections yet for this view.',
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                if (positivePts.isEmpty) {
                  return FutureBuilder<List<Land>>(
                    future: _landsFuture,
                    builder: (context, landSnap) {
                      final List<Land> lands = landSnap.data ?? const <Land>[];
                      final List<Polygon> fencePolys =
                          _buildGeoFencePolygons(context, lands, null);
                      final LatLng initial = _highlightedFenceCenter(
                            lands,
                            fieldName: _selectedFieldName,
                          ) ??
                          const LatLng(6.2167, 125.0667);
                      return Stack(
                        children: <Widget>[
                          RepaintBoundary(
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: initial,
                                initialZoom: (!_unassignedOnly &&
                                        (_selectedFieldId?.trim().isNotEmpty ??
                                            false))
                                    ? 16.8
                                    : 11.8,
                                maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                minZoom: 3,
                                onMapReady: () {
                                  if (!mounted) return;
                                  setState(() => _mapLiveZoom =
                                      _mapController.camera.zoom);
                                },
                                onPositionChanged:
                                    _onDetectionsMapPositionChanged,
                              ),
                              children: <Widget>[
                                EsriImageryTileLayer(
                                  maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                  maxNativeZoom:
                                      MapTiles.maxNativeZoomSatellite,
                                ),
                                if (fencePolys.isNotEmpty)
                                  PolygonLayer(polygons: fencePolys),
                              ],
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FloatingActionButton.extended(
                              heroTag: 'fieldsFabNoPositive',
                              onPressed: () => _openFieldsSheet(context, uid),
                              icon: const Icon(Icons.crop_square),
                              label: const Text('Fields'),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Material(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(12),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    docs.isEmpty
                                        ? (_unassignedOnly
                                            ? 'No unassigned detections yet.'
                                            : 'No detections yet for this view.')
                                        : 'No positive mealybug detections in this view.\n'
                                            'Negative scans remain in your history.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }

                final LatLng center =
                    LatLng(positivePts.first.lat!, positivePts.first.lng!);

                final int gridSig =
                    _heatmapSignature(positiveDocs, positivePts, center);
                final List<Polygon> gridPolys;
                if (!_showGrid) {
                  gridPolys = <Polygon>[];
                } else if (_cachedGridSig == gridSig) {
                  gridPolys = _cachedGridPolys;
                } else {
                  gridPolys = _buildHeatmapGrid(positivePts, center);
                  _cachedGridSig = gridSig;
                  _cachedGridPolys = gridPolys;
                }

                final bool pulseMarkers = positivePts.length <= 25;

                return FutureBuilder<List<Land>>(
                  future: _landsFuture,
                  builder: (context, landSnap) {
                    final List<Land> lands = landSnap.data ?? const <Land>[];
                    final Land? hiLand = _geoFence
                        .findLandForPoint(
                          center.latitude,
                          center.longitude,
                          lands,
                        )
                        .land;
                    final Map<String, int> posByField =
                        _positiveCountByFieldId(positiveDocs);
                    final List<Polygon> fencePolys = showFieldHeatmap
                        ? <Polygon>[]
                        : _buildGeoFencePolygons(
                            context,
                            lands,
                            hiLand,
                            positiveCounts: posByField,
                          );
                    final List<Polygon> fieldHeatPolys = showFieldHeatmap
                        ? _buildFieldHeatmapPolygons(
                            context,
                            lands,
                            positiveDocs,
                          )
                        : <Polygon>[];
                    final List<Marker> fieldHeatBadges = showFieldHeatmap
                        ? _buildFieldHeatBadges(lands, positiveDocs)
                        : <Marker>[];
                    final LatLng initial = _highlightedFenceCenter(
                          lands,
                          fieldName: _selectedFieldName,
                        ) ??
                        (hiLand != null
                            ? _highlightedFenceCenter(<Land>[hiLand],
                                fieldName: hiLand.landName)
                            : null) ??
                        center;
                    final double zoom =
                        (_selectedFieldId?.trim().isNotEmpty ?? false)
                            ? 17
                            : 16;
                    final double pinSize = _pinPixelSizeForZoom(_mapLiveZoom);
                    final double markerHit = _markerHitBoxForPinSize(pinSize);

                    return Stack(
                      children: <Widget>[
                        RepaintBoundary(
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: initial,
                              initialZoom: zoom,
                              maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                              minZoom: 3,
                              onMapReady: () {
                                if (!mounted) return;
                                setState(() =>
                                    _mapLiveZoom = _mapController.camera.zoom);
                              },
                              onPositionChanged:
                                  _onDetectionsMapPositionChanged,
                            ),
                            children: [
                              EsriImageryTileLayer(
                                maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                maxNativeZoom: MapTiles.maxNativeZoomSatellite,
                              ),
                              if (fencePolys.isNotEmpty)
                                PolygonLayer(polygons: fencePolys),
                              if (fieldHeatPolys.isNotEmpty)
                                PolygonLayer(polygons: fieldHeatPolys),
                              if (fieldHeatBadges.isNotEmpty)
                                MarkerLayer(markers: fieldHeatBadges),
                              if (gridPolys.isNotEmpty)
                                PolygonLayer(polygons: gridPolys),
                              if (showPositivePins)
                                MarkerLayer(
                                  markers: positivePts.map((_DetectionPoint p) {
                                  final double sev = severity01(
                                    bugCount: p.count ?? 0,
                                    confidencePct: p.confidencePct ?? 0,
                                  );
                                  return Marker(
                                    point: LatLng(p.lat!, p.lng!),
                                    width: markerHit,
                                    height: markerHit,
                                    alignment: Alignment.center,
                                    child: GestureDetector(
                                      onTap: () {
                                        _showDetectionDetails(context, p);
                                      },
                                      child: HexPulseMarker(
                                        color: _heatColor(sev),
                                        size: pinSize,
                                        pulse: pulseMarkers,
                                        icon: Icons.location_on,
                                      ),
                                    ),
                                  );
                                  }).toList(),
                                ),
                              if (showFieldHeatmap)
                                const Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 12,
                                      bottom: 12,
                                    ),
                                    child: _FieldHeatLegend(),
                                  ),
                                ),
                              if (_showGrid)
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 12, bottom: 12),
                                    child: _GridLegend(cellSizeM: _cellSizeM),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton.extended(
                            heroTag: 'fieldsFab',
                            onPressed: () => _openFieldsSheet(context, uid),
                            icon: const Icon(Icons.crop_square),
                            label: const Text('Fields'),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  void _showDetectionDetails(BuildContext context, _DetectionPoint p) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final int count = p.count ?? 0;
        final int conf = p.confidencePct ?? 0;
        final String? img = p.imageUrl?.trim();
        final bool hasRemoteImage = img != null && img.isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (hasRemoteImage) ...<Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _MapSheetDetectionImage(
                        imageUrl: img,
                        detections: p.detections,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text('Mealybug count: $count'),
                  subtitle: Text('Confidence: $conf%'),
                ),
                if (p.capturedPhotoId != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => CapturedPhotoDetailScreen(
                              capturedPhotoId: p.capturedPhotoId!,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('View details'),
                    ),
                  )
                else if (!hasRemoteImage)
                  Text(
                    'No preview image on this detection record. '
                    'Full history opens after the capture is synced to this device.',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openFieldsSheet(BuildContext context, String uid) async {
    if (!await ensureOnline(context)) return;
    if (!context.mounted) return;
    final Map<String, String?>? picked =
        await showModalBottomSheet<Map<String, String?>>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: fieldsRealtimeStreamOrderedByName(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final List<Map<String, dynamic>> rows =
                  snap.data ?? const <Map<String, dynamic>>[];
              final List<String> ownerIds =
                  fieldRowOwnerIdsForProfileFetch(rows);
              final String rowKey =
                  rows.map((Map<String, dynamic> e) => e['id']).join(',');
              return FutureBuilder<_FieldsSheetAgg>(
                key: ValueKey<String>('fsheet|$rowKey'),
                future: _loadFieldsSheetAgg(ownerIds),
                builder: (BuildContext context,
                    AsyncSnapshot<_FieldsSheetAgg> metaSnap) {
                  if (!metaSnap.hasData) {
                    return const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final _FieldsSheetAgg meta = metaSnap.data!;
                  final Map<String, String> labels = meta.labels;
                  final Map<String, int> detByField = meta.detectionsByField;
                  final Map<String, int> imgByField = meta.imagesByField;
                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.public),
                        title: const Text('All detections'),
                        subtitle:
                            const Text('Show all pins and all boundaries'),
                        onTap: () => Navigator.pop(
                          sheetContext,
                          <String, String?>{'filter': 'all'},
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_off_outlined),
                        title: const Text('Unassigned'),
                        subtitle: const Text(
                          'Detections with no field (not linked in Supabase)',
                        ),
                        onTap: () => Navigator.pop(
                          sheetContext,
                          <String, String?>{'filter': 'unassigned'},
                        ),
                      ),
                      const Divider(height: 16),
                      for (final Map<String, dynamic> r in rows)
                        ListTile(
                          leading: const Icon(Icons.landscape_outlined),
                          title: Text((r['name'] as String?) ?? 'Field'),
                          subtitle: Text(() {
                            final String? fid = (r['id'] as String?)?.trim();
                            final int det = (fid != null && fid.isNotEmpty)
                                ? (detByField[fid] ?? 0)
                                : 0;
                            final int images = (fid != null && fid.isNotEmpty)
                                ? (imgByField[fid] ?? 0)
                                : 0;
                            final String? ou = r['user_id'] as String?;
                            if (currentUserJwtStaff() &&
                                ou != null &&
                                ou.isNotEmpty) {
                              return 'Owner: ${ownerDisplayLabel(ou, labels)} · '
                                  'Detections (map): $det · Images in field: $images';
                            }
                            return 'Detections (map): $det · Images in field: $images';
                          }()),
                          onTap: () => Navigator.pop(
                            sheetContext,
                            <String, String?>{
                              'filter': 'field',
                              'id': (r['id'] as String?)?.trim(),
                              'name': (r['name'] as String?)?.trim(),
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );

    if (picked == null) return;
    final String mode = picked['filter'] ?? 'all';
    setState(() {
      _landsFuture = _loadLands();
      _pendingFitToPins = true;
      switch (mode) {
        case 'unassigned':
          _unassignedOnly = true;
          _selectedFieldId = null;
          _selectedFieldName = null;
          break;
        case 'field':
          _unassignedOnly = false;
          _selectedFieldId = picked['id']?.trim().isNotEmpty == true
              ? picked['id']!.trim()
              : null;
          _selectedFieldName = picked['name']?.trim().isNotEmpty == true
              ? picked['name']!.trim()
              : null;
          break;
        default:
          _unassignedOnly = false;
          _selectedFieldId = null;
          _selectedFieldName = null;
      }
    });
  }

  Future<void> _openLocationSearch(BuildContext context, String uid) async {
    final TextEditingController c = TextEditingController();
    try {
      await _db.initialize();
      final List<Map<String, dynamic>> cached =
          await _db.getCachedFields(userId: uid);
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (BuildContext sheetContext) {
          return StatefulBuilder(
            builder: (BuildContext ctx2, void Function(void Function()) setM) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx2).bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: c,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Search location',
                          hintText:
                              'Field name or lat, lng (e.g. 6.34, 125.14)',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setM(() {}),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: Builder(
                          builder: (BuildContext listContext) {
                            final String q = c.text.trim();
                            final String ql = q.toLowerCase();
                            final LatLng? coord = q.isEmpty
                                ? null
                                : _parseDetectionsMapLatLngQuery(q);
                            final List<Map<String, dynamic>> matches =
                                <Map<String, dynamic>>[];
                            if (ql.isNotEmpty) {
                              for (final Map<String, dynamic> r in cached) {
                                final String name =
                                    (r['name'] as String?)?.trim() ?? '';
                                if (name.toLowerCase().contains(ql)) {
                                  matches.add(r);
                                }
                              }
                              matches.sort((Map<String, dynamic> a,
                                  Map<String, dynamic> b) {
                                final String na =
                                    (a['name'] as String?)?.toLowerCase() ?? '';
                                final String nb =
                                    (b['name'] as String?)?.toLowerCase() ?? '';
                                int ra = 2;
                                int rb = 2;
                                if (na == ql) {
                                  ra = 0;
                                } else if (na.startsWith(ql)) {
                                  ra = 1;
                                }
                                if (nb == ql) {
                                  rb = 0;
                                } else if (nb.startsWith(ql)) {
                                  rb = 1;
                                }
                                final int c0 = ra.compareTo(rb);
                                if (c0 != 0) return c0;
                                return na.compareTo(nb);
                              });
                              if (matches.length > 30) {
                                matches.removeRange(30, matches.length);
                              }
                            }
                            if (q.isEmpty) {
                              return Center(
                                child: Text(
                                  'Type a field name (from your saved fields) '
                                  'or comma-separated latitude & longitude.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(listContext)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              );
                            }
                            return ListView(
                              children: <Widget>[
                                if (coord != null)
                                  ListTile(
                                    leading:
                                        const Icon(Icons.pin_drop_outlined),
                                    title: Text(
                                      'Go to ${coord.latitude.toStringAsFixed(5)}, '
                                      '${coord.longitude.toStringAsFixed(5)}',
                                    ),
                                    subtitle: const Text(
                                      'Move map to this point (does not change field filter)',
                                    ),
                                    onTap: () async {
                                      Navigator.pop(ctx2);
                                      await Future<void>.delayed(Duration.zero);
                                      if (!mounted) return;
                                      await _animateToCamera(
                                        center: coord,
                                        zoom: 17.2,
                                      );
                                    },
                                  ),
                                if (coord != null && matches.isNotEmpty)
                                  const Divider(height: 1),
                                ...matches.map((Map<String, dynamic> r) {
                                  final String name =
                                      (r['name'] as String?)?.trim() ?? 'Field';
                                  final String? id =
                                      (r['id'] as String?)?.trim();
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.crop_square_outlined,
                                    ),
                                    title: Text(name),
                                    subtitle: const Text(
                                      'Show this field on the map',
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx2);
                                      if (id == null || id.isEmpty) return;
                                      setState(() {
                                        _landsFuture = _loadLands();
                                        _pendingFitToPins = true;
                                        _unassignedOnly = false;
                                        _selectedFieldId = id;
                                        _selectedFieldName = name;
                                      });
                                    },
                                  );
                                }),
                                if (coord == null &&
                                    matches.isEmpty &&
                                    ql.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'No matching field. Check spelling, or '
                                      'use two numbers: latitude, longitude.',
                                      style: Theme.of(listContext)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      c.dispose();
    }
  }
}

/// Preview for detection bottom sheet: optional [detections] box overlay on image.
class _MapSheetDetectionImage extends StatelessWidget {
  const _MapSheetDetectionImage({
    required this.imageUrl,
    required this.detections,
  });

  final String imageUrl;
  final List<Detection> detections;

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) {
      return LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          final double logicalW =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : 360;
          final int cacheW = (logicalW * MediaQuery.devicePixelRatioOf(ctx))
              .round()
              .clamp(96, 1600);
          return Image.network(
            maybeSupabaseRenderUrl(imageUrl, width: cacheW),
            fit: BoxFit.cover,
            cacheWidth: cacheW,
            loadingBuilder:
                (BuildContext _, Widget child, ImageChunkEvent? progress) {
              if (progress == null) return child;
              return Container(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => Container(
              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Theme.of(ctx).colorScheme.outline,
              ),
            ),
          );
        },
      );
    }

    return FutureBuilder<Uint8List?>(
      future: http.get(Uri.parse(imageUrl)).then((http.Response r) {
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
          return r.bodyBytes;
        }
        return null;
      }),
      builder: (BuildContext ctx, AsyncSnapshot<Uint8List?> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final Uint8List? bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return LayoutBuilder(
            builder: (BuildContext ctx2, BoxConstraints constraints) {
              final double logicalW =
                  constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 360;
              final int cacheW =
                  (logicalW * MediaQuery.devicePixelRatioOf(ctx2))
                      .round()
                      .clamp(96, 1600);
              return Image.network(
                maybeSupabaseRenderUrl(imageUrl, width: cacheW),
                fit: BoxFit.cover,
                cacheWidth: cacheW,
                errorBuilder: (_, __, ___) => Container(
                  color: Theme.of(ctx2).colorScheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 40,
                    color: Theme.of(ctx2).colorScheme.outline,
                  ),
                ),
              );
            },
          );
        }
        return DetectionOverlayImage(
          imageBytes: bytes,
          detections: detections,
        );
      },
    );
  }
}

class _FieldHeatBadge extends StatelessWidget {
  const _FieldHeatBadge({
    required this.name,
    required this.count,
    required this.color,
  });

  final String name;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 128),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldHeatLegend extends StatelessWidget {
  const _FieldHeatLegend();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 210,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Outbreak heatmap',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF38C064),
                    Color(0xFFF1C40F),
                    Color(0xFFE74C3C),
                  ],
                ),
                border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Fewer',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                ),
                Text(
                  'More positives',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pinch in to see individual capture pins.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    height: 1.25,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridLegend extends StatelessWidget {
  const _GridLegend({required this.cellSizeM});

  final double cellSizeM;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: <Color>[
                    Color(0xFF2ECC71),
                    Color(0xFFF1C40F),
                    Color(0xFFF39C12),
                    Color(0xFFE74C3C),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${cellSizeM.toStringAsFixed(0)}m cells',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectionPoint {
  const _DetectionPoint({
    required this.lat,
    required this.lng,
    required this.count,
    required this.confidencePct,
    required this.capturedPhotoId,
    required this.imageUrl,
    required this.detections,
  });

  final double? lat;
  final double? lng;
  final int? count;
  final int? confidencePct;
  final int? capturedPhotoId;

  /// Public Storage URL from [detections.image_url] (shown when no local capture link).
  final String? imageUrl;

  /// Bounding boxes in original image pixel space (from [detections.detections_json]).
  final List<Detection> detections;

  static _DetectionPoint? fromRow(Map<String, dynamic> d) {
    final double? lat =
        d['latitude'] == null ? null : (d['latitude'] as num).toDouble();
    final double? lng =
        d['longitude'] == null ? null : (d['longitude'] as num).toDouble();
    final int? count = (d['count'] as num?)?.toInt();
    final num? rawConf = d['confidence'] as num?;
    // Backwards-compatible normalization:
    // - If stored as fraction (0..1), convert to percent.
    // - If stored as percent (0..100), keep as-is.
    final int? confidencePct = rawConf == null
        ? null
        : (() {
            final double v = rawConf.toDouble();
            final double pct = v <= 1.0 ? (v * 100.0) : v;
            return pct.round().clamp(0, 100);
          })();

    // Optional linkage if your DB stores it; otherwise tapping will do nothing.
    final int? capturedPhotoId = (d['captured_photo_id'] as num?)?.toInt();

    final String? imageUrl = () {
      final dynamic v = d['image_url'];
      if (v == null) return null;
      final String s = v.toString().trim();
      return s.isEmpty ? null : s;
    }();

    return _DetectionPoint(
      lat: lat,
      lng: lng,
      count: count,
      confidencePct: confidencePct,
      capturedPhotoId: capturedPhotoId,
      imageUrl: imageUrl,
      detections: parseStoredDetectionsJson(d['detections_json']),
    );
  }
}
