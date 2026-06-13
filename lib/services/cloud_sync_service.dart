library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_logger.dart';
import '../models/land.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import 'database_service.dart';
import 'detection_service.dart';
import 'image_storage_service.dart';

/// Progress update for manual full sync (Add Photo → Sync).
class ManualSyncProgress {
  ManualSyncProgress({
    required this.uploadedSoFar,
    required this.totalInitial,
    required this.remaining,
    required this.elapsed,
    this.estimatedRemaining,
  });

  /// Work units finished (offline fields pushed + each detection upload attempt).
  final int uploadedSoFar;

  /// Total work units at start: pending offline fields + pending upload queue.
  final int totalInitial;

  /// Units left ([totalInitial] - [uploadedSoFar], clamped).
  final int remaining;

  final Duration elapsed;

  /// Rough ETA to finish remaining items, from average time per completed upload.
  final Duration? estimatedRemaining;

  double get progress01 =>
      totalInitial <= 0 ? 1.0 : (uploadedSoFar / totalInitial).clamp(0.0, 1.0);
}

/// Result after a manual sync run.
class ManualSyncSummary {
  ManualSyncSummary({
    required this.syncedCount,
    required this.remainingPending,
    required this.wasSkipped,
    this.message,
  });

  final int syncedCount;
  final int remainingPending;
  final bool wasSkipped;
  final String? message;
}

/// Background uploader for offline-saved detections.
///
/// - Always stores photos locally first.
/// - When online + authenticated, uploads image + writes Supabase (`detections` + Storage).
class CloudSyncService {
  CloudSyncService({
    DatabaseService? databaseService,
    ImageStorageService? imageStorageService,
    DetectionService? detectionService,
  })  : _db = databaseService ?? DatabaseService(),
        _images = imageStorageService ?? ImageStorageService(),
        _remote = detectionService ?? DetectionService();

  final DatabaseService _db;
  final ImageStorageService _images;
  final DetectionService _remote;

  bool _running = false;

  /// Attempts to upload pending items. Safe to call repeatedly.
  Future<void> syncPending({int limit = 10}) async {
    if (_running) return;
    _running = true;
    try {
      await _db.initialize();

      final String? uid =
          SupabaseClientProvider.instance.client.auth.currentUser?.id;
      if (uid == null) {
        return;
      }
      if (!await NetworkReachability.isOnline()) return;

      await _db.backfillPendingUploadsForUnsyncedCaptures(uid);
      await _syncPendingFieldsForUser(uid);

      final pending = await _db.getPendingUploads(limit: limit);
      for (final row in pending) {
        await _uploadOneQueueRow(row, uid);
      }
    } finally {
      _running = false;
    }
  }

  /// Uploads every pending row (in batches), reporting progress for the UI.
  ///
  /// Stops early if the same pending count persists across several batches
  /// (e.g. missing files that can never succeed).
  Future<ManualSyncSummary> syncAllPendingWithProgress({
    void Function(ManualSyncProgress progress)? onProgress,
    int batchSize = 12,
    int maxStuckBatches = 6,
  }) async {
    if (_running) {
      return ManualSyncSummary(
        syncedCount: 0,
        remainingPending: await _db.countPendingUploads(),
        wasSkipped: true,
        message: 'Another sync is already running.',
      );
    }
    _running = true;
    try {
      await _db.initialize();
      final String? uid =
          SupabaseClientProvider.instance.client.auth.currentUser?.id;
      if (uid == null) {
        return ManualSyncSummary(
          syncedCount: 0,
          remainingPending: await _db.countPendingUploads(),
          wasSkipped: true,
          message: 'Sign in to sync.',
        );
      }
      if (!await NetworkReachability.isOnline()) {
        return ManualSyncSummary(
          syncedCount: 0,
          remainingPending: await _db.countPendingUploads(),
          wasSkipped: true,
          message: 'You are offline. Connect to sync.',
        );
      }

      await _db.backfillPendingUploadsForUnsyncedCaptures(uid);

      final int uploadsInitial = await _db.countPendingUploads();
      final int fieldsInitial =
          (await _db.getCachedFieldsPendingSync(userId: uid)).length;
      final int totalWork = fieldsInitial + uploadsInitial;

      if (totalWork == 0) {
        onProgress?.call(
          ManualSyncProgress(
            uploadedSoFar: 0,
            totalInitial: 0,
            remaining: 0,
            elapsed: Duration.zero,
            estimatedRemaining: null,
          ),
        );
        return ManualSyncSummary(
          syncedCount: 0,
          remainingPending: 0,
          wasSkipped: false,
          message: 'Nothing to sync.',
        );
      }

      final Stopwatch sw = Stopwatch()..start();
      int completed = 0;

      void report() {
        final int remaining = (totalWork - completed).clamp(0, totalWork);
        onProgress?.call(
          ManualSyncProgress(
            uploadedSoFar: completed,
            totalInitial: totalWork,
            remaining: remaining,
            elapsed: sw.elapsed,
            estimatedRemaining: _estimateRemaining(
              elapsed: sw.elapsed,
              uploadedSoFar: completed,
              remaining: remaining,
            ),
          ),
        );
      }

      report();

      final int fieldsSyncedFirst = await _syncPendingFieldsForUser(
        uid,
        afterEachAttempt: () {
          completed++;
          report();
        },
      );

      int stuckBatches = 0;

      while (true) {
        final int before = await _db.countPendingUploads();
        if (before == 0) break;

        final List<Map<String, dynamic>> pending =
            await _db.getPendingUploads(limit: batchSize);
        if (pending.isEmpty) break;

        for (final Map<String, dynamic> row in pending) {
          await _uploadOneQueueRow(row, uid);
          completed++;
          report();
        }

        final int after = await _db.countPendingUploads();
        if (after >= before) {
          stuckBatches++;
          if (stuckBatches >= maxStuckBatches) {
            break;
          }
        } else {
          stuckBatches = 0;
        }
      }

      final int finalRemaining = await _db.countPendingUploads();
      final int uploadsSynced = uploadsInitial - finalRemaining;
      return ManualSyncSummary(
        syncedCount: fieldsSyncedFirst + uploadsSynced,
        remainingPending: finalRemaining,
        wasSkipped: false,
        message: finalRemaining > 0
            ? 'Some items could not upload (check connection or missing files).'
            : null,
      );
    } finally {
      _running = false;
    }
  }

  /// Pushes offline-created rows from [field_cache] into Supabase (`fields`).
  Future<int> _syncPendingFieldsForUser(
    String uid, {
    void Function()? afterEachAttempt,
  }) async {
    final List<Map<String, dynamic>> pending =
        await _db.getCachedFieldsPendingSync(userId: uid);
    if (pending.isEmpty) return 0;

    final SupabaseClient client = SupabaseClientProvider.instance.client;
    int synced = 0;

    for (final Map<String, dynamic> row in pending) {
      final String id = (row['id'] as String?) ?? '';
      if (id.isEmpty) {
        afterEachAttempt?.call();
        continue;
      }
      final String name = (row['name'] as String?) ?? '';
      final String address = (row['address'] as String?) ?? '';
      final String? previewPath = row['preview_image_path'] as String?;
      final Land? landForBoundary = await _db.findLandByFieldName(name);
      final String? boundaryJson =
          _db.encodeLandBoundaryJsonForSupabase(landForBoundary);

      try {
        await client.from('fields').insert(<String, dynamic>{
          'id': id,
          'user_id': uid,
          'name': name,
          'address': address,
          'preview_image_path': previewPath,
          if (boundaryJson != null) 'boundary_json': boundaryJson,
        });
      } on PostgrestException catch (e) {
        final String msg = e.message.toLowerCase();
        final String? code = e.code?.toString();
        final bool duplicate = code == '23505' ||
            msg.contains('duplicate') ||
            msg.contains('unique');
        if (duplicate) {
          await _db.markFieldCacheSynced(fieldId: id, userId: uid);
          synced++;
          afterEachAttempt?.call();
          continue;
        }
        AppLogger.error('CloudSyncService field insert failed', e);
        afterEachAttempt?.call();
        continue;
      } catch (e) {
        AppLogger.error('CloudSyncService field insert failed', e);
        afterEachAttempt?.call();
        continue;
      }

      if (previewPath != null &&
          previewPath.isNotEmpty &&
          !previewPath.startsWith('http://') &&
          !previewPath.startsWith('https://')) {
        final File? file = await _images.getImageFile(previewPath);
        if (file != null) {
          try {
            final String storagePath = '$uid/field_previews/$id.jpg';
            await client.storage.from('detections').upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: true,
                    contentType: 'image/jpeg',
                  ),
                );
            final String url =
                client.storage.from('detections').getPublicUrl(storagePath);
            await client.from('fields').update(
                <String, dynamic>{'preview_image_path': url}).eq('id', id);
          } catch (e) {
            AppLogger.error('CloudSyncService field preview upload failed', e);
          }
        }
      }

      await _db.markFieldCacheSynced(fieldId: id, userId: uid);
      synced++;
      afterEachAttempt?.call();
    }

    return synced;
  }

  static Duration? _estimateRemaining({
    required Duration elapsed,
    required int uploadedSoFar,
    required int remaining,
  }) {
    if (uploadedSoFar <= 0 || remaining <= 0) return null;
    final double msPer = elapsed.inMilliseconds / uploadedSoFar;
    if (msPer <= 0) return null;
    return Duration(milliseconds: (msPer * remaining).round());
  }

  Future<void> _uploadOneQueueRow(
    Map<String, dynamic> row,
    String uid,
  ) async {
    final int id = row['id'] as int;
    final String localPath = row['local_image_path'] as String;
    final int confidence = (row['confidence'] as num).toInt();
    final int count = (row['count'] as num).toInt();
    final String? fieldId = row['field_id'] as String?;
    final double? lat =
        row['latitude'] == null ? null : (row['latitude'] as num).toDouble();
    final double? lng =
        row['longitude'] == null ? null : (row['longitude'] as num).toDouble();
    final String? nameHint = row['name_hint'] as String?;

    final File? file = await _images.getImageFile(localPath);
    if (file == null) {
      await _db.markUploadFailed(id, 'Local image missing: $localPath');
      return;
    }

    String? detectionsJson;
    final Map<String, dynamic>? cap =
        await _db.getCapturedPhotoByLocalImagePath(localPath);
    if (cap != null) {
      final dynamic dj = cap['detections_json'];
      if (dj != null) {
        detectionsJson = dj is String ? dj : jsonEncode(dj);
      }
    }

    try {
      final Map<String, dynamic> res = await _remote.saveDetection(
        imageFile: file,
        detectionResult: <String, dynamic>{
          'confidence': confidence,
          'count': count,
        },
        fieldId: fieldId,
        latitude: lat,
        longitude: lng,
        fieldNameHint: nameHint,
        detectionsJson: detectionsJson,
      );
      final bool ok = res['success'] as bool? ?? false;
      if (ok) {
        final String? remoteId = res['detection_id']?.toString();
        final String? remoteUrl = res['image_url']?.toString();
        if (remoteId != null &&
            remoteId.isNotEmpty &&
            remoteUrl != null &&
            remoteUrl.isNotEmpty) {
          await _db.linkCapturedPhotoToRemoteUpload(
            userId: uid,
            localImagePath: localPath,
            remoteId: remoteId,
            remoteImageUrl: remoteUrl,
          );
        }
        await _db.markUploadSynced(id);
      } else {
        await _db.markUploadFailed(id, res['message']?.toString() ?? 'Error');
      }
    } catch (e) {
      AppLogger.error('CloudSyncService upload failed', e);
      await _db.markUploadFailed(id, e.toString());
    }
  }

  /// Convenience helper to run sync in background.
  void syncInBackground() {
    // ignore: discarded_futures
    unawaited(syncPending());
  }
}
