/// Resolves optional images under [assets/placeholder_pics/] by **card title** = file stem.
///
/// Filenames must match the title text plus an extension: `.png`, `.jpg`, `.jpeg`, or `.webp`.
/// Only keys present in [AssetManifest.json] are used (missing files are ignored).
library;

import 'dart:convert';

import 'package:flutter/material.dart';

const String _kPlaceholderDir = 'assets/placeholder_pics';

String _normalizeStem(String s) {
  // Keep this conservative: only normalize for file lookup, not display.
  final lower = s.toLowerCase().trim();
  final noPunct = lower.replaceAll(RegExp(r"[^\w\s-]"), "");
  final collapsed = noPunct.replaceAll(RegExp(r"\s+"), " ");
  return collapsed;
}

List<String> _candidateStemsForTitle(String title) {
  final base = title.trim();
  final norm = _normalizeStem(title);
  return <String>{
    base,
    base.replaceAll(' ', '_'),
    base.replaceAll(' ', '-'),
    norm,
    norm.replaceAll(' ', '_'),
    norm.replaceAll(' ', '-'),
    norm.replaceAll(' ', ''),
  }.where((s) => s.isNotEmpty).toList(growable: false);
}

/// Returns the first bundled asset path under [_kPlaceholderDir] whose key exists in [manifest].
String? moreTabImageForTitle(Map<String, dynamic> manifest, String title) {
  const List<String> exts = <String>['.png', '.jpg', '.jpeg', '.webp'];
  for (final String stem in _candidateStemsForTitle(title)) {
    for (final String ext in exts) {
      final String path = '$_kPlaceholderDir/$stem$ext';
      if (manifest.containsKey(path)) {
        return path;
      }
    }
  }
  return null;
}

/// Loads decoded AssetManifest (Flutter asset bundle).
Future<Map<String, dynamic>> loadAssetManifestJson(BuildContext context) async {
  final String raw =
      await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
  return json.decode(raw) as Map<String, dynamic>;
}

/// Caches [AssetManifest.json] so More-tab cards and disease detail heroes resolve paths once.
class AssetManifestCache {
  AssetManifestCache._();

  static Map<String, dynamic>? _cached;
  static Future<Map<String, dynamic>>? _inFlight;

  static Future<Map<String, dynamic>> ensure(BuildContext context) {
    if (_cached != null) {
      return Future<Map<String, dynamic>>.value(_cached!);
    }
    _inFlight ??=
        loadAssetManifestJson(context).then((Map<String, dynamic> m) {
      _cached = m;
      return m;
    });
    return _inFlight!;
  }
}
