library;

/// Local queue item for uploading detections when online.
class UploadQueueItem {
  const UploadQueueItem({
    required this.id,
    required this.localImagePath,
    required this.confidence,
    required this.count,
    required this.status,
    required this.createdAt,
    this.fieldId,
    this.latitude,
    this.longitude,
    this.lastError,
    this.attempts,
  });

  final int id;
  final String localImagePath; // relative path (ImageStorageService)
  final int confidence;
  final int count;
  final String status; // pending | synced | failed
  final DateTime createdAt;
  final String? fieldId;
  final double? latitude;
  final double? longitude;
  final String? lastError;
  final int? attempts;
}
