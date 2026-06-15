library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/detection_result.dart';
import '../services/admin_reports_service.dart';
import '../utils/detection_overlay_export.dart';
import '../widgets/detection_overlay_image.dart';
import 'database_service.dart';
import 'image_storage_service.dart';

class ExportService {
  ExportService({
    DatabaseService? databaseService,
    ImageStorageService? imageStorageService,
  })  : _db = databaseService ?? DatabaseService(),
        _images = imageStorageService ?? ImageStorageService();

  static const MethodChannel _publicDownloadChannel =
      MethodChannel('com.pine.pine/public_download');

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

  Future<String> exportCapturedPhotosZipAll() async {
    await _db.initialize();
    final rows = await _db.getCapturedPhotos(limit: 5000);
    if (rows.isEmpty) {
      throw StateError('No captured pictures to export');
    }
    final csv = _buildCsv(rows);
    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');

    final Directory cacheDir = await getTemporaryDirectory();
    final String zipPath = p.join(cacheDir.path, 'pine-export-$timestamp.zip');

    int imageCount = 0;
    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      final String csvPath = p.join(cacheDir.path, 'pine-export-$timestamp.csv');
      await File(csvPath).writeAsString(csv);
      encoder.addFile(File(csvPath), 'pine-export.csv');

      for (final row in rows) {
        final List<int>? bytes = await _imageBytesForRow(row);
        if (bytes == null) continue;
        imageCount += 1;
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

    if (imageCount == 0) {
      throw StateError('Could not build export (images missing).');
    }

    return _saveExportZipToDownloads(zipPath);
  }

  Future<String> exportCapturedPhotosZipNewOnly() async {
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

    int imageCount = 0;
    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      final String csvPath =
          p.join(cacheDir.path, 'pine-export-new-$timestamp.csv');
      await File(csvPath).writeAsString(csv);
      encoder.addFile(File(csvPath), 'pine-export.csv');

      for (final row in rows) {
        final List<int>? bytes = await _imageBytesForRow(row);
        if (bytes == null) continue;
        imageCount += 1;
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

    if (imageCount == 0) {
      throw StateError('Could not build export (images missing).');
    }

    await _db.markCapturedPhotosExported(ids);

    return _saveExportZipToDownloads(zipPath);
  }

  Future<String> exportSingleCapturedPhotoZip(int capturedPhotoId) async {
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
      if (bytes == null) {
        throw StateError('Could not build export (image missing).');
      }
      final String localPath =
          (row['local_image_path'] as String?) ?? 'image.jpg';
      final String baseName = localPath == DatabaseService.remoteOnlyLocalPath
          ? 'remote-${row['id']}.jpg'
          : p.basename(localPath);
      final File tmp = File(p.join(cacheDir.path, 'exp1-$baseName'));
      await tmp.writeAsBytes(bytes);
      encoder.addFile(tmp, p.join('images', baseName));
    } finally {
      encoder.close();
    }

    return _saveExportZipToDownloads(zipPath);
  }

  /// Staff export: CSV + annotated PNGs for captures that already have expert advice.
  /// Saves the ZIP to Downloads and returns the saved path + row count.
  Future<({String path, int count})> exportReviewedImagesCsvZip({
    String? fieldId,
  }) async {
    final AdminReportsService reports = AdminReportsService();
    final List<AdminReportItem> reviewed = (await reports.fetchReports())
        .where((AdminReportItem i) => i.hasExpertReply)
        .where(
          (AdminReportItem i) =>
              fieldId == null ||
              fieldId.trim().isEmpty ||
              (i.fieldId?.trim() ?? '') == fieldId.trim(),
        )
        .toList();
    if (reviewed.isEmpty) {
      throw StateError('No reviewed images to export');
    }

    final Set<String> detIds =
        reviewed.map((AdminReportItem i) => i.detectionId).toSet();
    final Map<String, Map<String, dynamic>> expertByDet =
        await reports.fetchExpertResponsesByDetectionIds(detIds);

    final String timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-');
    final Directory cacheDir = await getTemporaryDirectory();
    final String zipPath =
        p.join(cacheDir.path, 'pine-reviewed-export-$timestamp.zip');

    final List<String> headers = <String>[
      'detection_id',
      'field_name',
      'farmer',
      'captured_at',
      'mealybug_count',
      'confidence_pct',
      'latitude',
      'longitude',
      'expert_advice',
      'expert_action',
      'expert_updated_at',
      'annotated_image_file',
    ];
    final StringBuffer csv = StringBuffer()..writeln(headers.join(','));
    int exportedCount = 0;

    final encoder = ZipFileEncoder()..create(zipPath);
    try {
      for (final AdminReportItem item in reviewed) {
        final Map<String, dynamic>? expert = expertByDet[item.detectionId];
        final String advice =
            (expert?['strategy_text'] as String?)?.trim() ?? '';
        if (advice.isEmpty) continue;

        final Map<String, dynamic>? detail =
            await reports.fetchDetectionDetail(item.detectionId);
        final List<Detection> detections = parseStoredDetectionsJson(
          detail?['detections_json'],
        );

        final List<int>? rawBytes = await _downloadImageBytes(item.imageUrl);
        if (rawBytes == null) continue;

        final Uint8List? annotated = await renderDetectionOverlayPng(
          imageBytes: Uint8List.fromList(rawBytes),
          detections: detections,
        );
        if (annotated == null) continue;

        final String imageName = '${item.detectionId}.png';
        final File tmp = File(p.join(cacheDir.path, 'rev-$imageName'));
        await tmp.writeAsBytes(annotated);
        encoder.addFile(tmp, p.join('images', imageName));

        csv.writeln(<String>[
          _csv(item.detectionId),
          _csv(item.fieldName),
          _csv(item.farmerLabel),
          _csv(item.createdAtIso),
          _csv(item.count),
          _csv(item.confidencePct),
          _csv(item.latitude),
          _csv(item.longitude),
          _csv(advice),
          _csv(expert?['action_type']),
          _csv(expert?['updated_at']),
          _csv(imageName),
        ].join(','));
        exportedCount += 1;
      }

      if (exportedCount == 0) {
        throw StateError(
          'Could not build export (images or expert advice missing).',
        );
      }

      final String csvPath =
          p.join(cacheDir.path, 'pine-reviewed-export-$timestamp.csv');
      await File(csvPath).writeAsString(csv.toString());
      encoder.addFile(File(csvPath), 'reviewed-captures.csv');
    } finally {
      encoder.close();
    }

    final String savedPath = await _saveExportZipToDownloads(zipPath);
    return (path: savedPath, count: exportedCount);
  }

  /// User-facing success text after saving an export ZIP to Downloads.
  static String downloadSuccessMessage(
    String savedPath, {
    int? count,
    bool filipino = false,
  }) {
    final String fileName = p.basename(savedPath);
    if (filipino) {
      final String countLine =
          count == null ? '' : '\n$count capture(s).';
      return 'Naka-save sa Downloads:\n$fileName$countLine\n'
          'Buksan ang Files → Downloads sa telepono.';
    }
    final String countLine = count == null ? '' : '\n$count capture(s).';
    return 'Saved to Downloads:\n$fileName$countLine\n'
        'Open Files → Downloads on your phone.';
  }

  /// Copies a finished export ZIP into the device Downloads folder.
  Future<String> _saveExportZipToDownloads(String zipPath) async {
    final File src = File(zipPath);
    if (!await src.exists()) {
      throw StateError('Export file missing');
    }
    final String fileName = p.basename(zipPath);
    final Uint8List bytes = await src.readAsBytes();

    if (!kIsWeb && Platform.isAndroid) {
      final String? savedPath =
          await _publicDownloadChannel.invokeMethod<String>(
        'saveZipToDownloads',
        <String, Object>{
          'fileName': fileName,
          'bytes': bytes,
        },
      );
      if (savedPath == null || savedPath.trim().isEmpty) {
        throw StateError('Could not save to Downloads');
      }
      return savedPath;
    }

    final Directory? downloads = await getDownloadsDirectory();
    if (downloads == null) {
      throw StateError('Downloads folder not available');
    }
    final String destPath = p.join(downloads.path, fileName);
    final File dest = await src.copy(destPath);
    return dest.path;
  }

  Future<List<int>?> _downloadImageBytes(String url) async {
    final String u = url.trim();
    if (u.isEmpty) return null;
    try {
      final http.Response r = await http.get(Uri.parse(u));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
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

