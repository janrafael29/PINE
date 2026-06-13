library;

import 'dart:collection';

import 'dart:io';

import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/image_storage_service.dart';

/// In-memory cache so list rebuilds don't restart disk [Future]s per cell.
final Map<String, Future<File?>> _kThumbnailFileFutureCache =
    HashMap<String, Future<File?>>();

/// If [publicUrl] is a Supabase Storage public object URL, convert it to the
/// image render endpoint (supports resize/quality) and apply [width] when given.
///
/// This makes thumbnail grids feel much faster by downloading fewer bytes.
String maybeSupabaseRenderUrl(String publicUrl, {int? width}) {
  final Uri? u = Uri.tryParse(publicUrl);
  if (u == null) return publicUrl;

  // Matches: /storage/v1/object/public/<bucket>/<path...>
  const String marker = '/storage/v1/object/public/';
  final String p = u.path;
  final int idx = p.indexOf(marker);
  if (idx < 0) return publicUrl;

  final String tail = p.substring(idx + marker.length); // <bucket>/<path...>
  final String newPath = '${p.substring(0, idx)}/storage/v1/render/image/public/$tail';

  final Map<String, String> qp = <String, String>{...u.queryParameters};
  if (width != null && width > 0) {
    qp['width'] = width.toString();
    qp.putIfAbsent('resize', () => 'contain');
    qp.putIfAbsent('quality', () => '65');
  }

  return u.replace(path: newPath, queryParameters: qp).toString();
}

Future<File?> _cachedImageFile(
  String localImagePath,
  ImageStorageService images,
) {
  if (localImagePath == DatabaseService.remoteOnlyLocalPath) {
    return Future<File?>.value(null);
  }
  return _kThumbnailFileFutureCache.putIfAbsent(
    localImagePath,
    () => images.getImageFile(localImagePath),
  );
}

/// Thumbnail from local disk when available, otherwise from [remoteImageUrl].
///
/// [displayLogicalWidth] is used with [MediaQuery.devicePixelRatio] for
/// [Image.cacheWidth] decode sizing (defaults to 160 logical px).
Widget captureThumbnail({
  required String localImagePath,
  String? remoteImageUrl,
  required ImageStorageService images,
  BoxFit fit = BoxFit.cover,
  double displayLogicalWidth = 160,
}) {
  return LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double logicalW = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : displayLogicalWidth;
      final int cacheW =
          (logicalW * MediaQuery.devicePixelRatioOf(context)).round().clamp(48, 2048);
      return FutureBuilder<File?>(
        future: _cachedImageFile(localImagePath, images),
        builder: (BuildContext context, AsyncSnapshot<File?> snap) {
          final File? file = snap.data;
          if (file != null) {
            return Image.file(
              file,
              fit: fit,
              cacheWidth: cacheW,
            );
          }
          final String? url = remoteImageUrl?.trim();
          if (url != null && url.isNotEmpty) {
            return Image.network(
              maybeSupabaseRenderUrl(url, width: cacheW),
              fit: fit,
              cacheWidth: cacheW,
              errorBuilder: (
                BuildContext _,
                Object __,
                StackTrace? ___,
              ) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined),
                );
              },
              loadingBuilder: (
                BuildContext _,
                Widget child,
                ImageChunkEvent? loadingProgress,
              ) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
            );
          }
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.image_outlined),
          );
        },
      );
    },
  );
}
