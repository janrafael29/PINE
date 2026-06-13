/// Shared on-disk cache for Esri World Imagery tiles (flutter_map + dio).
///
/// Visited tiles are stored under app support dir so they reload sharply offline
/// and after restarts. Does not pre-download the whole world — only tiles the
/// user has actually viewed while online (within [maxStale]).
library;

import 'dart:io';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_file_store/http_cache_file_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lazily opens a single [FileCacheStore] for all Esri satellite layers.
abstract final class EsriMapTileCache {
  EsriMapTileCache._();

  static Future<CacheStore>? _storeFuture;

  static Future<CacheStore> sharedStore() {
    _storeFuture ??= _open();
    return _storeFuture!;
  }

  static Future<CacheStore> _open() async {
    final Directory root = await getApplicationSupportDirectory();
    final String path = p.join(root.path, 'fm_esri_world_imagery');
    return FileCacheStore(path);
  }
}
