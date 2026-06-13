// Shared models for field dashboard (field-level stats only).
library;

/// Field-level infestation and capture stats (no sub-plots).
class FieldData {
  const FieldData({
    required this.name,
    required this.infestationPercentage,
    required this.imageCount,
  });

  final String name;
  final double infestationPercentage;
  final int imageCount;
}
