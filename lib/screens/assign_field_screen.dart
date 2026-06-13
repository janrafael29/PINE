// Pick a field for a saved capture (assign on Save).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin_session.dart';
import '../core/app_state.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../services/database_service.dart';

class AssignFieldScreen extends StatefulWidget {
  const AssignFieldScreen({
    super.key,
    this.initialFieldId,
    this.title = 'Choose a field',
    this.backToHomeOnCancel = false,
  });

  final String? initialFieldId;
  final String title;

  /// When true, back cancels the scan and returns to the dashboard home tab.
  final bool backToHomeOnCancel;

  @override
  State<AssignFieldScreen> createState() => _AssignFieldScreenState();
}

class _AssignFieldScreenState extends State<AssignFieldScreen> {
  final DatabaseService _db = DatabaseService();

  Future<List<Map<String, dynamic>>> _loadFields() async {
    await _db.initialize();
    final String uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) {
      // Signed out: no Supabase list; fall back to local cache if any.
      return _db.getCachedFields(userId: '', limit: 500);
    }

    List<Map<String, dynamic>> fields = const <Map<String, dynamic>>[];
    final bool online = await NetworkReachability.isOnline();
    if (online) {
      try {
        fields = await fieldsSelectForSession();
        // Best-effort: update cache for offline selection.
        // ignore: discarded_futures
        _db.cacheFieldsForUser(userId: uid, fields: fields);
        // ignore: discarded_futures
        _db.importFieldBoundariesFromSupabaseRows(fields);
      } catch (_) {
        // Fall back to cache.
      }
    }
    if (fields.isEmpty) {
      fields = currentUserJwtAdmin()
          ? await _db.getCachedFieldsAll(limit: 500)
          : await _db.getCachedFields(userId: uid, limit: 500);
    }
    return fields;
  }

  void _pickUnassigned() {
    Navigator.pop<Map<String, String?>>(context, <String, String?>{
      'id': null,
      'name': null,
    });
  }

  void _pickField(Map<String, dynamic> r) {
    final String id = (r['id'] as String?) ?? '';
    final String name = (r['name'] as String?) ?? 'Field';
    Navigator.pop<Map<String, String?>>(context, <String, String?>{
      'id': id,
      'name': name,
    });
  }

  void _handleBack() {
    if (widget.backToHomeOnCancel) {
      context.read<AppState>().requestDashboardHomeTab();
    }
    Navigator.pop<Map<String, String?>>(context);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? initial = widget.initialFieldId?.trim();

    return PopScope(
      canPop: !widget.backToHomeOnCancel,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop || !widget.backToHomeOnCancel) return;
        _handleBack();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.backToHomeOnCancel
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _handleBack,
              )
            : null,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadFields(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          final List<Map<String, dynamic>> fields =
              snap.data ?? const <Map<String, dynamic>>[];

          Widget? assignSubtitle(
            Map<String, dynamic> r,
            Map<String, String> labels,
          ) {
            final String addr = ((r['address'] as String?) ?? '').trim();
            final String? ou = r['user_id'] as String?;
            final List<Widget> lines = <Widget>[];
            if (currentUserJwtAdmin() &&
                ou != null &&
                ou.isNotEmpty) {
              lines.add(
                Text(
                  'Owner: ${ownerDisplayLabel(ou, labels)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            if (addr.isNotEmpty) {
              lines.add(
                Text(
                  addr,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              );
            }
            if (lines.isEmpty) return null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: lines,
            );
          }

          if (!currentUserJwtAdmin()) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.block),
                  title: const Text('Unassigned'),
                  subtitle:
                      const Text('Do not attach this photo to a field'),
                  onTap: _pickUnassigned,
                ),
                const Divider(height: 1),
                if (fields.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No fields found.\n\nOpen My Fields while online once to load/cached your fields.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  )
                else
                  for (final Map<String, dynamic> r in fields)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: ((initial != null && initial.isNotEmpty) &&
                                  ((r['id'] as String?) ?? '') == initial)
                              ? AppTheme.primaryGreen.withValues(alpha: 0.65)
                              : cs.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.landscape_outlined),
                        title: Text((r['name'] as String?) ?? 'Field'),
                        subtitle: assignSubtitle(
                          r,
                          const <String, String>{},
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickField(r),
                      ),
                    ),
              ],
            );
          }

          return FutureBuilder<Map<String, String>>(
            future: fetchProfileOwnerLabelsForUserIds(
              fieldRowOwnerIdsForProfileFetch(fields),
            ),
            builder: (BuildContext context,
                AsyncSnapshot<Map<String, String>> labelSnap) {
              final Map<String, String> labels =
                  labelSnap.data ?? const <String, String>{};
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('Unassigned'),
                    subtitle:
                        const Text('Do not attach this photo to a field'),
                    onTap: _pickUnassigned,
                  ),
                  const Divider(height: 1),
                  if (fields.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No fields found.\n\nOpen My Fields while online once to load/cached your fields.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  else
                    for (final Map<String, dynamic> r in fields)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: ((initial != null && initial.isNotEmpty) &&
                                    ((r['id'] as String?) ?? '') == initial)
                                ? AppTheme.primaryGreen.withValues(alpha: 0.65)
                                : cs.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.landscape_outlined),
                          title: Text((r['name'] as String?) ?? 'Field'),
                          subtitle: assignSubtitle(r, labels),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickField(r),
                        ),
                      ),
                ],
              );
            },
          );
        },
      ),
    ),
    );
  }
}

