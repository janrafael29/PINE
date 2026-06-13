/// Land boundary editor: define polygons on map for geo-fencing.
///
/// Uses flutter_map. Drawing UX: satellite-first, filled polygon preview,
/// tap vertices, tap near the first vertex to close (or use actions).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/map_tiles.dart';
import '../core/supabase_client.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/esri_imagery_tile_layer.dart';
import '../models/land.dart';
import '../services/database_service.dart';
import '../services/geo_fence_service.dart';

enum _LandMapStyle { satellite, street, terrain }

/// Screen for creating/editing land boundaries on a map.
class LandMapScreen extends StatefulWidget {
  const LandMapScreen({
    super.key,
    this.land,
    this.onSaved,
    this.initialCenter,
    this.initialLandName,
    this.supabaseFieldId,
  });

  final Land? land;
  final VoidCallback? onSaved;

  /// When set, map centers here and user can start drawing the boundary.
  final LatLng? initialCenter;

  /// When [land] is null, pre-fills the name field (e.g. link to a Supabase field).
  final String? initialLandName;

  /// When set, polygon is also written to [fields.boundary_json] after local save.
  final String? supabaseFieldId;

  @override
  State<LandMapScreen> createState() => _LandMapScreenState();
}

class _LandMapScreenState extends State<LandMapScreen> {
  final _mapController = MapController();
  final _database = DatabaseService();
  final _nameController = TextEditingController();

  List<LatLng> _polygonPoints = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  _LandMapStyle _mapStyle = _LandMapStyle.satellite;

  /// After closing the ring (tap near first point), no more vertices.
  bool _isClosed = false;

  static const Distance _distance = Distance();

  @override
  void initState() {
    super.initState();
    if (widget.land != null) {
      _nameController.text = widget.land!.landName;
      _polygonPoints = widget.land!.polygonCoordinates
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
    } else {
      final String pre = widget.initialLandName?.trim() ?? '';
      _nameController.text = pre;
      _polygonPoints = <LatLng>[];
    }
    if (_polygonPoints.length >= 3) {
      _isClosed = true;
    }
    _initialize();
  }

  Future<void> _initialize() async {
    await _database.initialize();
    if (mounted) setState(() => _isLoading = false);
  }

  bool _isNearFirstVertex(LatLng tap) {
    if (_polygonPoints.length < 3) return false;
    final double meters =
        _distance.as(LengthUnit.Meter, _polygonPoints.first, tap);
    return meters < 22;
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    if (_isClosed) return;
    if (_polygonPoints.length >= 3 && _isNearFirstVertex(point)) {
      setState(() => _isClosed = true);
      return;
    }
    setState(() => _polygonPoints.add(point));
  }

  void _removeLastPoint() {
    if (_polygonPoints.isNotEmpty) {
      setState(() {
        _polygonPoints.removeLast();
        _isClosed = false;
      });
    }
  }

  void _clearPoints() {
    setState(() {
      _polygonPoints.clear();
      _isClosed = false;
    });
  }

  void _reopenForEditing() {
    if (_polygonPoints.isEmpty) return;
    setState(() => _isClosed = false);
  }

  Future<void> _confirmClearBoundary() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear boundary?'),
        content: const Text('Are you sure you want to clear this boundary?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear boundary'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _clearPoints();
  }

  Future<void> _saveLand() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter land name')),
      );
      return;
    }
    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least 3 points to form a polygon'),
        ),
      );
      return;
    }
    if (!_isClosed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Close the shape: tap near the first point, or keep adding corners'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final coords = _polygonPoints
          .map((p) => LatLngPoint(p.latitude, p.longitude))
          .toList();

      int? excludeLandId = widget.land?.id;
      if (excludeLandId == null) {
        final Land? existingByName = await _database.findLandByFieldName(name);
        excludeLandId = existingByName?.id;
      }
      final List<Land> allLands = await _database.getAllLands();
      for (final Land other in allLands) {
        if (excludeLandId != null && other.id == excludeLandId) {
          continue;
        }
        if (other.polygonCoordinates.length < 3) {
          continue;
        }
        if (fieldBoundaryRingsOverlap(coords, other.polygonCoordinates)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This boundary overlaps another field. Adjust corners so '
                  'fields do not cross.',
                ),
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
      }

      if (widget.land?.id != null) {
        await _database.updateLand(
          widget.land!.copyWith(
            landName: name,
            polygonCoordinates: coords,
          ),
        );
      } else {
        final Land? byName = await _database.findLandByFieldName(name);
        if (byName?.id != null) {
          await _database.updateLand(
            byName!.copyWith(
              landName: name,
              polygonCoordinates: coords,
            ),
          );
        } else {
          await _database.insertLand(Land(
            landName: name,
            polygonCoordinates: coords,
            createdAt: DateTime.now(),
          ));
        }
      }

      widget.onSaved?.call();

      final String? fid = widget.supabaseFieldId?.trim();
      if (fid != null && fid.isNotEmpty) {
        try {
          final String? boundaryJson =
              _database.encodeLandBoundaryJsonForSupabase(
            Land(
              landName: name,
              polygonCoordinates: coords,
              createdAt: DateTime.now(),
            ),
          );
          if (boundaryJson != null) {
            await SupabaseClientProvider.instance.client.from('fields').update(
                <String, dynamic>{'boundary_json': boundaryJson}).eq('id', fid);
          }
        } catch (_) {
          // Offline or RLS: local polygon still saved.
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _tileUrl() {
    switch (_mapStyle) {
      case _LandMapStyle.satellite:
        return MapTiles.esriWorldImagery;
      case _LandMapStyle.terrain:
        return MapTiles.esriTerrain;
      case _LandMapStyle.street:
        return MapTiles.openStreetMap;
    }
  }

  int _tileMaxNativeZoom() {
    switch (_mapStyle) {
      case _LandMapStyle.satellite:
        return MapTiles.maxNativeZoomSatellite;
      case _LandMapStyle.terrain:
        return MapTiles.maxNativeZoomTerrain;
      case _LandMapStyle.street:
        return MapTiles.maxNativeZoomOpenStreetMap;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final List<LatLng> ring = _polygonPoints.length >= 3
        ? <LatLng>[..._polygonPoints, _polygonPoints.first]
        : <LatLng>[];

    final ColorScheme cs = Theme.of(context).colorScheme;

    return AppScaffold(
      usePatternBackground: false,
      title: widget.land != null
          ? 'Edit field boundary'
          : (widget.initialLandName != null &&
                  widget.initialLandName!.trim().isNotEmpty)
              ? 'Add boundary'
              : 'Draw field boundary',
      actions: <Widget>[
        PopupMenuButton<_LandMapStyle>(
          icon: const Icon(Icons.layers_outlined),
          tooltip: 'Map style',
          onSelected: (_LandMapStyle s) => setState(() => _mapStyle = s),
          itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<_LandMapStyle>>[
            const PopupMenuItem<_LandMapStyle>(
              value: _LandMapStyle.satellite,
              child: Text('Satellite'),
            ),
            const PopupMenuItem<_LandMapStyle>(
              value: _LandMapStyle.street,
              child: Text('Street'),
            ),
            const PopupMenuItem<_LandMapStyle>(
              value: _LandMapStyle.terrain,
              child: Text('Terrain'),
            ),
          ],
        ),
        if (_polygonPoints.isNotEmpty) ...[
          if (_isClosed)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _reopenForEditing,
              tooltip: 'Edit shape',
            ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _isClosed ? null : _removeLastPoint,
            tooltip: 'Remove last point',
          ),
        ],
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Field name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _polygonPoints.isNotEmpty
                          ? _polygonPoints.first
                          : widget.initialCenter ??
                              const LatLng(14.5995, 120.9842),
                      initialZoom: 16,
                      maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                      minZoom: 3,
                      onTap: _onMapTap,
                    ),
                    children: [
                      if (_mapStyle == _LandMapStyle.satellite)
                        EsriImageryTileLayer(
                          maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                          maxNativeZoom: MapTiles.maxNativeZoomSatellite,
                        )
                      else
                        TileLayer(
                          urlTemplate: _tileUrl(),
                          userAgentPackageName: 'com.pine.pine',
                          maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                          maxNativeZoom: _tileMaxNativeZoom(),
                        ),
                      if (ring.length >= 4)
                        PolygonLayer(
                          polygons: <Polygon>[
                            Polygon(
                              points: ring,
                              color: cs.primary.withValues(alpha: 0.22),
                              borderColor: cs.primary,
                              borderStrokeWidth: 2.5,
                            ),
                          ],
                        )
                      else if (_polygonPoints.length >= 2)
                        PolylineLayer(
                          polylines: <Polyline>[
                            Polyline(
                              points: _polygonPoints,
                              color: cs.primary,
                              strokeWidth: 3,
                            ),
                          ],
                        ),
                      if (_polygonPoints.isNotEmpty)
                        MarkerLayer(
                          markers: _polygonPoints
                              .asMap()
                              .entries
                              .map((MapEntry<int, LatLng> e) {
                            final bool isFirst = e.key == 0;
                            return Marker(
                              point: e.value,
                              width: isFirst ? 22 : 16,
                              height: isFirst ? 22 : 16,
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surface,
                                  border: Border.all(
                                    color: cs.primary,
                                    width: isFirst ? 3 : 2,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Container(
                                    width: isFirst ? 8 : 6,
                                    height: isFirst ? 8 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(12),
                    color: cs.surface.withValues(alpha: 0.94),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            _isClosed
                                ? Icons.check_circle_outline
                                : Icons.touch_app_outlined,
                            color: cs.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isClosed
                                  ? 'Boundary closed. Save when ready — or tap Edit (pencil) to adjust corners.'
                                  : _polygonPoints.length >= 3
                                      ? 'Tap the first point (larger dot) to close, or keep tapping to add corners. Undo removes the last corner.'
                                      : 'Tap the map to place corners along your field edge.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: cs.onSurface,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                _error!,
                style: TextStyle(color: cs.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_polygonPoints.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _confirmClearBoundary,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear boundary'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error.withValues(alpha: 0.65)),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLand,
                      child: _isSaving
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Text('Save boundary'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
