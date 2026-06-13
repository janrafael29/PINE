/// Geo-tagging service: GPS acquisition with permission handling.
///
/// Captures device location at detection time. Uses last known location
/// as fallback when GPS signal is weak. Async to avoid blocking UI.
library;

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a location acquisition attempt.
class GeoLocationResult {
  const GeoLocationResult({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.isLastKnown = false,
    this.error,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool isLastKnown;
  final String? error;

  bool get isSuccess => error == null && latitude != null && longitude != null;
}

/// Service for acquiring GPS coordinates with fallback logic.
class GeoService {
  Position? _lastKnownPosition; // ignore: unused_field

  /// Requests location permission. Returns true if granted.
  Future<bool> requestPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Checks if location permission is granted.
  Future<bool> hasPermission() async {
    return await Permission.locationWhenInUse.isGranted;
  }

  /// Checks if location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Acquires current position. Uses last known location as fallback
  /// when GPS signal is weak or timeout occurs.
  Future<GeoLocationResult> getCurrentPosition() async {
    return _getCurrentPositionImpl();
  }

  /// Gets last known (cached) position without waiting for fresh fix.
  /// Useful when user denies permission or GPS is unavailable.
  Future<GeoLocationResult?> getLastKnownPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        _lastKnownPosition = pos;
        return GeoLocationResult(
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          isLastKnown: true,
        );
      }
    } catch (e) {
      return GeoLocationResult(
        error: e.toString(),
      );
    }
    return null;
  }
}

Future<GeoLocationResult> _getCurrentPositionImpl() async {
  try {
    // Check service enabled
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return GeoLocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracy: last.accuracy,
          isLastKnown: true,
        );
      }
      return const GeoLocationResult(
        error: 'Location services disabled',
      );
    }

    // Try fresh position with timeout (geolocator 11.x API)
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 18),
    );

    return GeoLocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      isLastKnown: false,
    );
  } catch (e) {
    // Fallback to last known
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return GeoLocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracy: last.accuracy,
          isLastKnown: true,
        );
      }
    } catch (_) {}

    return GeoLocationResult(
      error: e.toString(),
    );
  }
}
