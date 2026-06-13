// Single-field hub: stats from Supabase detections and Take Photo.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../utils/field_recency.dart';
import '../utils/friendly_datetime.dart';
import 'detections_map_screen.dart';
import 'permission_screens.dart';
import 'edit_field_screen.dart';
import 'manage_field_photos_screen.dart';
import 'field_history_screen.dart';
import '../services/database_service.dart';
import '../services/field_stats_service.dart';
import '../widgets/action_popup.dart';
import '../widgets/online_required_dialog.dart';
import 'land_map_screen.dart';
import '../models/land.dart';
import 'package:latlong2/latlong.dart';

/// Detail view for one field.
class FieldDetailScreen extends StatefulWidget {
  const FieldDetailScreen({
    super.key,
    required this.fieldId,
    required this.fieldName,
  });

  final String fieldId;
  final String fieldName;

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await recordFieldOpened(widget.fieldId);
      if (!mounted) return;
      context.read<AppState>().bumpFieldRecency();
    });
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseService localDb = DatabaseService();
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fieldName),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: (String v) async {
              if (v == 'history') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => FieldHistoryScreen(
                      fieldId: widget.fieldId,
                      fieldName: widget.fieldName,
                    ),
                  ),
                );
                return;
              }
              if (v == 'edit') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EditFieldScreen(fieldId: widget.fieldId),
                  ),
                );
                return;
              }
              if (v == 'boundary') {
                await localDb.initialize();
                final Land? existing =
                    await localDb.findLandByFieldName(widget.fieldName);
                const LatLng defaultCenter = LatLng(6.2167, 125.0667);
                final LatLng center = existing != null &&
                        existing.polygonCoordinates.isNotEmpty
                    ? LatLng(
                        existing.polygonCoordinates.first.latitude,
                        existing.polygonCoordinates.first.longitude,
                      )
                    : defaultCenter;
                if (!context.mounted) return;
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute<bool>(
                    builder: (_) => LandMapScreen(
                      land: existing,
                      initialLandName:
                          existing == null ? widget.fieldName : null,
                      initialCenter: center,
                      supabaseFieldId: widget.fieldId,
                    ),
                  ),
                );
                return;
              }
              if (v == 'manage') {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ManageFieldPhotosScreen(
                      fieldId: widget.fieldId,
                      fieldName: widget.fieldName,
                    ),
                  ),
                );
                return;
              }
              if (v == 'delete') {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete field?'),
                    content: const Text(
                      'This will delete the field. Photos will be unassigned (not deleted).',
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                // ignore: use_build_context_synchronously
                if (!await ensureOnline(context)) return;
                if (!context.mounted) return;
                try {
                  final String? uid =
                      SupabaseClientProvider.instance.client.auth.currentUser?.id;
                  // Unassign remote detections first (avoids FK issues if any).
                  await SupabaseClientProvider.instance.client
                      .from('detections')
                      .update(<String, dynamic>{'field_id': null})
                      .eq('field_id', widget.fieldId);
                  await SupabaseClientProvider.instance.client
                      .from('fields')
                      .delete()
                      .eq('id', widget.fieldId);
                  await localDb.initialize();
                  if (uid != null) {
                    await localDb.deleteCachedField(fieldId: widget.fieldId, userId: uid);
                  }
                  final Land? localLand =
                      await localDb.findLandByFieldName(widget.fieldName);
                  if (localLand?.id != null) {
                    await localDb.deleteLand(localLand!.id!);
                  }
                  await localDb.unassignCapturedPhotosForField(fieldId: widget.fieldId, userId: uid);
                  if (!context.mounted) return;
                  await ActionPopup.showSuccess(
                    context,
                    title: 'Deleted',
                    message: 'Field deleted.',
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  if (!context.mounted) return;
                  await ActionPopup.showError(context, message: '$e');
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('Field history'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Edit field'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'boundary',
                child: ListTile(
                  leading: Icon(Icons.draw_outlined),
                  title: Text('Update boundary'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manage',
                child: ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Manage photos'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete field'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<FieldImageStats>(
        future: loadFieldImageStats(fieldId: widget.fieldId, viewerUserId: uid),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final FieldImageStats stats =
              snap.data ?? const FieldImageStats(imageCount: 0);
          final int imageCount = stats.imageCount;
          final String lastUpdated = stats.lastUpdated == null
              ? 'Never'
              : formatFriendlyDateTime(stats.lastUpdated!);

          // Use local latest capture to compute a stable "infestation" preview even offline.
          // (Remote stream can lag; local shows what the user just did.)
          return FutureBuilder<Map<String, dynamic>?>(
            future: () async {
              await localDb.initialize();
              final List<Map<String, dynamic>> rows =
                  await localDb.getCapturedPhotosForField(
                fieldId: widget.fieldId,
                limit: 1,
                userId: uid,
              );
              return rows.isEmpty ? null : rows.first;
            }(),
            builder: (context, latestSnap) {
              final Map<String, dynamic>? latest = latestSnap.data;
              double infestationRate = 0;
              if (latest != null) {
                final int count = (latest['count'] as num?)?.toInt() ?? 0;
                final bool hasBugs = count > 0;
                infestationRate = hasBugs && count > 0
                    ? (count * 7).clamp(0, 100).toDouble()
                    : (hasBugs ? 25.0 : 0.0);
              }
              final bool isNewField = imageCount == 0;
              return _buildBody(
                context,
                imageCount: imageCount,
                infestationRate: infestationRate,
                lastUpdated: lastUpdated,
                isNewField: isNewField,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required int imageCount,
    required double infestationRate,
    required String lastUpdated,
    required bool isNewField,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppTheme.primaryGreen,
                  AppTheme.secondaryGreen,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: isNewField
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'No detections yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Run your first scan to see mealybug activity for this field.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      const Text(
                        'The fruit is',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${infestationRate.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Infested with Mealybug',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _buildStatItem(
                      Icons.image,
                      'Images Taken',
                      '$imageCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatItem(
                      Icons.calendar_today,
                      'Last Updated',
                      lastUpdated,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PhotoSourcePicker(
                      fieldName: widget.fieldName,
                      fieldId: widget.fieldId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Take Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DetectionsMapScreen(
                      fieldId: widget.fieldId,
                      fieldName: widget.fieldName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text('View detections map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryGreen,
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, color: AppTheme.primaryGreen, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textMedium,
          ),
        ),
      ],
    );
  }
}
