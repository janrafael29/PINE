/// Live check that your Supabase project accepts REST calls with the anon key.
///
/// Run (replace values):
/// ```sh
/// flutter test test/integration/supabase_connection_test.dart ^
///   --dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co ^
///   --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
/// ```
///
/// - **Pass:** `profiles` exists and query returns (maybe empty rows).
/// - **Pass:** `profiles` missing but error `PGRST205` — URL + anon key still reach Supabase;
///   apply `supabase/migrations/*.sql` in the dashboard.
/// - **Fail:** wrong URL/key or no network.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

void main() {
  const String url = String.fromEnvironment('SUPABASE_URL');
  const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final bool configured = url.isNotEmpty && anonKey.isNotEmpty;

  test('Supabase: anon client reaches API (profiles table or schema pending)', () async {
    final SupabaseClient client = SupabaseClient(url, anonKey);
    try {
      final List<dynamic> rows =
          await client.from('profiles').select('id').limit(1);
      expect(rows, isA<List<dynamic>>());
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205') {
        expect(
          e.message,
          contains('profiles'),
          reason: 'Supabase is reachable; run SQL in supabase/migrations/ if you have not yet.',
        );
        return;
      }
      rethrow;
    }
  }, skip: configured
      ? false
      : 'Pass --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_ANON_KEY=...');
}
