// My Fields view (Compact 12): Fields | Reminders tabs, bottom nav.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../services/database_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/pine_card.dart';
import 'main_dashboard_screen.dart';
import 'field_detail_screen.dart';
import '../utils/scan_flow.dart';
import 'edit_field_screen.dart';

class FieldsListScreen extends StatefulWidget {
  const FieldsListScreen({super.key, this.initialField});

  final String? initialField;

  @override
  State<FieldsListScreen> createState() => _FieldsListScreenState();
}

class _FieldsListScreenState extends State<FieldsListScreen> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Map<String, dynamic>>> _cachedFuture;

  @override
  void initState() {
    super.initState();
    _cachedFuture = _loadCached();
  }

  Future<List<Map<String, dynamic>>> _loadCached() async {
    await _db.initialize();
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return const <Map<String, dynamic>>[];
    if (currentUserJwtStaff()) {
      return _db.getCachedFieldsAll(limit: 2000);
    }
    return _db.getCachedFields(userId: uid);
  }

  Future<void> _refreshOnlineThenCache() async {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (!await NetworkReachability.isOnline()) {
      if (!mounted) return;
      setState(() {
        _cachedFuture = _loadCached();
      });
      return;
    }
    try {
      final List<Map<String, dynamic>> rows = await fieldsSelectForSession();
      await _db.initialize();
      await _db.cacheFieldsForUser(userId: uid, fields: rows);
      await _db.importFieldBoundariesFromSupabaseRows(rows);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _cachedFuture = _loadCached();
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    final textTheme = Theme.of(context).textTheme;
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: AppScaffold(
        title: 'My Fields',
        appBarBottom: const TabBar(
          tabs: <Tab>[
            Tab(text: 'Fields'),
            Tab(text: 'Reminders'),
          ],
        ),
        body: TabBarView(
          children: <Widget>[
            uid == null
                ? _buildEmptyFields(context)
                : RefreshIndicator(
                    onRefresh: _refreshOnlineThenCache,
                    child: FutureBuilder<bool>(
                      future: NetworkReachability.isOnline(),
                      builder: (context, onlineSnap) {
                        final bool online = onlineSnap.data == true;
                        if (online) {
                          return StreamBuilder<List<Map<String, dynamic>>>(
                            stream: fieldsRealtimeStream(),
                            builder: (BuildContext context,
                                AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                              final List<Map<String, dynamic>> docs =
                                  snapshot.data ?? const <Map<String, dynamic>>[];
                              if (docs.isNotEmpty) {
                                // Best-effort cache + local polygons for offline maps.
                                // ignore: discarded_futures
                                _db.cacheFieldsForUser(userId: uid, fields: docs);
                                // ignore: discarded_futures
                                _db.importFieldBoundariesFromSupabaseRows(docs);
                              }
                              if (!snapshot.hasData || snapshot.hasError) {
                                // Fall back to cached list if stream can't load.
                                return _CachedFieldsList(
                                  cachedFuture: _cachedFuture,
                                  textTheme: textTheme,
                                );
                              }
                              return _FieldsList(
                                rows: docs,
                                textTheme: textTheme,
                              );
                            },
                          );
                        }
                        return _CachedFieldsList(
                          cachedFuture: _cachedFuture,
                          textTheme: textTheme,
                        );
                      },
                    ),
                  ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Theme.of(context).hintColor,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'You Have No Reminders',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first photo and carry out your daily survey routines.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // ignore: discarded_futures
                        startFieldFirstScan(context);
                      },
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Add Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 2,
          onTap: (int index) {
            if (index == 0) {
              Navigator.pushAndRemoveUntil<void>(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const MainDashboardScreen()),
                (Route<dynamic> _) => false,
              );
            } else if (index == 1) {
              // ignore: discarded_futures
              startFieldFirstScan(context);
            } else if (index == 3) {
              Navigator.pushAndRemoveUntil<void>(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => const MainDashboardScreen()),
                (Route<dynamic> _) => false,
              );
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bug_report), label: 'Diagnose'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'My Fields'),
            BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }

  static Widget _buildEmptyFields(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.landscape_outlined,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No fields yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a field from the location picker in More.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CachedFieldsList extends StatelessWidget {
  const _CachedFieldsList({
    required this.cachedFuture,
    required this.textTheme,
  });

  final Future<List<Map<String, dynamic>>> cachedFuture;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: cachedFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              const SizedBox(height: 120),
              Center(
                child: Text(
                  'No fields yet (offline)',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            ],
          );
        }
        return _FieldsList(rows: rows, textTheme: textTheme);
      },
    );
  }
}

class _FieldsList extends StatelessWidget {
  const _FieldsList({
    required this.rows,
    required this.textTheme,
  });

  final List<Map<String, dynamic>> rows;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    if (!currentUserJwtStaff()) {
      return _fieldsListContent(context, const <String, String>{});
    }
    return FutureBuilder<Map<String, String>>(
      future: fetchProfileOwnerLabelsForUserIds(
        fieldRowOwnerIdsForProfileFetch(rows),
      ),
      builder: (BuildContext context,
          AsyncSnapshot<Map<String, String>> labelSnap) {
        return _fieldsListContent(
          context,
          labelSnap.data ?? const <String, String>{},
        );
      },
    );
  }

  Widget _fieldsListContent(
    BuildContext context,
    Map<String, String> ownerLabels,
  ) {
    final List<Map<String, dynamic>> fields = rows.map((Map<String, dynamic> data) {
      return <String, dynamic>{
        'fieldId': data['id'] as String,
        'name': data['name'] as String? ?? 'Field',
        'address': data['address'] as String? ?? '',
        'user_id': data['user_id'],
      };
    }).toList();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: fields.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> field = fields[index];
        final String? ou = field['user_id'] as String?;
        return PineCard(
          margin: const EdgeInsets.only(bottom: 8),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FieldDetailScreen(
                  fieldId: field['fieldId'] as String,
                  fieldName: field['name'] as String,
                ),
              ),
            );
          },
          child: Stack(
            children: <Widget>[
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  field['name'] as String,
                  style: (textTheme.titleMedium ?? const TextStyle())
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 4),
                    if (currentUserJwtStaff() &&
                        ou != null &&
                        ou.isNotEmpty)
                      Text(
                        'Owner: ${ownerDisplayLabel(ou, ownerLabels)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.pineTextSecondary,
                        ),
                      ),
                    if ((field['address'] as String).isNotEmpty)
                      Text(
                        'Address: ${field['address']}',
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: currentUserJwtFullAdmin()
                    ? Builder(
                        builder: (BuildContext editContext) {
                          final String? fieldId = field['fieldId'] as String?;
                          return IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit field',
                            onPressed: () {
                              if (fieldId == null) return;
                              Navigator.push<void>(
                                editContext,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      EditFieldScreen(fieldId: fieldId),
                                ),
                              );
                            },
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
