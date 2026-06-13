// Location picker focused on South Cotabato with municipality chips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_logger.dart';
import '../core/map_tiles.dart';
import '../core/service_locator.dart';
import '../models/land.dart';
import '../services/geo_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/esri_imagery_tile_layer.dart';
import '../widgets/hex_pulse_marker.dart';

List<LatLng>? _fieldBoundaryRing(Land? land) {
  if (land == null || land.polygonCoordinates.length < 3) return null;
  final List<LatLng> ring = land.polygonCoordinates
      .map((LatLngPoint p) => LatLng(p.latitude, p.longitude))
      .toList();
  return <LatLng>[...ring, ring.first];
}

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialCenter,
    this.animateZoomIn = false,
    this.fieldBoundaryLand,
    this.fieldBoundaryLabel,
  });

  /// When set, the pin starts here and map animates in.
  final LatLng? initialCenter;

  /// If true, animate a quick zoom-in on open.
  final bool animateZoomIn;

  /// When set, draws this field's boundary on the map and fits the camera to it.
  final Land? fieldBoundaryLand;

  /// Shown in the hint banner (e.g. chosen field name "Angelei").
  final String? fieldBoundaryLabel;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

enum _MapStyle { street, satellite, terrain }

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  /// After the user taps the map or picks a chip, do not replace the red pin when GPS finishes.
  bool _userPinnedManually = false;
  _MapStyle _mapStyle = _MapStyle.satellite;
  final TextEditingController _searchController = TextEditingController();
  /// One SnackBar per screen visit when GPS is denied (avoids log/UI spam).
  bool _locationDeniedNoticeShown = false;
  bool _gpsFetchInFlight = false;

  static const LatLng polomolokCenter = LatLng(6.2167, 125.0667);
  static final LatLngBounds polomolokBounds = LatLngBounds(
    const LatLng(6.06, 124.90),
    const LatLng(6.44, 125.24),
  );

  final List<Map<String, dynamic>> polomolokLocations =
      <Map<String, dynamic>>[
    <String, dynamic>{'name': 'Polomolok', 'lat': 6.2167, 'lng': 125.0667},
    <String, dynamic>{'name': 'Poblacion', 'lat': 6.2158, 'lng': 125.0635},
    <String, dynamic>{'name': 'Cannery Site', 'lat': 6.2408, 'lng': 125.0613},
    <String, dynamic>{'name': 'Landan', 'lat': 6.1787, 'lng': 125.0873},
    <String, dynamic>{'name': 'Lumakil', 'lat': 6.2152, 'lng': 125.1138},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialCenter ?? polomolokCenter;
    if (widget.initialCenter != null) {
      _userPinnedManually = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final List<LatLng>? fieldRing = _fieldBoundaryRing(widget.fieldBoundaryLand);
      if (fieldRing != null && fieldRing.length >= 4) {
        try {
          final List<LatLng> fitPoints = List<LatLng>.from(fieldRing);
          if (_selectedLocation != null) {
            fitPoints.add(_selectedLocation!);
          }
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(fitPoints),
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 160),
            ),
          );
        } catch (_) {
          _mapController.move(fieldRing.first, 16.5);
        }
        return;
      }
      final LatLng start = _selectedLocation ?? polomolokCenter;
      if (widget.animateZoomIn) {
        _animateZoomIn(start);
      } else if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 14.5);
      } else {
        _mapController.move(start, widget.initialCenter != null ? 16.2 : 11.6);
      }
    });
    // ignore: discarded_futures
    _getCurrentLocation(
      moveSelectionToGpsIfUnset: widget.fieldBoundaryLand == null,
    );
  }

  @override
  void dispose() {
    _locationDeniedNoticeShown = false;
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches GPS. When [moveSelectionToGpsIfUnset] is true, moves the red pin (and map) to the
  /// device location only if the user has not already placed the pin manually.
  /// When [forceSelectionToGps] is true (toolbar "my location"), always align pin + map to GPS.
  Future<void> _getCurrentLocation({
    bool moveSelectionToGpsIfUnset = false,
    bool forceSelectionToGps = false,
  }) async {
    if (_gpsFetchInFlight) return;
    _gpsFetchInFlight = true;
    try {
      final GeoService geo = ServiceLocator.instance.get<GeoService>();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (forceSelectionToGps) {
          await geo.requestPermission();
          permission = await Geolocator.checkPermission();
        } else {
          permission = await Geolocator.requestPermission();
        }
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (!_locationDeniedNoticeShown && mounted) {
          _locationDeniedNoticeShown = true;
          AppLogger.warn(
            'Location unavailable: permission denied (not retrying until you leave this screen or tap My Location).',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                permission == LocationPermission.deniedForever
                    ? 'Location is blocked. Enable it in system Settings to use My Location.'
                    : 'Location permission is needed to show your position on the map.',
              ),
            ),
          );
        }
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final LatLng here = LatLng(position.latitude, position.longitude);
      final bool snapPin = forceSelectionToGps ||
          (moveSelectionToGpsIfUnset && !_userPinnedManually);
      setState(() {
        _currentLocation = here;
        if (snapPin) {
          _selectedLocation = here;
          if (forceSelectionToGps) {
            _userPinnedManually = false;
          }
        }
      });
      if (snapPin) {
        _mapController.move(here, 14.5);
      }
    } on PermissionDeniedException catch (e) {
      if (!_locationDeniedNoticeShown && mounted) {
        _locationDeniedNoticeShown = true;
        AppLogger.warn('Location permission denied: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is needed to show your position on the map.',
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Location error', e);
    } finally {
      _gpsFetchInFlight = false;
    }
  }

  void _animateZoomIn(LatLng target) {
    // Cheap zoom animation: step the camera a few times.
    _mapController.move(target, 13.5);
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      _mapController.move(target, 15.0);
    });
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _mapController.move(target, 16.2);
    });
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      _mapController.move(target, 17.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<LatLng>? fieldRing = _fieldBoundaryRing(widget.fieldBoundaryLand);
    final String landHint = widget.fieldBoundaryLabel?.trim().isNotEmpty == true
        ? widget.fieldBoundaryLabel!.trim()
        : (widget.fieldBoundaryLand?.landName.trim() ?? '');
    return AppScaffold(
      usePatternBackground: false,
      titleWidget: landHint.isNotEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Select Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Text(
                  landHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimary.withValues(alpha: 0.92),
                  ),
                ),
              ],
            )
          : null,
      title: landHint.isNotEmpty ? null : 'Select Location - Polomolok',
      actions: <Widget>[
          PopupMenuButton<_MapStyle>(
            icon: const Icon(Icons.layers),
            tooltip: 'Map style',
            onSelected: (_MapStyle style) {
              setState(() => _mapStyle = style);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_MapStyle>>[
              const PopupMenuItem<_MapStyle>(
                value: _MapStyle.street,
                child: ListTile(
                  leading: Icon(Icons.map),
                  title: Text('Street'),
                ),
              ),
              const PopupMenuItem<_MapStyle>(
                value: _MapStyle.satellite,
                child: ListTile(
                  leading: Icon(Icons.satellite),
                  title: Text('Satellite'),
                ),
              ),
              const PopupMenuItem<_MapStyle>(
                value: _MapStyle.terrain,
                child: ListTile(
                  leading: Icon(Icons.terrain),
                  title: Text('Terrain'),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use device location for pin',
            onPressed: () {
              _locationDeniedNoticeShown = false;
              // ignore: discarded_futures
              _getCurrentLocation(forceSelectionToGps: true);
            },
          ),
        ],
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Polomolok locations...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: polomolokLocations.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> loc =
                        polomolokLocations[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(loc['name'] as String),
                        onSelected: (bool selected) {
                          final LatLng point = LatLng(
                            (loc['lat'] as num).toDouble(),
                            (loc['lng'] as num).toDouble(),
                          );
                          setState(() {
                            _userPinnedManually = true;
                            _selectedLocation = point;
                          });
                          _mapController.move(point, 14);
                        },
                        avatar: const Icon(Icons.location_on, size: 16),
                        selected: false,
                      ),
                    );
                  },
                ),
              ),
              if (fieldRing != null && fieldRing.length >= 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    color: cs.primary.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.crop_square, color: cs.primary, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.fieldBoundaryLabel?.trim().isNotEmpty ==
                                      true
                                  ? 'Green outline: ${widget.fieldBoundaryLabel!.trim()}. Tap inside it to place your pin.'
                                  : 'Green outline is your field. Tap inside it to place your pin.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    height: 1.35,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? polomolokCenter,
                    initialZoom: 11.6,
                    minZoom: 10.8,
                    maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                    cameraConstraint: fieldRing != null && fieldRing.length >= 4
                        ? null
                        : CameraConstraint.contain(bounds: polomolokBounds),
                    onTap: (TapPosition tapPosition, LatLng point) {
                      setState(() {
                        _userPinnedManually = true;
                        _selectedLocation = point;
                      });
                    },
                  ),
                  children: <Widget>[
                    if (_mapStyle == _MapStyle.satellite)
                      EsriImageryTileLayer(
                        maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                        maxNativeZoom: MapTiles.maxNativeZoomSatellite,
                      )
                    else
                      TileLayer(
                        urlTemplate: _mapStyle == _MapStyle.terrain
                            ? MapTiles.esriTerrain
                            : MapTiles.openStreetMap,
                        userAgentPackageName: 'com.pine.pine',
                        maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                        maxNativeZoom: _mapStyle == _MapStyle.terrain
                            ? MapTiles.maxNativeZoomTerrain
                            : MapTiles.maxNativeZoomOpenStreetMap,
                      ),
                    if (fieldRing != null && fieldRing.length >= 4)
                      PolygonLayer(
                        polygons: <Polygon>[
                          Polygon(
                            points: fieldRing,
                            color: cs.primary.withValues(alpha: 0.22),
                            borderColor: cs.primary,
                            borderStrokeWidth: 3.5,
                          ),
                        ],
                      ),
                    if (_selectedLocation != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _selectedLocation!,
                            width: 52,
                            height: 52,
                            child: const HexPulseMarker(
                              color: Color(0xFF2ECC71),
                              size: 44,
                              pulse: true,
                              icon: Icons.location_on,
                            ),
                          ),
                        ],
                      ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _currentLocation!,
                            width: 32,
                            height: 32,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                                size: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_selectedLocation != null)
                      Text(
                        '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                        '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedLocation != null
                            ? () => Navigator.pop(context, _selectedLocation)
                            : null,
                        child: const Text('Confirm Location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
