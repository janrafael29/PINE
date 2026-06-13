library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'database_service.dart';
import 'image_storage_service.dart';

class ExportService {
  ExportService({
    DatabaseService? databaseService,
    ImageStorageService? imageStorageService,
  })  : _db = databaseService ?? DatabaseService(),
        _images = imageStorageService ?? ImageStorageService();

  final DatabaseService _db;
  final ImageStorageService _images;

  Future<List<int>?> _imageBytesForRow(Map<String, dynamic> row) async {
    final String? remoteUrl = row['remote_image_url'] as String?;
    final String? localPath = row['local_image_path'] as String?;
    if (localPath != null &&
        localPath.isNotEmpty &&
        localPath != DatabaseService.remoteOnlyLocalPath) {
      final File? f = await _images.getImageFile(localPath);
      if (f != null) return f.readAsBytes();
    }
    final String? u = remoteUrl?.trim();
    if (u != null && u.isNotEmpty) {
      try {
        final http.Response r = await http.get(Uri.parse(u));
        if (r.statusCode == 200) return r.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  Future<void> exportCapturedPhotosZipAll() async {
    await _db.initialize();
    final rows = await _db.getCapturedPhotos(limit: 5000);
    final csv = _buildCsv(rows);
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');

    final Directory cacheDir = await getTemporaryDirectory();
    final String zipPath = p.join(cacheDir.path, 'pine-export-$timestamp.zip');

    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      final String csvPath = p.join(cacheDir.path, 'pine-export-$timestamp.csv');
      await File(csvPath).writeAsString(csv);
      encoder.addFile(File(csvPath), 'pine-export.csv');

      for (final row in rows) {
        final List<int>? bytes = await _imageBytesForRow(row);
        if (bytes == null) continue;
        final String localPath =
            (row['local_image_path'] as String?) ?? 'image.jpg';
        final String baseName = localPath == DatabaseService.remoteOnlyLocalPath
            ? 'remote-${row['id']}.jpg'
            : p.basename(localPath);
        final File tmp = File(p.join(cacheDir.path, 'exp-$baseName'));
        await tmp.writeAsBytes(bytes);
        encoder.addFile(tmp, p.join('images', baseName));
      }
    } finally {
      encoder.close();
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(zipPath)],
        subject: 'PINE Export (CSV + images)',
        text: 'PINE captured photos export.',
      ),
    );
  }

  Future<void> exportCapturedPhotosZipNewOnly() async {
    await _db.initialize();
    final rows = await _db.getUnexportedCapturedPhotos(limit: 5000);
    if (rows.isEmpty) {
      throw StateError('No new captured pictures to export');
    }

    final csv = _buildCsv(rows);
    final ids =
        rows.map((r) => (r['id'] as num).toInt()).toList(growable: false);

    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final Directory cacheDir = await getTemporaryDirectory();
    final String zipPath =
        p.join(cacheDir.path, 'pine-export-new-$timestamp.zip');

    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      final String csvPath =
          p.join(cacheDir.path, 'pine-export-new-$timestamp.csv');
      await File(csvPath).writeAsString(csv);
      encoder.addFile(File(csvPath), 'pine-export.csv');

      for (final row in rows) {
        final List<int>? bytes = await _imageBytesForRow(row);
        if (bytes == null) continue;
        final String localPath =
            (row['local_image_path'] as String?) ?? 'image.jpg';
        final String baseName = localPath == DatabaseService.remoteOnlyLocalPath
            ? 'remote-${row['id']}.jpg'
            : p.basename(localPath);
        final File tmp = File(p.join(cacheDir.path, 'expn-$baseName'));
        await tmp.writeAsBytes(bytes);
        encoder.addFile(tmp, p.join('images', baseName));
      }
    } finally {
      encoder.close();
    }

    await _db.markCapturedPhotosExported(ids);

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(zipPath)],
        subject: 'PINE Export (new captures)',
        text: 'PINE captured photos export (new only).',
      ),
    );
  }

  Future<void> exportSingleCapturedPhotoZip(int capturedPhotoId) async {
    await _db.initialize();
    final row = await _db.getCapturedPhotoById(capturedPhotoId);
    if (row == null) {
      throw StateError('Captured photo not found');
    }

    final csv = _buildCsv(<Map<String, dynamic>>[row]);
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');

    final Directory cacheDir = await getTemporaryDirectory();
    final String zipPath =
        p.join(cacheDir.path, 'pine-export-one-$timestamp.zip');

    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      final String csvPath =
          p.join(cacheDir.path, 'pine-export-one-$timestamp.csv');
      await File(csvPath).writeAsString(csv);
      encoder.addFile(File(csvPath), 'pine-export.csv');

      final List<int>? bytes = await _imageBytesForRow(row);
      if (bytes != null) {
        final String localPath =
            (row['local_image_path'] as String?) ?? 'image.jpg';
        final String baseName = localPath == DatabaseService.remoteOnlyLocalPath
            ? 'remote-${row['id']}.jpg'
            : p.basename(localPath);
        final File tmp = File(p.join(cacheDir.path, 'exp1-$baseName'));
        await tmp.writeAsBytes(bytes);
        encoder.addFile(tmp, p.join('images', baseName));
      }
    } finally {
      encoder.close();
    }

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(zipPath)],
        subject: 'PINE Export (1 capture)',
        text: 'PINE captured photo export (CSV + image).',
      ),
    );
  }

  String _buildCsv(List<Map<String, dynamic>> rows) {
    final headers = <String>[
      'id',
      'created_at',
      'field_name',
      'field_id',
      'confidence',
      'count',
      'latitude',
      'longitude',
      'local_image_path',
    ];

    final out = StringBuffer()..writeln(headers.join(','));

    for (final row in rows) {
      final values = <String>[
        _csv(row['id']),
        _csv(row['created_at']),
        _csv(row['field_name']),
        _csv(row['field_id']),
        _csv(row['confidence']),
        _csv(row['count']),
        _csv(row['latitude']),
        _csv(row['longitude']),
        _csv(row['local_image_path']),
      ];
      out.writeln(values.join(','));
    }
    return out.toString();
  }

  String _csv(Object? v) {
    final s = v?.toString() ?? '';
    final needsQuote = s.contains(',') || s.contains('"') || s.contains('\n');
    if (!needsQuote) return s;
    return '"${s.replaceAll('"', '""')}"';
  }
}

