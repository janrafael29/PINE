library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Central place to initialize and access Supabase.
class SupabaseClientProvider {
  SupabaseClientProvider._();

  static final SupabaseClientProvider instance =
      SupabaseClientProvider._();

  SupabaseClient? _client;
  Object? _initError;

  bool get isInitialized => _client != null;
  Object? get initError => _initError;

  SupabaseClient get client {
    final SupabaseClient? value = _client;
    if (value == null) {
      throw StateError('SupabaseClient not initialized. Call init() first.');
    }
    return value;
  }

  SupabaseClient? get clientOrNull => _client;

  /// Initializes Supabase using compile-time environment variables.
  ///
  /// You must provide:
  /// - `--dart-define=SUPABASE_URL=...`
  /// - `--dart-define=SUPABASE_ANON_KEY=...`
  Future<void> initFromEnv() async {
    const String url = String.fromEnvironment('SUPABASE_URL');
    const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (url.isEmpty || anonKey.isEmpty) {
      throw ArgumentError(
        'Missing Supabase env vars. Provide --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...',
      );
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
    _initError = null;
  }

  /// Attempts initialization. Returns false instead of throwing if missing.
  Future<bool> tryInitFromEnv() async {
    try {
      await initFromEnv();
      return true;
    } catch (e) {
      _initError = e;
      return false;
    }
  }
}

