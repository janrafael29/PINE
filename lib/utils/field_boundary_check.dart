/// Checks whether a GPS point lies inside a field's boundary polygon.
library;

import '../core/supabase_client.dart';
import '../models/land.dart';
import '../services/database_service.dart';
import '../services/geo_fence_service.dart';

/// Result of checking capture location against the user-chosen field.
enum FieldBoundarySaveGate {
  /// No field selected (unassigned) — save allowed without boundary check.
  unassigned,

  /// Field has no drawable boundary — save allowed (cannot verify).
  noBoundary,

  /// Point is inside the selected field polygon.
  inside,

  /// GPS missing — cannot verify.
  locationRequired,

  /// GPS present but outside the selected field polygon.
  outside,
}

/// Loads boundary ring for [fieldName] / [fieldId] from local land cache or field_cache.
Future<List<LatLngPoint>?> loadFieldBoundaryRing(
  DatabaseService db, {
  String? fieldId,
  required String fieldName,
}) async {
  await db.initialize();
  final Land? land = await db.findLandByFieldName(fieldName);
  if (land != null && land.polygonCoordinates.length >= 3) {
    return land.polygonCoordinates;
  }

  final String fid = fieldId?.trim() ?? '';
  if (fid.isEmpty) return null;

  final String? uid =
      SupabaseClientProvider.instance.client.auth.currentUser?.id;
  if (uid == null || uid.isEmpty) return null;

  final Map<String, dynamic>? row = await db.getCachedFieldById(
    userId: uid,
    fieldId: fid,
  );
  return DatabaseService.parseFieldsBoundaryJson(row?['boundary_json']);
}

/// Whether the user may save a capture for the chosen field at ([latitude], [longitude]).
Future<FieldBoundarySaveGate> fieldBoundarySaveGate({
  required DatabaseService db,
  String? fieldId,
  required String fieldName,
  required double? latitude,
  required double? longitude,
}) async {
  final String fid = fieldId?.trim() ?? '';
  final String name = fieldName.trim();
  final bool hasField =
      fid.isNotEmpty && name.isNotEmpty && !_isUnassignedFieldLabel(name);

  if (!hasField) {
    return FieldBoundarySaveGate.unassigned;
  }

  if (latitude == null || longitude == null) {
    return FieldBoundarySaveGate.locationRequired;
  }

  final List<LatLngPoint>? ring = await loadFieldBoundaryRing(
    db,
    fieldId: fid,
    fieldName: name,
  );
  if (ring == null || ring.length < 3) {
    return FieldBoundarySaveGate.noBoundary;
  }

  final bool inside = pointInPolygonForRing(latitude, longitude, ring);
  return inside ? FieldBoundarySaveGate.inside : FieldBoundarySaveGate.outside;
}

bool _isUnassignedFieldLabel(String name) {
  final String n = name.trim().toLowerCase();
  return n.isEmpty || n == 'unassigned' || n == 'walang field' || n == 'field';
}
