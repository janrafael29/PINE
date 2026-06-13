// One map session to place all gallery photos that lack EXIF GPS inside a field.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/map_tiles.dart';
import '../core/theme.dart';
import '../models/land.dart';
import '../services/geo_fence_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/esri_imagery_tile_layer.dart';

/// Returns a [List] of [LatLng] in order (one per photo needing a pin), or null if
/// the user backs out without confirming.
class BulkGalleryPinScreen extends StatefulWidget {
  const BulkGalleryPinScreen({
    super.key,
    required this.land,
    required this.count,
    required this.fieldName,
    required this.filipino,
    required this.fence,
  });

  final Land land;
  final int count;
  final String fieldName;
  final bool filipino;
  final GeoFenceService fence;

  @override
  State<BulkGalleryPinScreen> createState() => _BulkGalleryPinScreenState();
}

class _BulkGalleryPinScreenState extends State<BulkGalleryPinScreen> {
  final MapController _mapController = MapController();
  late List<LatLng> _positions;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _positions = _initialPositions();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitMap());
  }

  LatLng _centroid() {
    final List<LatLngPoint> pts = widget.land.polygonCoordinates;
    if (pts.isEmpty) return const LatLng(6.2167, 125.0667);
    double sl = 0, sn = 0;
    for (final LatLngPoint p in pts) {
      sl += p.latitude;
      sn += p.longitude;
    }
    return LatLng(sl / pts.length, sn / pts.length);
  }

  List<LatLng> _initialPositions() {
    final LatLng c = _centroid();
    final int n = widget.count;
    final List<LatLng> out = <LatLng>[];
    for (int i = 0; i < n; i++) {
      LatLng p = c;
      for (int attempt = 0; attempt < 12; attempt++) {
        final double angle = 2 * math.pi * i / math.max(n, 1) + attempt * 0.25;
        final double scale =
            0.00006 * (1 + attempt * 0.35) * (1 + i * 0.015);
        final double lat = c.latitude + scale * math.cos(angle);
        final double lng = c.longitude + scale * math.sin(angle);
        p = LatLng(lat, lng);
        if (widget.fence.isPointInsideLand(lat, lng, widget.land)) {
          break;
        }
      }
      if (!widget.fence.isPointInsideLand(p.latitude, p.longitude, widget.land)) {
        p = c;
      }
      out.add(p);
    }
    return out;
  }

  void _fitMap() {
    final List<LatLng> ring = _polygonRing();
    if (ring.length < 3) {
      _mapController.move(_centroid(), 16);
      return;
    }
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(ring),
          padding: const EdgeInsets.all(56),
        ),
      );
    } catch (_) {
      _mapController.move(_centroid(), 16);
    }
  }

  List<LatLng> _polygonRing() {
    if (widget.land.polygonCoordinates.length < 3) return <LatLng>[];
    final List<LatLng> ring = widget.land.polygonCoordinates
        .map((LatLngPoint p) => LatLng(p.latitude, p.longitude))
        .toList();
    return <LatLng>[...ring, ring.first];
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (!widget.fence.isPointInsideLand(
      point.latitude,
      point.longitude,
      widget.land,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.filipino
                ? 'Sa loob lang ng field ang pin.'
                : 'Keep the pin inside the field boundary.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    setState(() {
      _positions[_selected] = point;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> ring = _polygonRing();
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AppScaffold(
      usePatternBackground: false,
      title: widget.filipino ? 'Mga lokasyon sa mapa' : 'Place photos on map',
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              widget.filipino
                  ? '${widget.count} larawan ang walang GPS. Pumili ng marker (#${_selected + 1}), tapos pindutin ang mapa para ilipat. Field: ${widget.fieldName}'
                  : '${widget.count} photos have no GPS. Tap a numbered marker (#${_selected + 1} selected), then tap the map to place it. Field: ${widget.fieldName}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centroid(),
                initialZoom: 16,
                minZoom: 3,
                maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                onTap: _onMapTap,
              ),
              children: <Widget>[
                EsriImageryTileLayer(
                  maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                  maxNativeZoom: MapTiles.maxNativeZoomSatellite,
                ),
                if (ring.length >= 4)
                  PolygonLayer(
                    polygons: <Polygon>[
                      Polygon(
                        points: ring,
                        color: cs.primary.withValues(alpha: 0.18),
                        borderColor: cs.primary,
                        borderStrokeWidth: 2.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: List<Marker>.generate(_positions.length, (int i) {
                    final bool sel = i == _selected;
                    return Marker(
                      point: _positions[i],
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = i),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: sel ? cs.primary : cs.surface,
                            border: Border.all(
                              color: sel ? cs.onPrimary : cs.primary,
                              width: sel ? 3 : 2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: sel ? cs.onPrimary : cs.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.filipino
                      ? 'Pinili: #${_selected + 1} / ${widget.count}'
                      : 'Selected: #${_selected + 1} / ${widget.count}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop<List<LatLng>>(context, List<LatLng>.from(_positions)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    widget.filipino ? 'Kumpirmahin lahat ng lokasyon' : 'Confirm all locations',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
