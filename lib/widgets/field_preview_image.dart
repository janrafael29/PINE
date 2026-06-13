library;

import 'dart:collection';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/image_storage_service.dart';
import 'capture_thumbnail.dart';

/// Max width sent to Supabase image render (keeps field cards snappy on 4G).
const int kFieldPreviewRenderWidth = 280;

final Map<String, Future<File?>> _kFieldPreviewDiskFutures =
    HashMap<String, Future<File?>>();

String _diskCacheKey(String renderUrl) =>
    renderUrl.hashCode.toUnsigned(32).toRadixString(16);

Future<File?> _fieldPreviewDiskFile(String publicUrl) {
  final String renderUrl =
      maybeSupabaseRenderUrl(publicUrl, width: kFieldPreviewRenderWidth);
  return _kFieldPreviewDiskFutures.putIfAbsent(renderUrl, () async {
    try {
      final Directory tmp = await getTemporaryDirectory();
      final Directory dir =
          Directory(p.join(tmp.path, 'field_preview_cache'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final File file = File(p.join(dir.path, '${_diskCacheKey(renderUrl)}.jpg'));
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
      final http.Response res = await http
          .get(Uri.parse(renderUrl))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        return null;
      }
      await file.writeAsBytes(res.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  });
}

/// Thumbnail for My Fields / Home horizontal cards (local path, file, or URL).
class FieldPreviewImage extends StatelessWidget {
  const FieldPreviewImage({
    super.key,
    required this.previewPath,
    this.fallbackLogicalWidth = 160,
    this.placeholderIconSize = 40,
    this.images,
  });

  final String? previewPath;
  final double fallbackLogicalWidth;
  final double placeholderIconSize;
  final ImageStorageService? images;

  /// Warm Flutter image cache for visible field cards.
  static void precacheNetworkUrls(
    BuildContext context,
    Iterable<String?> paths, {
    double logicalWidth = 160,
  }) {
    if (!context.mounted) return;
    for (final String? raw in paths) {
      final String? p = raw?.trim();
      if (p == null || p.isEmpty) continue;
      if (!p.startsWith('http://') && !p.startsWith('https://')) continue;
      final String url =
          maybeSupabaseRenderUrl(p, width: kFieldPreviewRenderWidth);
      precacheImage(
        NetworkImage(url),
        context,
        size: Size(logicalWidth, logicalWidth),
      );
    }
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.landscape,
        size: placeholderIconSize,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? raw = previewPath?.trim();
    if (raw == null || raw.isEmpty) {
      return _placeholder(context);
    }

    final bool looksUrl =
        raw.startsWith('http://') || raw.startsWith('https://');
    final bool looksAbsolute = raw.contains(':') || raw.startsWith('/');

    if (looksUrl) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double logicalW = constraints.hasBoundedWidth &&
                  constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : fallbackLogicalWidth;
          final int cacheW = (logicalW *
                  MediaQuery.devicePixelRatioOf(context))
              .round()
              .clamp(96, kFieldPreviewRenderWidth);

          return FutureBuilder<File?>(
            future: _fieldPreviewDiskFile(raw),
            builder: (BuildContext context, AsyncSnapshot<File?> snap) {
              final File? cached = snap.data;
              if (cached != null && cached.existsSync()) {
                return Image.file(
                  cached,
                  fit: BoxFit.cover,
                  cacheWidth: cacheW,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, __, ___) => _placeholder(context),
                );
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return _placeholder(context);
              }
              final String url =
                  maybeSupabaseRenderUrl(raw, width: kFieldPreviewRenderWidth);
              return Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: cacheW,
                gaplessPlayback: true,
                filterQuality: FilterQuality.low,
                loadingBuilder: (_, Widget child, progress) {
                  if (progress == null) return child;
                  return _placeholder(context);
                },
                errorBuilder: (_, __, ___) => _placeholder(context),
              );
            },
          );
        },
      );
    }

    if (looksAbsolute) {
      final File f = File(raw);
      if (f.existsSync()) {
        return Image.file(
          f,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      }
      return _placeholder(context);
    }

    return captureThumbnail(
      localImagePath: raw,
      images: images ?? ImageStorageService(),
      displayLogicalWidth: fallbackLogicalWidth,
    );
  }
}
