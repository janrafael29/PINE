library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_service.dart';
import '../services/detection_service.dart';
import '../services/export_service.dart';
import '../services/image_storage_service.dart';
import '../widgets/capture_activity_card.dart';
import '../widgets/app_scaffold.dart';
import 'captured_photo_detail_screen.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/action_popup.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/captured_photos_select_labels.dart';
import '../widgets/show_pine_bottom_sheet.dart';
import '../core/theme.dart';

String _capturedSelectUnassignedTitle(bool fil) {
  final String o = fil
      ? capturedPhotosSelectUnassignedTitleFil
      : capturedPhotosSelectUnassignedTitleEn;
  final String t = o.trim();
  if (t.isNotEmpty) return t;
  return fil ? 'Mga "Field" lang' : 'Only "Field" rows';
}

String _capturedSelectUnassignedSubtitle(bool fil) {
  final String o = fil
      ? capturedPhotosSelectUnassignedSubtitleFil
      : capturedPhotosSelectUnassignedSubtitleEn;
  final String t = o.trim();
  if (t.isNotEmpty) return t;
  return fil
      ? 'Mga hindi pa naka-assign sa isang partikular na field'
      : 'Items still using the generic Field label';
}

DateTime? _parseCapturedCreatedAt(Map<String, dynamic> row) {
  final Object? raw = row['created_at'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

/// Rows still using the generic [field_name] / unassigned label.
bool _isUnassignedFieldLabel(String? fieldName) {
  final String t = (fieldName ?? '').trim().toLowerCase();
  return t.isEmpty || t == 'field';
}

String _headingForCalendarDay(DateTime dayLocal, bool fil) {
  final DateTime now = DateTime.now();
  final DateTime t0 = DateTime(now.year, now.month, now.day);
  final DateTime d0 =
      DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  final int diff = d0.difference(t0).inDays;
  if (diff == 0) return fil ? 'Ngayon' : 'Today';
  if (diff == -1) return fil ? 'Kahapon' : 'Yesterday';
  if (diff == 1) return fil ? 'Bukas' : 'Tomorrow';
  return DateFormat.yMMMMd().format(d0);
}

class _CaptureListRow {
  const _CaptureListRow.header(this.title) : row = null;
  const _CaptureListRow.item(this.row) : title = null;
  final String? title;
  final Map<String, dynamic>? row;
  bool get isHeader => title != null;
}

List<_CaptureListRow> _buildCaptureListRows(
  List<Map<String, dynamic>> items,
  bool fil,
) {
  if (items.isEmpty) return <_CaptureListRow>[];
  final List<Map<String, dynamic>> sorted =
      List<Map<String, dynamic>>.from(items);
  sorted.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
    final DateTime? da = _parseCapturedCreatedAt(a);
    final DateTime? db = _parseCapturedCreatedAt(b);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });

  final List<_CaptureListRow> out = <_CaptureListRow>[];
  String? lastHeading;
  for (final Map<String, dynamic> row in sorted) {
    final DateTime? dt = _parseCapturedCreatedAt(row);
    final String heading;
    if (dt == null) {
      heading = fil ? 'Walang petsa' : 'No date';
    } else {
      final DateTime local = dt.toLocal();
      heading = _headingForCalendarDay(
        DateTime(local.year, local.month, local.day),
        fil,
      );
    }
    if (heading != lastHeading) {
      out.add(_CaptureListRow.header(heading));
      lastHeading = heading;
    }
    out.add(_CaptureListRow.item(row));
  }
  return out;
}

class CapturedPhotosScreen extends StatefulWidget {
  const CapturedPhotosScreen({super.key});

  @override
  State<CapturedPhotosScreen> createState() => _CapturedPhotosScreenState();
}

class _CapturedPhotosScreenState extends State<CapturedPhotosScreen> {
  late final DatabaseService _db;
  late final ImageStorageService _images;
  late final ExportService _export;

  bool _loading = true;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  bool _selectionMode = false;
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _images = ImageStorageService();
    _export = ExportService(databaseService: _db, imageStorageService: _images);
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CapturedPhotosRemoteSync(databaseService: _db)
          .pullIntoLocalIfSignedIn();
      if (!mounted) return;
      await _reload();
    });
  }

  Future<void> _reload() async {
    await _db.initialize();
    final String? userId =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    final bool jwtAdmin = currentUserJwtAdmin();
    final List<Map<String, dynamic>> list = await _db.getCapturedPhotos(
      limit: 500,
      userId: jwtAdmin ? null : userId,
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
      _selectedIds.removeWhere(
        (int id) => !list.any(
          (Map<String, dynamic> r) => (r['id'] as num).toInt() == id,
        ),
      );
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAllVisible() {
    if (_items.isEmpty) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          _items.map((Map<String, dynamic> r) => (r['id'] as num).toInt()),
        );
    });
  }

  void _selectAllFieldLabeledOnly() {
    if (_items.isEmpty) return;
    setState(() {
      _selectedIds.clear();
      for (final Map<String, dynamic> r in _items) {
        if (_isUnassignedFieldLabel(r['field_name'] as String?)) {
          _selectedIds.add((r['id'] as num).toInt());
        }
      }
    });
  }

  Future<void> _openSelectHowSheet(BuildContext context, bool fil) async {
    final String? choice = await showPineBottomSheet<String>(
      context: context,
      title: fil ? 'Piliin ang paraan' : 'Select how',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(fil ? 'Lahat ng larawan' : 'All pictures'),
              subtitle: Text(
                fil
                    ? 'Piliin ang lahat sa listahang ito'
                    : 'Select every item in this list',
              ),
              onTap: () => Navigator.pop(sheetContext, 'all'),
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(_capturedSelectUnassignedTitle(fil)),
              subtitle: Text(_capturedSelectUnassignedSubtitle(fil)),
              onTap: () => Navigator.pop(sheetContext, 'field'),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
    if (!mounted) return;
    if (choice == 'all') {
      _selectAllVisible();
      return;
    }
    if (choice == 'field') {
      final int n = _items
          .where(
            (Map<String, dynamic> r) =>
                _isUnassignedFieldLabel(r['field_name'] as String?),
          )
          .length;
      if (n == 0) {
        if (!context.mounted) return;
        await ActionPopup.showInfo(
          context,
          title: fil ? 'Walang match' : 'None found',
          message: fil
              ? 'Walang larawan na may label na "Field" sa listahang ito.'
              : 'No pictures with the generic "Field" label in this list.',
        );
        return;
      }
      _selectAllFieldLabeledOnly();
    }
  }

  Future<void> _refreshAndPushOffline() async {
    await CloudSyncService(databaseService: _db).syncPending(limit: 50);
    await CapturedPhotosRemoteSync(databaseService: _db).pullIntoLocalIfSignedIn();
    if (!mounted) return;
    await _reload();
    if (!mounted) return;
    context.read<AppState>().bumpCapturedPhotos();
  }

  Future<void> _bulkAssignToField(BuildContext context) async {
    if (_selectedIds.isEmpty) return;
    final Map<String, String>? picked = await _pickField(context);
    if (picked == null || !mounted) return;
    final String? fid = picked['id']?.trim().isNotEmpty == true
        ? picked['id']!.trim()
        : null;
    final String fname = picked['name'] ?? 'Field';
    await _db.initialize();
    final bool anyRemote = _items.any((Map<String, dynamic> row) {
      if (!_selectedIds.contains((row['id'] as num).toInt())) return false;
      final String? rid = row['remote_id'] as String?;
      return rid != null && rid.isNotEmpty;
    });
    bool canPatchRemote = false;
    if (anyRemote) {
      if (!mounted || !context.mounted) return;
      canPatchRemote = await ensureOnline(context);
    }
    if (!mounted || !context.mounted) return;

    int ok = 0;
    for (final Map<String, dynamic> row in _items) {
      final int id = (row['id'] as num).toInt();
      if (!_selectedIds.contains(id)) continue;
      final String localPath = row['local_image_path'] as String;
      final String? remoteId = row['remote_id'] as String?;
      await _db.updateCapturedPhotoField(
        id: id,
        fieldId: fid,
        fieldName: fname,
      );
      await _db.updatePendingUploadQueueFieldForLocalImagePath(
        localImagePath: localPath,
        fieldId: fid,
      );
      if (remoteId != null &&
          remoteId.isNotEmpty &&
          canPatchRemote) {
        try {
          await DetectionService().updateDetectionFieldAssignment(
            detectionId: remoteId,
            fieldId: fid,
          );
        } catch (_) {}
      }
      ok++;
    }

    if (!mounted || !context.mounted) return;
    context.read<AppState>().bumpCapturedPhotos();
    _exitSelectionMode();
    await _reload();
    if (!mounted || !context.mounted) return;
    final bool fil = context.read<AppState>().isFilipino;
    await ActionPopup.showSuccess(
      context,
      title: fil ? 'Field' : 'Field',
      message: fil
          ? 'Na-assign ang $ok (na) larawan.'
          : 'Assigned $ok picture${ok == 1 ? '' : 's'}.',
    );
  }

  Future<void> _exportNew(bool fil) async {
    final ActionPopupController popup = ActionPopupController();
    popup.showBlockingProgress(
      context,
      message: fil ? 'Inihahanda ang export…' : 'Preparing export…',
    );
    try {
      final String savedPath = await _export.exportCapturedPhotosZipNewOnly();
      popup.close();
      if (!mounted) return;
      await ActionPopup.showSuccess(
        context,
        title: fil ? 'Export' : 'Export',
        message: ExportService.downloadSuccessMessage(
          savedPath,
          filipino: fil,
        ),
      );
    } catch (e) {
      popup.close();
      if (!mounted) return;
      if (e is StateError &&
          e.message.contains('No new captured pictures')) {
        await ActionPopup.showInfo(
          context,
          title: fil ? 'Walang bago' : 'Nothing new',
          message: fil
              ? 'Walang bagong larawan na i-e-export.'
              : 'No new captured pictures to export.',
        );
      } else {
        await ActionPopup.showError(
          context,
          message: '$e',
        );
      }
    }
  }

  Future<void> _exportAll(bool fil) async {
    final ActionPopupController popup = ActionPopupController();
    popup.showBlockingProgress(
      context,
      message: fil ? 'Inihahanda ang export…' : 'Preparing export…',
    );
    try {
      final String savedPath = await _export.exportCapturedPhotosZipAll();
      popup.close();
      if (!mounted) return;
      await ActionPopup.showSuccess(
        context,
        title: fil ? 'Export' : 'Export',
        message: ExportService.downloadSuccessMessage(
          savedPath,
          filipino: fil,
        ),
      );
    } catch (e) {
      popup.close();
      if (!mounted) return;
      await ActionPopup.showError(
        context,
        message: 'Export failed: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;

    return AppScaffold(
      titleWidget: _selectionMode
          ? Text(
              fil
                  ? '${_selectedIds.length} napili'
                  : '${_selectedIds.length} selected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            )
          : Text(fil ? 'Mga Larawan' : 'Captured Pictures'),
      leading: _selectionMode
          ? IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _exitSelectionMode,
            )
          : null,
      actions: _selectionMode
          ? null
          : <Widget>[
              IconButton(
                tooltip: fil ? 'Maramihan' : 'Select multiple',
                icon: const Icon(Icons.checklist),
                onPressed: () => setState(() => _selectionMode = true),
              ),
              if (currentUserJwtStaff())
                PopupMenuButton<String>(
                  tooltip: fil ? 'Export' : 'Export',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String value) async {
                    if (value == 'export_new') {
                      await _exportNew(fil);
                    } else if (value == 'export_all') {
                      await _exportAll(fil);
                    }
                  },
                  itemBuilder: (BuildContext menuContext) =>
                      <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'export_new',
                      child: ListTile(
                        leading: const Icon(Icons.upload_outlined),
                        title: Text(fil ? 'Export bago' : 'Export new'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'export_all',
                      child: ListTile(
                        leading: const Icon(Icons.all_inbox_outlined),
                        title: Text(fil ? 'Export lahat' : 'Export all'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
      bottomNavigationBar: _selectionMode
          ? Material(
              elevation: 12,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _items.isEmpty
                              ? null
                              : () => _openSelectHowSheet(context, fil),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryGreen,
                            side: const BorderSide(
                              color: AppTheme.primaryGreen,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.checklist_rtl, size: 22),
                          label: Text(
                            fil ? 'Pumili…' : 'Select…',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _bulkAssignToField(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white70,
                            disabledBackgroundColor:
                                AppTheme.primaryGreen.withValues(alpha: 0.45),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: _selectedIds.isEmpty ? 0 : 2,
                          ),
                          icon: const Icon(Icons.drive_file_move_outline, size: 22),
                          label: Text(
                            fil ? 'I-assign sa field' : 'Assign to field',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshAndPushOffline,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: <Widget>[
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          fil
                              ? 'Wala pang nai-save na larawan.'
                              : 'No captured pictures yet.',
                        ),
                      ),
                    ],
                  )
                : Builder(
                    builder: (BuildContext context) {
                      final List<_CaptureListRow> displayRows =
                          _buildCaptureListRows(_items, fil);
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: displayRows.length,
                        itemBuilder: (BuildContext context, int i) {
                          final _CaptureListRow entry = displayRows[i];
                          if (entry.isHeader) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                4,
                                i == 0 ? 0 : 18,
                                4,
                                8,
                              ),
                              child: Text(
                                entry.title!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryGreen,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            );
                          }
                          final Map<String, dynamic> row = entry.row!;
                          final int id = (row['id'] as num).toInt();
                          final String fieldName =
                              (row['field_name'] as String?) ?? 'Field';
                          final String fieldLabel = fieldName;
                          final int confidence =
                              (row['confidence'] as num?)?.toInt() ?? 0;
                          final int count =
                              (row['count'] as num?)?.toInt() ?? 0;
                          final String localPath =
                              row['local_image_path'] as String;
                          final String? remoteUrl =
                              row['remote_image_url'] as String?;
                          final String? remoteId =
                              row['remote_id'] as String?;
                          final bool checked = _selectedIds.contains(id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                          if (_selectionMode) {
                            setState(() {
                              if (checked) {
                                _selectedIds.remove(id);
                              } else {
                                _selectedIds.add(id);
                              }
                            });
                            return;
                          }
                          final bool? assign = await showPineBottomSheet<bool>(
                            context: context,
                            title: fil ? 'Larawan' : 'Picture',
                            builder: (BuildContext sheetContext) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  ListTile(
                                    leading: const Icon(Icons.visibility),
                                    title: Text(
                                        fil ? 'Tingnan' : 'View details'),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, false),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.map),
                                    title: Text(
                                      fil
                                          ? 'Mag-assign sa field'
                                          : 'Assign to a field',
                                    ),
                                    subtitle: Text(
                                      fil
                                          ? 'I-tag ang capture na ito'
                                          : 'Tag this capture to one of your fields',
                                    ),
                                    onTap: () =>
                                        Navigator.pop(sheetContext, true),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          );

                          if (!context.mounted) return;
                          if (assign == true) {
                            if (!context.mounted) return;
                            final Map<String, String>? picked =
                                await _pickField(context);
                            if (picked == null) return;
                            await _db.initialize();
                            await _db.updateCapturedPhotoField(
                              id: id,
                              fieldId: picked['id'],
                              fieldName: picked['name'] ?? 'Field',
                            );
                            await _db.updatePendingUploadQueueFieldForLocalImagePath(
                              localImagePath: localPath,
                              fieldId: picked['id'],
                            );
                            if (remoteId != null && remoteId.isNotEmpty) {
                              if (context.mounted &&
                                  await ensureOnline(context)) {
                                await DetectionService()
                                    .updateDetectionFieldAssignment(
                                  detectionId: remoteId,
                                  fieldId: picked['id'],
                                );
                              }
                            }
                            if (!context.mounted) return;
                            context.read<AppState>().bumpCapturedPhotos();
                            await _reload();
                            if (!context.mounted) return;
                            await ActionPopup.showSuccess(
                              context,
                              title: fil ? 'Field' : 'Field',
                              message: fil
                                  ? 'Naka-assign sa field.'
                                  : 'Assigned to field.',
                            );
                            return;
                          }

                          if (!context.mounted) return;
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CapturedPhotoDetailScreen(
                                capturedPhotoId: id,
                              ),
                            ),
                          );
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (_selectionMode) ...<Widget>[
                                  Checkbox(
                                    value: checked,
                                    onChanged: (bool? v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedIds.add(id);
                                        } else {
                                          _selectedIds.remove(id);
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: CaptureActivityCard(
                                    fieldLabel: fieldLabel,
                                    mealybugCount: count,
                                    confidencePct: confidence,
                                    localImagePath: localPath,
                                    remoteImageUrl: remoteUrl,
                                    images: _images,
                                    createdAtIso:
                                        row['created_at'] as String?,
                                    filipino: fil,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

Future<Map<String, String>?> _pickField(BuildContext context) async {
  final String? uid =
      SupabaseClientProvider.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  return showPineBottomSheet<Map<String, String>>(
    context: context,
    title: 'Assign to field',
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return SizedBox(
        height: 360,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: fieldsRealtimeStreamOrderedByName(),
          builder: (context, snapshot) {
            final List<Map<String, dynamic>> rows =
                snapshot.data ?? const <Map<String, dynamic>>[];
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (rows.isEmpty) {
              return const SizedBox(
                height: 240,
                child: Center(child: Text('No fields yet.')),
              );
            }
            Widget fieldRows(Map<String, String> labels) {
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, int i) {
                  final Map<String, dynamic> r = rows[i];
                  final String id = (r['id'] as String?) ?? '';
                  final String name = (r['name'] as String?) ?? 'Field';
                  final String? ou = r['user_id'] as String?;
                  return ListTile(
                    leading: const Icon(Icons.landscape),
                    title: Text(name),
                    subtitle: currentUserJwtAdmin() &&
                            ou != null &&
                            ou.isNotEmpty
                        ? Text(
                            'Owner: ${ownerDisplayLabel(ou, labels)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.pop(
                      sheetContext,
                      <String, String>{'id': id, 'name': name},
                    ),
                  );
                },
              );
            }

            if (!currentUserJwtAdmin()) {
              return fieldRows(const <String, String>{});
            }
            return FutureBuilder<Map<String, String>>(
              future: fetchProfileOwnerLabelsForUserIds(
                fieldRowOwnerIdsForProfileFetch(rows),
              ),
              builder: (context, labelSnap) {
                return fieldRows(
                  labelSnap.data ?? const <String, String>{},
                );
              },
            );
          },
        ),
      );
    },
  );
}
