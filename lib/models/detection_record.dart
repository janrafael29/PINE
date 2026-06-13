/// Persisted detection record with geo-tagging metadata.
library;

/// A detection record stored in SQLite with geo metadata.
class DetectionRecord {
  const DetectionRecord({
    this.id,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    this.landId,
    required this.bugCount,
    required this.confidenceScore,
    required this.timestamp,
  });

  final int? id;
  final String imagePath;
  final double latitude;
  final double longitude;
  final int? landId;
  final int bugCount;
  final double confidenceScore;
  final DateTime timestamp;

  DetectionRecord copyWith({
    int? id,
    String? imagePath,
    double? latitude,
    double? longitude,
    int? landId,
    int? bugCount,
    double? confidenceScore,
    DateTime? timestamp,
  }) {
    return DetectionRecord(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      landId: landId ?? this.landId,
      bugCount: bugCount ?? this.bugCount,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'image_path': imagePath,
        'latitude': latitude,
        'longitude': longitude,
        'land_id': landId,
        'bug_count': bugCount,
        'confidence_score': confidenceScore,
        'timestamp': timestamp.toIso8601String(),
      };

  factory DetectionRecord.fromJson(Map<String, dynamic> json) =>
      DetectionRecord(
        id: json['id'] as int?,
        imagePath: json['image_path'] as String? ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        landId: json['land_id'] as int?,
        bugCount: json['bug_count'] as int? ?? 0,
        confidenceScore: (json['confidence_score'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
