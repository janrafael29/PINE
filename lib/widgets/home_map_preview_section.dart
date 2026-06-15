/// Home tab map preview — farmer (own captures) or staff (org positive sightings).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../core/admin_session.dart';
import '../core/map_tiles.dart';
import '../core/theme.dart';
import '../services/database_service.dart';
import '../utils/detection_report_status.dart';
import '../widgets/esri_imagery_tile_layer.dart';
import '../widgets/hex_pulse_marker.dart';
import '../widgets/online_required_dialog.dart';
import '../screens/detections_map_screen.dart';

class HomeMapPreviewSection extends StatelessWidget {
  const HomeMapPreviewSection({
    super.key,
    required this.uid,
    required this.fil,
    required this.staffMode,
  });

  final String? uid;
  final bool fil;
  final bool staffMode;

  @override
  Widget build(BuildContext context) {
    final String title = staffMode
        ? (fil ? 'Mapa ng positibong sighting' : 'Positive sightings map')
        : (fil ? 'Preview ng Mapa: Polomolok' : 'Map Preview: Polomolok');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.pineTextPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 200,
              child: staffMode
                  ? _StaffMapPreview(fil: fil)
                  : _FarmerMapPreview(uid: uid, fil: fil),
            ),
          ),
        ),
      ],
    );
  }
}

class _FarmerMapPreview extends StatelessWidget {
  const _FarmerMapPreview({required this.uid, required this.fil});

  final String? uid;
  final bool fil;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        FutureBuilder<List<Map<String, dynamic>>>(
          future: () async {
            final String? userId = uid;
            if (userId == null) return <Map<String, dynamic>>[];
            final DatabaseService db = DatabaseService();
            await db.initialize();
            return db.getCapturedPhotos(limit: 250, userId: userId);
          }(),
          builder: (BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snap) {
            final List<Map<String, dynamic>> rows =
                snap.data ?? const <Map<String, dynamic>>[];
            final List<Map<String, dynamic>> pins = rows
                .where((Map<String, dynamic> r) =>
                    r['latitude'] != null && r['longitude'] != null)
                .take(60)
                .toList();

            return _MapPreviewBody(pins: pins, positiveOnlyPins: false);
          },
        ),
        _MapPreviewOverlay(fil: fil, staffMode: false),
      ],
    );
  }
}

class _StaffMapPreview extends StatelessWidget {
  const _StaffMapPreview({required this.fil});

  final bool fil;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: detectionsRealtimeStream(),
          builder: (BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snap) {
            final List<Map<String, dynamic>> rows =
                snap.data ?? const <Map<String, dynamic>>[];
            final List<Map<String, dynamic>> pins = rows
                .where(detectionRowIsPositive)
                .where((Map<String, dynamic> r) =>
                    r['latitude'] != null && r['longitude'] != null)
                .take(80)
                .toList();

            return _MapPreviewBody(pins: pins, positiveOnlyPins: true);
          },
        ),
        _MapPreviewOverlay(fil: fil, staffMode: true),
      ],
    );
  }
}

class _MapPreviewBody extends StatelessWidget {
  const _MapPreviewBody({
    required this.pins,
    required this.positiveOnlyPins,
  });

  final List<Map<String, dynamic>> pins;
  final bool positiveOnlyPins;

  @override
  Widget build(BuildContext context) {
    LatLng center = const LatLng(6.2167, 125.0667);
    if (pins.isNotEmpty) {
      center = LatLng(
        (pins.first['latitude'] as num).toDouble(),
        (pins.first['longitude'] as num).toDouble(),
      );
    }

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: pins.isNotEmpty ? 14.5 : 11.8,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: <Widget>[
        EsriImageryTileLayer(
          maxZoom: MapTiles.maxZoomSatellite.toDouble(),
          maxNativeZoom: MapTiles.maxNativeZoomSatellite,
        ),
        if (pins.isNotEmpty)
          MarkerLayer(
            markers: pins.map((Map<String, dynamic> r) {
              final double lat = (r['latitude'] as num).toDouble();
              final double lng = (r['longitude'] as num).toDouble();
              final int count = (r['count'] as num?)?.toInt() ?? 0;
              final double sev = (count / 20.0).clamp(0.0, 1.0);
              final Color c = Color.lerp(
                    const Color(0xFF2ECC71),
                    const Color(0xFFE74C3C),
                    sev,
                  ) ??
                  const Color(0xFF2ECC71);
              return Marker(
                point: LatLng(lat, lng),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: HexPulseMarker(
                  color: c,
                  size: 28,
                  pulse: false,
                  icon: Icons.location_on,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _MapPreviewOverlay extends StatelessWidget {
  const _MapPreviewOverlay({
    required this.fil,
    required this.staffMode,
  });

  final bool fil;
  final bool staffMode;

  Future<void> _openFullMap(BuildContext context) async {
    if (!await ensureOnline(context)) return;
    if (!context.mounted) return;
    await Navigator.push<Object?>(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => DetectionsMapScreen(
          initialShowGeoFence: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[
                  Colors.black.withValues(alpha: 0.36),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // ignore: discarded_futures
                _openFullMap(context);
              },
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  staffMode
                      ? (fil
                          ? 'Positibong mealybug sa accredited farms'
                          : 'Positive mealybug across farms')
                      : 'Polomolok, South Cotabato',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  // ignore: discarded_futures
                  _openFullMap(context);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(fil ? 'Buksan' : 'Open'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(0, 36),
                  maximumSize: const Size(160, 36),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
