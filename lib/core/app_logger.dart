/// Simple logging facade for PINE.
///
/// Uses [debugPrint] so logs are stripped in release builds.
/// Can be replaced with a package like `logger` later if needed.
library;

import 'package:flutter/foundation.dart';

/// Application logger; use instead of raw [debugPrint] or [print].
abstract final class AppLogger {
  AppLogger._();

  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('[PINE] $message');
    }
  }

  static void warn(String message, [Object? detail]) {
    if (kDebugMode) {
      debugPrint('[PINE] WARN: $message');
      if (detail != null) debugPrint('  $detail');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[PINE] ERROR: $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrint(stackTrace.toString());
    }
  }
}
