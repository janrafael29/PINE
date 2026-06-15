library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/supabase_client.dart';
import '../services/database_service.dart';
import '../services/detection_service.dart';
import '../services/image_storage_service.dart';
import '../widgets/action_popup.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/online_required_dialog.dart';
import 'captured_photo_detail_screen.dart';

class ManageFieldPhotosScreen extends StatefulWidget {
  const ManageFieldPhotosScreen({
    super.key,
    required this.fieldId,
    required this.fieldName,
  });

  final String fieldId;
  final String fieldName;

  @override
  State<ManageFieldPhotosScreen> createState() => _ManageFieldPhotosScreenState();
}

class _ManageFieldPhotosScreenState extends State<ManageFieldPhotosScreen> {
  late final DatabaseService _db;
  late final ImageStorageService _images;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _images = ImageStorageService();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    await _db.initialize();
    final String? userId =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    return _db.getCapturedPhotosForField(
      fieldId: widget.fieldId,
      limit: 800,
      userId: userId,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _unassign(BuildContext context, Map<String, dynamic> row) async {
    final bool fil = context.read<AppState>().isFilipino;
    final int id = (row['id'] as num).toInt();
    final String? remoteId = row['remote_id'] as String?;
    if (!await ensureOnline(context)) return;
    await _db.initialize();
    await _db.updateCapturedPhotoField(
      id: id,
      fieldId: null,
      fieldName: 'Field',
    );
    if (remoteId != null && remoteId.isNotEmpty) {
      await DetectionService().updateDetectionFieldAssignment(
        detectionId: remoteId,
        fieldId: null,
      );
    }
    if (!context.mounted) return;
    context.read<AppState>().bumpCapturedPhotos();
    await ActionPopup.showSuccess(
      context,
      title: fil ? 'Field' : 'Field',
      message: fil ? 'Na-unassign ang larawan.' : 'Photo unassigned.',
    );
    await _refresh();
  }

  Future<void> _delete(BuildContext context, Map<String, dynamic> row) async {
    final bool fil = context.read<AppState>().isFilipino;
    final int id = (row['id'] as num).toInt();
    final String? remoteId = row['remote_id'] as String?;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(fil ? 'Burahin?' : 'Delete?'),
        content: Text(
          fil
              ? 'Tatanggalin ang larawan na ito sa device. Kapag online, tatanggalin din ang cloud record.'
              : 'This will remove the photo from this device. When online, the cloud record will also be deleted.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(fil ? 'Cancel' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(fil ? 'Delete' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _db.initialize();
    await _db.deleteCapturedPhoto(id);
    if (remoteId != null && remoteId.isNotEmpty) {
      // ignore: use_build_context_synchronously
      if (await ensureOnline(context)) {
        if (!context.mounted) return;
        try {
          await DetectionService().deleteDetection(detectionId: remoteId);
        } catch (_) {
          // best-effort
        }
      }
    }
    if (!context.mounted) return;
    context.read<AppState>().bumpCapturedPhotos();
    await ActionPopup.showSuccess(
      context,
      title: fil ? 'Deleted' : 'Deleted',
      message: fil ? 'Nabura ang larawan.' : 'Photo deleted.',
    );
    await _refresh();
  }

  Future<void> _openDetail(BuildContext context, int id) async {
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CapturedPhotoDetailScreen(capturedPhotoId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    return AppScaffold(
      title: fil ? 'Manage Photos' : 'Manage Photos',
      actions: <Widget>[
        IconButton(
          tooltip: fil ? 'Refresh' : 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      fil
                          ? 'Wala pang pictures sa field na ito.'
                          : 'No pictures in this field yet.',
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = items[i];
                final int id = (row['id'] as num).toInt();
                final int confidence = (row['confidence'] as num?)?.toInt() ?? 0;
                final int count = (row['count'] as num?)?.toInt() ?? 0;
                final String localPath = row['local_image_path'] as String;
                final String? remoteUrl = row['remote_image_url'] as String?;

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openDetail(context, id),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: captureThumbnail(
                                localImagePath: localPath,
                                remoteImageUrl: remoteUrl,
                                images: _images,
                                displayLogicalWidth: 72,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  widget.fieldName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mealybug Count: $count',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Confidence: $confidence%',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'view') {
                                await _openDetail(context, id);
                              } else if (v == 'unassign') {
                                await _unassign(context, row);
                              } else if (v == 'delete') {
                                await _delete(context, row);
                              }
                            },
                            itemBuilder: (_) => <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'view',
                                child: Text(fil ? 'View details' : 'View details'),
                              ),
                              PopupMenuItem<String>(
                                value: 'unassign',
                                child: Text(
                                  fil ? 'Unassign from field' : 'Unassign from field',
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(fil ? 'Delete' : 'Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
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

