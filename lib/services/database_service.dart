/// SQLite database service for Land and Detection records.
///
/// Land polygons are stored locally; the app mirrors them to Supabase
/// (`fields.boundary_json`) so boundaries survive reinstall.
library;

import 'dart:convert';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/detection_record.dart';
import '../models/land.dart';

/// Database service for offline storage of lands and detections.
class DatabaseService {
  static const _dbName = 'pine.db';
  static const _dbVersion = 12;

  Database? _db;

  /// Initializes the database. Call once at app startup.
  Future<void> initialize() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<bool> _columnExists(
    Database db,
    String table,
    String column,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    for (final row in rows) {
      final name = row['name']?.toString();
      if (name == column) return true;
    }
    return false;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE land (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        land_name TEXT NOT NULL,
        polygon_coordinates TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE detection (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        land_id INTEGER,
        bug_count INTEGER NOT NULL,
        confidence_score REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (land_id) REFERENCES land(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_detection_land_id ON detection(land_id)',
    );
    await db.execute(
      'CREATE INDEX idx_detection_timestamp ON detection(timestamp)',
    );

    await db.execute('''
      CREATE TABLE upload_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_image_path TEXT NOT NULL,
        confidence INTEGER NOT NULL,
        count INTEGER NOT NULL,
        field_id TEXT,
        latitude REAL,
        longitude REAL,
        name_hint TEXT,
        status TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_upload_queue_status_created ON upload_queue(status, created_at)',
    );

    await db.execute('''
      CREATE TABLE captured_photo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_image_path TEXT NOT NULL,
        field_name TEXT NOT NULL,
        field_id TEXT,
        confidence INTEGER NOT NULL,
        count INTEGER NOT NULL,
        detections_json TEXT,
        latitude REAL,
        longitude REAL,
        user_id TEXT,
        created_at TEXT NOT NULL,
        exported_at TEXT,
        remote_id TEXT,
        remote_image_url TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_captured_photo_created ON captured_photo(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_captured_photo_user ON captured_photo(user_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_captured_photo_user_remote '
      'ON captured_photo(user_id, remote_id) WHERE remote_id IS NOT NULL '
      "AND remote_id != ''",
    );

    await db.execute('''
      CREATE TABLE field_cache (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        preview_image_path TEXT,
        image_count INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        sync_pending INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_field_cache_user ON field_cache(user_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE upload_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          local_image_path TEXT NOT NULL,
          confidence INTEGER NOT NULL,
          count INTEGER NOT NULL,
          field_id TEXT,
          plot_id TEXT,
          latitude REAL,
          longitude REAL,
          status TEXT NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_upload_queue_status_created ON upload_queue(status, created_at)',
      );
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE captured_photo (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          local_image_path TEXT NOT NULL,
          field_name TEXT NOT NULL,
          plot_name TEXT NOT NULL,
          field_id TEXT,
          plot_id TEXT,
          confidence INTEGER NOT NULL,
          count INTEGER NOT NULL,
          latitude REAL,
          longitude REAL,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_captured_photo_created ON captured_photo(created_at)',
      );
    }
    if (oldVersion < 4) {
      final hasExportedAt =
          await _columnExists(db, 'captured_photo', 'exported_at');
      if (!hasExportedAt) {
        await db.execute(
          'ALTER TABLE captured_photo ADD COLUMN exported_at TEXT',
        );
      }
    }

    if (oldVersion < 5) {
      final hasUserId = await _columnExists(db, 'captured_photo', 'user_id');
      if (!hasUserId) {
        await db.execute(
          'ALTER TABLE captured_photo ADD COLUMN user_id TEXT',
        );
      }
    }

    if (oldVersion < 6) {
      // Remove plot-related columns (SQLite 3.35+). Older engines: columns may remain unused.
      try {
        await db.execute('ALTER TABLE upload_queue DROP COLUMN plot_id');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE captured_photo DROP COLUMN plot_name');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE captured_photo DROP COLUMN plot_id');
      } catch (_) {}
    }

    if (oldVersion < 7) {
      final hasDetectionsJson =
          await _columnExists(db, 'captured_photo', 'detections_json');
      if (!hasDetectionsJson) {
        await db.execute(
          'ALTER TABLE captured_photo ADD COLUMN detections_json TEXT',
        );
      }
    }

    if (oldVersion < 8) {
      if (!await _columnExists(db, 'captured_photo', 'remote_id')) {
        await db
            .execute('ALTER TABLE captured_photo ADD COLUMN remote_id TEXT');
      }
      if (!await _columnExists(db, 'captured_photo', 'remote_image_url')) {
        await db.execute(
          'ALTER TABLE captured_photo ADD COLUMN remote_image_url TEXT',
        );
      }
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_captured_photo_user_remote '
        'ON captured_photo(user_id, remote_id) WHERE remote_id IS NOT NULL '
        "AND remote_id != ''",
      );
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS field_cache (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          address TEXT NOT NULL DEFAULT '',
          updated_at TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_field_cache_user ON field_cache(user_id)',
      );
    }

    if (oldVersion < 10) {
      if (!await _columnExists(db, 'field_cache', 'preview_image_path')) {
        await db.execute(
          'ALTER TABLE field_cache ADD COLUMN preview_image_path TEXT',
        );
      }
      if (!await _columnExists(db, 'field_cache', 'image_count')) {
        await db.execute(
          'ALTER TABLE field_cache ADD COLUMN image_count INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 11) {
      if (!await _columnExists(db, 'field_cache', 'sync_pending')) {
        await db.execute(
          'ALTER TABLE field_cache ADD COLUMN sync_pending INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 12) {
      if (!await _columnExists(db, 'upload_queue', 'name_hint')) {
        await db.execute('ALTER TABLE upload_queue ADD COLUMN name_hint TEXT');
      }
    }
  }

  // --- Land CRUD ---

  Future<int> insertLand(Land land) async {
    final db = _db!;
    final coordsJson = jsonEncode(
      land.polygonCoordinates.map((p) => p.toJson()).toList(),
    );
    return db.insert('land', {
      'land_name': land.landName,
      'polygon_coordinates': coordsJson,
      'created_at': (land.createdAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<List<Land>> getAllLands() async {
    final rows = await _db!.query('land', orderBy: 'created_at DESC');
    return rows.map(_landFromRow).toList();
  }

  Future<Land?> getLandById(int id) async {
    final rows = await _db!.query('land', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _landFromRow(rows.first);
  }

  /// Local geo-fence row keyed by [Land.landName] (matches Supabase `fields.name`).
  Future<Land?> findLandByFieldName(String name) async {
    await initialize();
    final String n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final Land l in await getAllLands()) {
      if (l.landName.trim().toLowerCase() == n) return l;
    }
    return null;
  }

  /// When a field is renamed in Supabase, keep the local polygon linked.
  Future<void> renameLandMatchingFieldName({
    required String fromName,
    required String toName,
  }) async {
    final String a = fromName.trim();
    final String b = toName.trim();
    if (a.isEmpty || b.isEmpty) return;
    if (a.toLowerCase() == b.toLowerCase()) return;
    final Land? land = await findLandByFieldName(a);
    if (land == null || land.id == null) return;
    await updateLand(land.copyWith(landName: b));
  }

  /// JSON for Supabase [fields.boundary_json] (array of [LatLngPoint.toJson]).
  String? encodeLandBoundaryJsonForSupabase(Land? land) {
    if (land == null || land.polygonCoordinates.length < 3) return null;
    return jsonEncode(land.polygonCoordinates.map((p) => p.toJson()).toList());
  }

  /// Restores polygons from Supabase field rows into the local [land] table.
  Future<void> importFieldBoundariesFromSupabaseRows(
    List<Map<String, dynamic>> fieldRows,
  ) async {
    await initialize();
    for (final Map<String, dynamic> r in fieldRows) {
      final String name = (r['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      final List<LatLngPoint>? coords =
          parseFieldsBoundaryJson(r['boundary_json']);
      if (coords == null) continue;
      await upsertLandPolygonForFieldName(fieldName: name, coords: coords);
    }
  }

  /// Parses [fields.boundary_json] (array of `{ "lat", "lng" }`) for maps / import.
  static List<LatLngPoint>? parseFieldsBoundaryJson(dynamic raw) {
    if (raw == null) return null;
    try {
      final List<dynamic> list;
      if (raw is String) {
        final String s = raw.trim();
        if (s.isEmpty) return null;
        final Object? dec = jsonDecode(s);
        if (dec is! List<dynamic>) return null;
        list = dec;
      } else if (raw is List) {
        list = raw;
      } else {
        return null;
      }
      final List<LatLngPoint> out = <LatLngPoint>[];
      for (final dynamic e in list) {
        if (e is! Map) continue;
        final Map<String, dynamic> m = Map<String, dynamic>.from(e);
        final double? lat = (m['lat'] as num?)?.toDouble();
        final double? lng = (m['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        out.add(LatLngPoint(lat, lng));
      }
      return out.length >= 3 ? out : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertLandPolygonForFieldName({
    required String fieldName,
    required List<LatLngPoint> coords,
  }) async {
    await initialize();
    final Land? existing = await findLandByFieldName(fieldName);
    if (existing?.id != null) {
      await updateLand(
        existing!.copyWith(
          landName: fieldName,
          polygonCoordinates: coords,
        ),
      );
      return;
    }
    await insertLand(
      Land(
        landName: fieldName,
        polygonCoordinates: coords,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<int> updateLand(Land land) async {
    if (land.id == null) return 0;
    final coordsJson = jsonEncode(
      land.polygonCoordinates.map((p) => p.toJson()).toList(),
    );
    return _db!.update(
      'land',
      {
        'land_name': land.landName,
        'polygon_coordinates': coordsJson,
      },
      where: 'id = ?',
      whereArgs: [land.id],
    );
  }

  Future<int> deleteLand(int id) async {
    await _db!.update(
      'detection',
      {'land_id': null},
      where: 'land_id = ?',
      whereArgs: [id],
    );
    return _db!.delete('land', where: 'id = ?', whereArgs: [id]);
  }

  Land _landFromRow(Map<String, dynamic> row) {
    final coordsList =
        jsonDecode(row['polygon_coordinates'] as String) as List<dynamic>;
    final coords = coordsList
        .map((e) => LatLngPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return Land(
      id: row['id'] as int,
      landName: row['land_name'] as String,
      polygonCoordinates: coords,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }

  // --- Detection CRUD ---

  Future<int> insertDetection(DetectionRecord record) async {
    return _db!.insert('detection', {
      'image_path': record.imagePath,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'land_id': record.landId,
      'bug_count': record.bugCount,
      'confidence_score': record.confidenceScore,
      'timestamp': record.timestamp.toIso8601String(),
    });
  }

  Future<List<DetectionRecord>> getAllDetections() async {
    final rows = await _db!.query('detection', orderBy: 'timestamp DESC');
    return rows.map(_detectionFromRow).toList();
  }

  Future<List<DetectionRecord>> getDetectionsByLandId(int landId) async {
    final rows = await _db!.query(
      'detection',
      where: 'land_id = ?',
      whereArgs: [landId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(_detectionFromRow).toList();
  }

  DetectionRecord _detectionFromRow(Map<String, dynamic> row) =>
      DetectionRecord(
        id: row['id'] as int,
        imagePath: row['image_path'] as String,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        landId: row['land_id'] as int?,
        bugCount: row['bug_count'] as int,
        confidenceScore: (row['confidence_score'] as num).toDouble(),
        timestamp: DateTime.parse(row['timestamp'] as String),
      );

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // --- Upload queue (offline sync) ---

  Future<int> enqueueUpload({
    required String localImagePath,
    required int confidence,
    required int count,
    String? fieldId,
    double? latitude,
    double? longitude,
    String? nameHint,
  }) async {
    // Idempotency: if Save is triggered twice quickly, avoid inserting two
    // identical pending uploads for the same local file.
    final existing = await _db!.query(
      'upload_queue',
      columns: const <String>['id'],
      where: 'status = ? AND local_image_path = ?',
      whereArgs: <Object?>['pending', localImagePath],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return (existing.first['id'] as num).toInt();
    }

    return _db!.insert('upload_queue', {
      'local_image_path': localImagePath,
      'confidence': confidence,
      'count': count,
      'field_id': fieldId,
      'latitude': latitude,
      'longitude': longitude,
      'name_hint': nameHint,
      'status': 'pending',
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingUploads({int limit = 20}) async {
    return _db!.query(
      'upload_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Number of rows still waiting to upload to Supabase.
  Future<int> countPendingUploads() async {
    final List<Map<String, dynamic>> rows = await _db!.rawQuery(
      'SELECT COUNT(*) AS c FROM upload_queue WHERE status = ?',
      <Object?>['pending'],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markUploadSynced(int id) async {
    await _db!.update(
      'upload_queue',
      {
        'status': 'synced',
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markUploadFailed(int id, String error) async {
    await _db!.rawUpdate(
      '''
      UPDATE upload_queue
      SET status = ?,
          attempts = attempts + 1,
          last_error = ?
      WHERE id = ?
      ''',
      ['pending', error, id],
    );
  }

  Future<Map<String, dynamic>?> getUploadQueueById(int id) async {
    final rows = await _db!
        .query('upload_queue', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> updateUploadQueueField({
    required int id,
    String? fieldId,
  }) async {
    await _db!.update(
      'upload_queue',
      <String, Object?>{
        'field_id': fieldId,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  // --- Captured photos (local gallery) ---

  Future<int> insertCapturedPhoto({
    required String localImagePath,
    String? userId,
    required String fieldName,
    required int confidence,
    required int count,
    String? detectionsJson,
    String? fieldId,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    String? remoteId,
    String? remoteImageUrl,
  }) async {
    return _db!.insert('captured_photo', {
      'local_image_path': localImagePath,
      'field_name': fieldName,
      'field_id': fieldId,
      'confidence': confidence,
      'count': count,
      'detections_json': detectionsJson,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'remote_id': remoteId,
      'remote_image_url': remoteImageUrl,
    });
  }

  /// Placeholder path for rows hydrated from Supabase (no local JPEG file).
  static const String remoteOnlyLocalPath = '_remote_';

  /// Inserts a gallery row backed by cloud storage (after reinstall / sync).
  Future<int> insertCapturedPhotoFromRemote({
    required String userId,
    required String remoteId,
    required String remoteImageUrl,
    required String fieldName,
    required int confidence,
    required int count,
    String? fieldId,
    double? latitude,
    double? longitude,
    required DateTime createdAt,
    String? detectionsJson,
  }) async {
    return _db!.insert('captured_photo', {
      'local_image_path': remoteOnlyLocalPath,
      'field_name': fieldName,
      'field_id': fieldId,
      'confidence': confidence,
      'count': count,
      'detections_json': detectionsJson,
      'latitude': latitude,
      'longitude': longitude,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'remote_id': remoteId,
      'remote_image_url': remoteImageUrl,
    });
  }

  Future<void> linkCapturedPhotoToRemoteUpload({
    required String userId,
    required String localImagePath,
    required String remoteId,
    required String remoteImageUrl,
  }) async {
    // Match rows saved before sign-in (user_id NULL) or with the same account.
    await _db!.update(
      'captured_photo',
      <String, Object?>{
        'remote_id': remoteId,
        'remote_image_url': remoteImageUrl,
        'user_id': userId,
      },
      where: 'local_image_path = ? AND (user_id IS NULL OR user_id = ?)',
      whereArgs: <Object?>[localImagePath, userId],
    );
  }

  /// Re-queues local captures that never received [captured_photo.remote_id].
  ///
  /// This fixes "Nothing to sync" when [upload_queue] rows were missing (e.g. older
  /// builds) while photos still show in Manage Photos.
  Future<int> backfillPendingUploadsForUnsyncedCaptures(String userId) async {
    await initialize();
    if (userId.isEmpty) return 0;
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      where:
          '(remote_id IS NULL OR remote_id = ?) AND local_image_path IS NOT NULL '
          'AND local_image_path != ? AND (user_id = ? OR user_id IS NULL)',
      whereArgs: <Object?>['', remoteOnlyLocalPath, userId],
    );
    int added = 0;
    for (final Map<String, dynamic> r in rows) {
      final String path = (r['local_image_path'] as String?)?.trim() ?? '';
      if (path.isEmpty) continue;
      final List<Map<String, dynamic>> qRows = await _db!.query(
        'upload_queue',
        columns: const <String>['id'],
        where: 'local_image_path = ?',
        whereArgs: <Object?>[path],
        limit: 1,
      );
      if (qRows.isNotEmpty) continue;

      final String? rowUid = r['user_id'] as String?;
      if (rowUid == null || rowUid.isEmpty) {
        await _db!.update(
          'captured_photo',
          <String, Object?>{'user_id': userId},
          where: 'id = ?',
          whereArgs: <Object?>[r['id']],
        );
      }

      final int confidence = (r['confidence'] as num?)?.toInt() ?? 0;
      final int count = (r['count'] as num?)?.toInt() ?? 0;
      final String? fieldId = r['field_id'] as String?;
      final double? lat =
          r['latitude'] == null ? null : (r['latitude'] as num).toDouble();
      final double? lng =
          r['longitude'] == null ? null : (r['longitude'] as num).toDouble();
      final String? nameHint = r['field_name'] as String?;
      await enqueueUpload(
        localImagePath: path,
        confidence: confidence,
        count: count,
        fieldId: fieldId,
        latitude: lat,
        longitude: lng,
        nameHint: nameHint,
      );
      added++;
    }
    return added;
  }

  Future<bool> hasCapturedPhotoForRemoteIdGlobal(String remoteId) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      columns: <String>['id'],
      where: 'remote_id = ?',
      whereArgs: <Object?>[remoteId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> hasCapturedPhotoForRemoteImageUrlGlobal(
    String remoteImageUrl,
  ) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      columns: <String>['id'],
      where: 'remote_image_url = ?',
      whereArgs: <Object?>[remoteImageUrl],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, dynamic>?> getCapturedPhotoByRemoteId(String remoteId) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      where: 'remote_id = ?',
      whereArgs: <Object?>[remoteId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<bool> hasCapturedPhotoForRemoteId(
    String userId,
    String remoteId,
  ) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      columns: <String>['id'],
      where: 'user_id = ? AND remote_id = ?',
      whereArgs: <Object?>[userId, remoteId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> hasCapturedPhotoForRemoteImageUrl(
    String userId,
    String remoteImageUrl,
  ) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      columns: <String>['id'],
      where: 'user_id = ? AND remote_image_url = ?',
      whereArgs: <Object?>[userId, remoteImageUrl],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> getCapturedPhotos({
    int limit = 200,
    String? userId,
  }) async {
    return _db!.query(
      'captured_photo',
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : <Object?>[userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getCapturedPhotosForField({
    required String fieldId,
    int limit = 200,
    String? userId,
  }) async {
    final String where = userId == null
        ? 'field_id = ?'
        : 'field_id = ? AND (user_id IS NULL OR user_id = ?)';
    final List<Object?> args =
        userId == null ? <Object?>[fieldId] : <Object?>[fieldId, userId];
    return _db!.query(
      'captured_photo',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getUnexportedCapturedPhotos({
    int limit = 500,
    String? userId,
  }) async {
    final String where = userId == null
        ? 'exported_at IS NULL'
        : 'exported_at IS NULL AND user_id = ?';
    return _db!.query(
      'captured_photo',
      where: where,
      whereArgs: userId == null ? null : <Object?>[userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> markCapturedPhotosExported(List<int> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db!.update(
      'captured_photo',
      {'exported_at': now},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<Map<String, dynamic>?> getCapturedPhotoByLocalImagePath(
    String localImagePath,
  ) async {
    final String p = localImagePath.trim();
    if (p.isEmpty) return null;
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      where: 'local_image_path = ?',
      whereArgs: <Object?>[p],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> getCapturedPhotoById(int id) async {
    final rows =
        await _db!.query('captured_photo', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> updateCapturedPhotoField({
    required int id,
    required String fieldName,
    String? fieldId,
  }) async {
    await _db!.update(
      'captured_photo',
      <String, Object?>{
        'field_name': fieldName,
        'field_id': fieldId,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteCapturedPhoto(int id) async {
    return _db!
        .delete('captured_photo', where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> unassignCapturedPhotosForField({
    required String fieldId,
    String unassignedName = 'Field',
    String? userId,
  }) async {
    final String where =
        userId == null ? 'field_id = ?' : 'field_id = ? AND user_id = ?';
    final List<Object?> args =
        userId == null ? <Object?>[fieldId] : <Object?>[fieldId, userId];
    return _db!.update(
      'captured_photo',
      <String, Object?>{
        'field_id': null,
        'field_name': unassignedName,
      },
      where: where,
      whereArgs: args,
    );
  }

  /// Lists unassigned captured photos that have GPS coordinates.
  Future<List<Map<String, dynamic>>> getUnassignedCapturedPhotosWithLocation({
    String? userId,
    int limit = 3000,
  }) async {
    final String where = userId == null
        ? 'field_id IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL'
        : 'user_id = ? AND field_id IS NULL AND latitude IS NOT NULL AND longitude IS NOT NULL';
    return _db!.query(
      'captured_photo',
      columns: const <String>[
        'id',
        'local_image_path',
        'latitude',
        'longitude',
      ],
      where: where,
      whereArgs: userId == null ? null : <Object?>[userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Bulk-assign captured photos to a field (by ids).
  Future<void> assignCapturedPhotosToFieldByIds({
    required List<int> ids,
    required String fieldName,
    String? fieldId,
  }) async {
    if (ids.isEmpty) return;
    final String placeholders = List.filled(ids.length, '?').join(',');
    await _db!.update(
      'captured_photo',
      <String, Object?>{
        'field_name': fieldName,
        'field_id': fieldId,
      },
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Bulk-update pending upload_queue rows by local_image_path.
  Future<void> assignPendingUploadsToFieldByLocalPaths({
    required List<String> localImagePaths,
    String? fieldId,
  }) async {
    if (localImagePaths.isEmpty) return;
    final String placeholders =
        List.filled(localImagePaths.length, '?').join(',');
    await _db!.update(
      'upload_queue',
      <String, Object?>{
        'field_id': fieldId,
      },
      where: 'status = ? AND local_image_path IN ($placeholders)',
      whereArgs: <Object?>['pending', ...localImagePaths],
    );
  }

  Future<int> deleteCachedField({
    required String fieldId,
    required String userId,
  }) async {
    return _db!.delete(
      'field_cache',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[fieldId, userId],
    );
  }

  // --- Fields cache (for offline view) ---

  Future<void> cacheFieldsForUser({
    required String userId,
    required List<Map<String, dynamic>> fields,
  }) async {
    final Database db = _db!;
    await db.transaction((txn) async {
      for (final f in fields) {
        final String id = (f['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        final String name = (f['name'] as String?) ?? 'Field';
        final String address = (f['address'] as String?) ?? '';
        final String? previewImagePath = f['preview_image_path'] as String?;
        final int imageCount = (f['image_count'] as num?)?.toInt() ?? 0;
        final String? updatedAt = f['updated_at']?.toString();
        final String ownerId = () {
          final String? fromRow = (f['user_id'] as String?)?.trim();
          if (fromRow != null && fromRow.isNotEmpty) return fromRow;
          return userId;
        }();
        await txn.insert(
          'field_cache',
          <String, Object?>{
            'id': id,
            'user_id': ownerId,
            'name': name,
            'address': address,
            'preview_image_path': previewImagePath,
            'image_count': imageCount,
            'updated_at': updatedAt,
            'sync_pending': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getCachedFields({
    required String userId,
    int limit = 500,
  }) async {
    return _db!.query(
      'field_cache',
      where: 'user_id = ?',
      whereArgs: <Object?>[userId],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
  }

  /// All cached fields (e.g. JWT admin offline fallback).
  Future<List<Map<String, dynamic>>> getCachedFieldsAll({
    int limit = 2000,
  }) async {
    return _db!.query(
      'field_cache',
      orderBy: 'name COLLATE NOCASE ASC',
      limit: limit,
    );
  }

  /// Single cached field row (e.g. offline-created pending sync).
  Future<Map<String, dynamic>?> getCachedFieldById({
    required String userId,
    required String fieldId,
  }) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'field_cache',
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[fieldId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Cached field by primary key only (admin viewing another user's field).
  Future<Map<String, dynamic>?> getCachedFieldByIdOnly({
    required String fieldId,
  }) async {
    final List<Map<String, dynamic>> rows = await _db!.query(
      'field_cache',
      where: 'id = ?',
      whereArgs: <Object?>[fieldId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Latest displayable image per [field_id] from local [captured_photo].
  Future<Map<String, String>> latestCapturePreviewPathByFieldIds(
    List<String> fieldIds,
  ) async {
    if (fieldIds.isEmpty) return const <String, String>{};
    await initialize();
    final String placeholders = List<String>.filled(fieldIds.length, '?').join(',');
    final List<Map<String, dynamic>> rows = await _db!.rawQuery(
      '''
      SELECT field_id, remote_image_url, local_image_path, created_at
      FROM captured_photo
      WHERE field_id IN ($placeholders)
      ORDER BY created_at DESC
      ''',
      fieldIds,
    );
    final Map<String, String> out = <String, String>{};
    for (final Map<String, dynamic> r in rows) {
      final String? fid = r['field_id'] as String?;
      if (fid == null || fid.isEmpty || out.containsKey(fid)) continue;
      final String? path = _previewPathFromCaptureRow(r);
      if (path != null) out[fid] = path;
    }
    return out;
  }

  String? _previewPathFromCaptureRow(Map<String, dynamic> row) {
    final String? remote = row['remote_image_url'] as String?;
    if (remote != null && remote.trim().isNotEmpty) return remote.trim();
    final String? local = row['local_image_path'] as String?;
    if (local == null ||
        local.isEmpty ||
        local == remoteOnlyLocalPath) {
      return null;
    }
    return local;
  }

  /// Rows created offline and not yet inserted into Supabase.
  Future<List<Map<String, dynamic>>> getCachedFieldsPendingSync({
    required String userId,
  }) async {
    return _db!.query(
      'field_cache',
      where: 'user_id = ? AND sync_pending = 1',
      whereArgs: <Object?>[userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
  }

  /// Saves a field locally so it appears in My Fields offline; [syncPending]=1 until cloud insert.
  Future<void> upsertPendingLocalField({
    required String id,
    required String userId,
    required String name,
    required String address,
    String? previewImagePath,
    int imageCount = 0,
  }) async {
    await _db!.insert(
      'field_cache',
      <String, Object?>{
        'id': id,
        'user_id': userId,
        'name': name,
        'address': address,
        'preview_image_path': previewImagePath,
        'image_count': imageCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_pending': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markFieldCacheSynced({
    required String fieldId,
    required String userId,
  }) async {
    await _db!.update(
      'field_cache',
      <String, Object?>{'sync_pending': 0},
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[fieldId, userId],
    );
  }

  /// Updates the field assignment for a pending upload queue row that matches
  /// a given [localImagePath]. Used when the user reassigns a photo while offline.
  Future<void> updatePendingUploadQueueFieldForLocalImagePath({
    required String localImagePath,
    String? fieldId,
  }) async {
    await _db!.update(
      'upload_queue',
      <String, Object?>{
        'field_id': fieldId,
      },
      where: 'status = ? AND local_image_path = ?',
      whereArgs: <Object?>['pending', localImagePath],
    );
  }

  /// Counts local [captured_photo] rows per [field_id] for dashboard totals.
  ///
  /// Includes rows with [user_id] null (saved before sign-in) so assignments still show.
  Future<Map<String, int>> countCapturedPhotosGroupedByFieldId({
    required String userId,
  }) async {
    await initialize();
    final List<Map<String, dynamic>> rows = await _db!.rawQuery(
      '''
      SELECT field_id, COUNT(*) AS c FROM captured_photo
      WHERE field_id IS NOT NULL AND TRIM(field_id) != ''
        AND (user_id IS NULL OR user_id = ?)
      GROUP BY field_id
      ''',
      <Object?>[userId],
    );
    final Map<String, int> out = <String, int>{};
    for (final Map<String, dynamic> r in rows) {
      final String? fid = r['field_id'] as String?;
      if (fid == null || fid.trim().isEmpty) continue;
      final int n = (r['c'] as num?)?.toInt() ?? 0;
      if (n > 0) {
        out[fid] = n;
      }
    }
    return out;
  }

  /// Returns count + latest created_at for a field from local captured photos.
  Future<({int count, DateTime? latest})> getCapturedPhotoStatsForField({
    required String fieldId,
    String? userId,
  }) async {
    final String where = userId == null
        ? 'field_id = ?'
        : 'field_id = ? AND (user_id IS NULL OR user_id = ?)';
    final List<Object?> args =
        userId == null ? <Object?>[fieldId] : <Object?>[fieldId, userId];
    final List<Map<String, dynamic>> rows = await _db!.query(
      'captured_photo',
      columns: const <String>['created_at'],
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    final int count = Sqflite.firstIntValue(
          await _db!.rawQuery(
            'SELECT COUNT(*) FROM captured_photo WHERE $where',
            args,
          ),
        ) ??
        0;
    final DateTime? latest = rows.isEmpty
        ? null
        : DateTime.tryParse(rows.first['created_at']?.toString() ?? '');
    return (count: count, latest: latest);
  }
}
