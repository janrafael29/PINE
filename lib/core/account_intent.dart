/// Farmer vs DA/OMAG/LGU staff choice stored on `profiles.account_intent`.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../services/da_access_request_service.dart';

enum AccountIntent { farmer, staff }

enum PostAuthStep { loading, staffOnboarding, dashboard }

class AccountIntentService {
  AccountIntentService({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.instance.client;

  final SupabaseClient _client;

  static AccountIntent? parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'farmer':
        return AccountIntent.farmer;
      case 'staff':
        return AccountIntent.staff;
      default:
        return null;
    }
  }

  Future<AccountIntent?> fetchCurrent() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final Object? raw = await _client
        .from('profiles')
        .select('account_intent')
        .eq('id', uid)
        .maybeSingle();
    if (raw is! Map) return null;
    return parse((raw['account_intent'] as String?)?.trim());
  }

  Future<void> setCurrent(AccountIntent intent) async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in required.');
    }
    await _client.from('profiles').update(<String, dynamic>{
      'account_intent': intent.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  Future<bool> staffNeedsOnboarding() async {
    final AccountIntent? intent = await fetchCurrent();
    if (intent != AccountIntent.staff) return false;
    final DaAccessRequestRow? latest =
        await DaAccessRequestService(client: _client).fetchLatestForCurrentUser();
    if (latest == null) return true;
    if (latest.status == DaAccessRequestStatus.rejected) return true;
    return false;
  }

  Future<PostAuthStep> resolvePostAuthStep() async {
    if (currentUserJwtStaff()) {
      return PostAuthStep.dashboard;
    }
    final AccountIntent? intent = await fetchCurrent();
    if (intent != AccountIntent.staff) {
      return PostAuthStep.dashboard;
    }
    if (await staffNeedsOnboarding()) {
      return PostAuthStep.staffOnboarding;
    }
    return PostAuthStep.dashboard;
  }
}
