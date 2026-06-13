/// DA / OMAG access request workflow (farmer → admin approval).
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/admin_session.dart';
import '../core/supabase_client.dart';

enum DaAccessRequestStatus { pending, approved, rejected, none }

class DaAccessRequestRow {
  const DaAccessRequestRow({
    required this.id,
    required this.status,
    this.userId,
    this.note,
    this.reviewNote,
    this.createdAt,
    this.reviewedAt,
    this.displayName,
    this.email,
  });

  final String id;
  final DaAccessRequestStatus status;
  final String? userId;
  final String? note;
  final String? reviewNote;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? displayName;
  final String? email;

  static DaAccessRequestStatus _parseStatus(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'pending':
        return DaAccessRequestStatus.pending;
      case 'approved':
        return DaAccessRequestStatus.approved;
      case 'rejected':
        return DaAccessRequestStatus.rejected;
      default:
        return DaAccessRequestStatus.none;
    }
  }

  factory DaAccessRequestRow.fromMap(Map<String, dynamic> row) {
    return DaAccessRequestRow(
      id: (row['id'] as String?) ?? '',
      status: _parseStatus(row['status'] as String?),
      userId: (row['user_id'] as String?)?.trim(),
      note: (row['note'] as String?)?.trim(),
      reviewNote: (row['review_note'] as String?)?.trim(),
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'].toString())
          : null,
      reviewedAt: row['reviewed_at'] != null
          ? DateTime.tryParse(row['reviewed_at'].toString())
          : null,
      displayName: (row['display_name'] as String?)?.trim(),
      email: (row['email'] as String?)?.trim(),
    );
  }
}

class DaAccessRequestService {
  DaAccessRequestService({SupabaseClient? client})
      : _client = client ?? SupabaseClientProvider.instance.client;

  final SupabaseClient _client;

  /// Latest request for the signed-in user (any status), or null.
  Future<DaAccessRequestRow?> fetchLatestForCurrentUser() async {
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final Object? raw = await _client
        .from('da_access_requests')
        .select(
          'id, status, note, review_note, created_at, reviewed_at',
        )
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (raw is! Map) return null;
    return DaAccessRequestRow.fromMap(Map<String, dynamic>.from(raw));
  }

  /// Submits a new pending request. Caller must not already be staff.
  Future<void> submitRequest({String? note}) async {
    if (currentUserJwtStaff()) {
      throw StateError('You already have staff access.');
    }
    final String? uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Sign in required.');
    }

    final String trimmed = (note ?? '').trim();
    final Map<String, dynamic> row = <String, dynamic>{
      'user_id': uid,
      'status': 'pending',
      if (trimmed.isNotEmpty) 'note': trimmed,
    };

    try {
      await _client.from('da_access_requests').insert(row);
    } on PostgrestException catch (e) {
      final String msg = e.message.toLowerCase();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        throw StateError('You already have a pending DA access request.');
      }
      throw StateError(e.message);
    }
  }

  /// Pending requests for full admin review (More tab / mobile).
  Future<List<DaAccessRequestRow>> fetchPendingForAdmin() async {
    if (!currentUserJwtFullAdmin()) {
      throw StateError('Full admin access required.');
    }

    final Object raw = await _client
        .from('da_access_requests')
        .select('id, user_id, status, note, created_at')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    if (raw is! List) return const <DaAccessRequestRow>[];
    final List<Map<String, dynamic>> rows = raw
        .map((dynamic e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (rows.isEmpty) return const <DaAccessRequestRow>[];

    final List<String> userIds = rows
        .map((Map<String, dynamic> r) => (r['user_id'] as String?)?.trim())
        .whereType<String>()
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList();

    final Map<String, String> labels =
        await fetchProfileOwnerLabelsForUserIds(userIds);
    final Map<String, String> emails = await _fetchProfileEmails(userIds);

    return rows
        .map((Map<String, dynamic> r) {
          final String? uid = (r['user_id'] as String?)?.trim();
          return DaAccessRequestRow.fromMap(<String, dynamic>{
            ...r,
            if (uid != null && uid.isNotEmpty) 'display_name': labels[uid],
            if (uid != null && uid.isNotEmpty) 'email': emails[uid],
          });
        })
        .toList();
  }

  /// Approve or reject a pending request (edge function; full admin only).
  Future<void> reviewRequest({
    required String requestId,
    required String action,
    String? reviewNote,
  }) async {
    if (!currentUserJwtFullAdmin()) {
      throw StateError('Full admin access required.');
    }
    final String normalized = action.trim().toLowerCase();
    if (normalized != 'approve' && normalized != 'reject') {
      throw ArgumentError('action must be approve or reject');
    }

    final String trimmedNote = (reviewNote ?? '').trim();
    final Map<String, dynamic> body = <String, dynamic>{
      'request_id': requestId,
      'action': normalized,
      if (trimmedNote.isNotEmpty) 'review_note': trimmedNote,
    };

    final FunctionResponse response = await _client.functions.invoke(
      'pine-admin-review-da-request',
      body: body,
    );

    if (response.status != 200) {
      final Object? data = response.data;
      String message = 'Request failed';
      if (data is Map) {
        final Object? err = data['error'];
        if (err != null && err.toString().trim().isNotEmpty) {
          message = err.toString();
        }
      }
      throw StateError(message);
    }
  }

  Future<Map<String, String>> _fetchProfileEmails(List<String> userIds) async {
    if (userIds.isEmpty) return <String, String>{};
    final Map<String, String> out = <String, String>{};
    const int chunk = 80;
    for (int i = 0; i < userIds.length; i += chunk) {
      final int end = i + chunk > userIds.length ? userIds.length : i + chunk;
      final List<String> slice = userIds.sublist(i, end);
      try {
        final Object raw = await _client
            .from('profiles')
            .select('id, email')
            .inFilter('id', slice);
        if (raw is! List<dynamic>) continue;
        for (final Object? e in raw) {
          if (e is! Map) continue;
          final Map<String, dynamic> row = Map<String, dynamic>.from(e);
          final String? id = row['id'] as String?;
          final String? email = (row['email'] as String?)?.trim();
          if (id != null && email != null && email.isNotEmpty) {
            out[id] = email;
          }
        }
      } catch (_) {
        // Keep empty fallbacks.
      }
    }
    return out;
  }
}
