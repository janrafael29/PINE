/// Land boundary model for geo-fencing.
library;

/// Represents a land parcel with polygon boundary.
class Land {
  const Land({
    this.id,
    required this.landName,
    required this.polygonCoordinates,
    this.createdAt,
  });

  final int? id;
  final String landName;
  final List<LatLngPoint> polygonCoordinates;
  final DateTime? createdAt;

  Land copyWith({
    int? id,
    String? landName,
    List<LatLngPoint>? polygonCoordinates,
    DateTime? createdAt,
  }) {
    return Land(
      id: id ?? this.id,
      landName: landName ?? this.landName,
      polygonCoordinates: polygonCoordinates ?? this.polygonCoordinates,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'land_name': landName,
        'polygon_coordinates': polygonCoordinates
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'created_at': createdAt?.toIso8601String(),
      };

  factory Land.fromJson(Map<String, dynamic> json) {
    final coords = (json['polygon_coordinates'] as List<dynamic>?)
            ?.map((e) => LatLngPoint(
                  (e['lat'] as num).toDouble(),
                  (e['lng'] as num).toDouble(),
                ))
            .toList() ??
        <LatLngPoint>[];
    return Land(
      id: json['id'] as int?,
      landName: json['land_name'] as String? ?? '',
      polygonCoordinates: coords,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// A point with latitude and longitude.
class LatLngPoint {
  const LatLngPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  Map<String, double> toJson() => {'lat': latitude, 'lng': longitude};

  factory LatLngPoint.fromJson(Map<String, dynamic> json) => LatLngPoint(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );
}
