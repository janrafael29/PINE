/// Esri World Imagery [TileLayer] with persistent file cache when available.
library;

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';

import '../core/esri_map_tile_cache.dart';
import '../core/map_tiles.dart';

class EsriImageryTileLayer extends StatefulWidget {
  const EsriImageryTileLayer({
    super.key,
    required this.maxZoom,
    required this.maxNativeZoom,
    this.userAgentPackageName = 'com.pine.pine',
  });

  final double maxZoom;
  final int maxNativeZoom;
  final String userAgentPackageName;

  @override
  State<EsriImageryTileLayer> createState() => _EsriImageryTileLayerState();
}

class _EsriImageryTileLayerState extends State<EsriImageryTileLayer> {
  CachedTileProvider? _cached;

  @override
  void initState() {
    super.initState();
    EsriMapTileCache.sharedStore().then((CacheStore store) {
      if (!mounted) return;
      setState(() {
        _cached = CachedTileProvider(
          store: store,
          maxStale: const Duration(days: 30),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: MapTiles.esriWorldImagery,
      userAgentPackageName: widget.userAgentPackageName,
      maxZoom: widget.maxZoom,
      maxNativeZoom: widget.maxNativeZoom,
      tileProvider: _cached,
    );
  }
}
