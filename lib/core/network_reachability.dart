/// Shared reachability checks for sync and UI gating.
library;

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

/// DNS-based check that the device can reach the public internet.
///
/// Used by [CloudSyncService] and [ensureOnline]; keep timeouts short for UI.
class NetworkReachability {
  NetworkReachability._();

  static const Duration _lookupTimeout = Duration(seconds: 2);

  /// Returns true if a network interface is available (Wi‑Fi, mobile, etc.).
  static Future<bool> hasUsableConnectivity() async {
    try {
      final List<ConnectivityResult> results =
          await Connectivity().checkConnectivity();
      if (results.isEmpty) {
        return true;
      }
      return results.any((ConnectivityResult r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  /// Best-effort: resolves a well-known host. False when offline or blocked.
  static Future<bool> isHostReachable({
    String host = 'example.com',
    Duration timeout = _lookupTimeout,
  }) async {
    try {
      final List<InternetAddress> result =
          await InternetAddress.lookup(host).timeout(timeout);
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Interface up and a quick DNS check (matches previous [CloudSyncService] behavior).
  static Future<bool> isOnline() async {
    if (!await hasUsableConnectivity()) {
      return false;
    }
    return isHostReachable();
  }
}
