library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/detection_result.dart';
import '../core/map_tiles.dart';
import '../core/theme.dart';
import '../services/admin_reports_service.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../utils/severity_score.dart';
import '../utils/friendly_datetime.dart';
import '../widgets/detection_overlay_image.dart';
import '../widgets/esri_imagery_tile_layer.dart';
import '../widgets/severity_glow_marker.dart';
import '../widgets/action_popup.dart';
import '../core/staff_role_labels.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/pine_card.dart';
import '../core/admin_session.dart';
import '../core/expert_reply_notification_prefs.dart';
import '../core/supabase_client.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/expert_feedback_service.dart';
import '../utils/detection_report_status.dart';

class CapturedPhotoDetailScreen extends StatefulWidget {
  const CapturedPhotoDetailScreen({
    super.key,
    this.capturedPhotoId,
    this.remoteDetectionId,
  }) : assert(capturedPhotoId != null || remoteDetectionId != null);

  final int? capturedPhotoId;
  final String? remoteDetectionId;

  @override
  State<CapturedPhotoDetailScreen> createState() =>
      _CapturedPhotoDetailScreenState();
}

class _CaptureDetailData {
  const _CaptureDetailData({this.row, this.expertResponse});

  final Map<String, dynamic>? row;
  final Map<String, dynamic>? expertResponse;
}

class _CapturedPhotoDetailScreenState extends State<CapturedPhotoDetailScreen> {
  late final DatabaseService _db;
  late final ImageStorageService _images;
  late final ExpertFeedbackService _expertFeedback;
  late final AdminReportsService _adminReports;
  final TextEditingController _replyController = TextEditingController();
  String _replyAction = '';
  bool _replySaving = false;
  late Future<_CaptureDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _db = DatabaseService();
    _images = ImageStorageService();
    _expertFeedback = ExpertFeedbackService();
    _adminReports = AdminReportsService();
    _detailFuture = _loadDetail();
  }

  void _refreshDetail() {
    setState(() {
      _detailFuture = _loadDetail();
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<_CaptureDetailData> _loadDetail() async {
    await _db.initialize();
    Map<String, dynamic>? row;
    if (widget.capturedPhotoId != null) {
      row = await _db.getCapturedPhotoById(widget.capturedPhotoId!);
    } else if (widget.remoteDetectionId != null) {
      final String rid = widget.remoteDetectionId!.trim();
      row = await _db.getCapturedPhotoByRemoteId(rid);
      if (row == null) {
        await CapturedPhotosRemoteSync(databaseService: _db)
            .ensureLocalCaptureForDetection(rid);
        row = await _db.getCapturedPhotoByRemoteId(rid);
      }
      row ??= await _loadRemoteRow(rid);
    }
    Map<String, dynamic>? expert;
    final String? remoteId = row?['remote_id'] as String? ??
        widget.remoteDetectionId?.trim();
    if (remoteId != null && remoteId.isNotEmpty) {
      expert = await _expertFeedback.getResponseForDetection(remoteId);
    }
    if (expert != null && mounted) {
      _replyController.text = (expert['strategy_text'] as String?) ?? '';
      _replyAction = (expert['action_type'] as String?) ?? '';
      if (!currentUserJwtStaff()) {
        final String text = (expert['strategy_text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty && remoteId != null) {
          await markExpertReplySeen(
            detectionId: remoteId,
            updatedAt: (expert['updated_at'] as String?)?.trim(),
          );
        }
      }
    }
    return _CaptureDetailData(row: row, expertResponse: expert);
  }

  Future<Map<String, dynamic>?> _loadRemoteRow(String detectionId) async {
    final Map<String, dynamic>? det = currentUserJwtStaff()
        ? await _adminReports.fetchDetectionDetail(detectionId)
        : await CapturedPhotosRemoteSync(databaseService: _db)
            .fetchDetectionForCurrentUser(detectionId);
    if (det == null) return null;

    String fieldName = 'Field';
    final String? fieldId = det['field_id']?.toString();
    if (fieldId != null && fieldId.isNotEmpty) {
      try {
        final Object? raw = await SupabaseClientProvider.instance.client
            .from('fields')
            .select('name')
            .eq('id', fieldId)
            .maybeSingle();
        if (raw is Map && raw['name'] is String) {
          final String name = (raw['name'] as String).trim();
          if (name.isNotEmpty) fieldName = name;
        }
      } catch (_) {}
    }

    final dynamic rawDj = det['detections_json'];
    String? djStr;
    if (rawDj != null) {
      djStr = rawDj is String ? rawDj : rawDj.toString();
    }

    final num? confRaw = det['confidence'] as num?;
    final int confidence = confRaw == null
        ? 0
        : (confRaw <= 1 ? confRaw * 100 : confRaw).round().clamp(0, 100);

    return <String, dynamic>{
      'field_name': fieldName,
      'field_id': fieldId,
      'confidence': confidence,
      'count': (det['count'] as num?)?.toInt() ?? 0,
      'latitude': det['latitude'],
      'longitude': det['longitude'],
      'local_image_path': DatabaseService.remoteOnlyLocalPath,
      'remote_id': detectionId,
      'remote_image_url': det['image_url'],
      'created_at': det['created_at'],
      'detections_json': djStr,
    };
  }

  Future<Uint8List?> _loadCaptureBytes({
    required String localPath,
    String? remoteUrl,
  }) async {
    if (localPath != DatabaseService.remoteOnlyLocalPath) {
      final File? f = await _images.getImageFile(localPath);
      if (f != null) return f.readAsBytes();
    }
    final String? u = remoteUrl?.trim();
    if (u != null && u.isNotEmpty) {
      try {
        final http.Response r = await http.get(Uri.parse(u));
        if (r.statusCode == 200) return r.bodyBytes;
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: AppScaffold(
        title: 'Captured Picture',
        body: FutureBuilder<_CaptureDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final row = snapshot.data?.row;
          if (row == null) {
            return const Center(child: Text('Capture not found.'));
          }
          final Map<String, dynamic>? expert = snapshot.data?.expertResponse;
          final bool isStaff = currentUserJwtStaff();
          final bool isPositive = capturedPhotoRowIsPositive(row);

          final String fieldName = (row['field_name'] as String?) ?? 'Field';
          final String fieldLabel = fieldName;
          final int confidence = (row['confidence'] as num?)?.toInt() ?? 0;
          final int count = (row['count'] as num?)?.toInt() ?? 0;
          final double? lat = row['latitude'] == null
              ? null
              : (row['latitude'] as num).toDouble();
          final double? lng = row['longitude'] == null
              ? null
              : (row['longitude'] as num).toDouble();
          final String localPath = row['local_image_path'] as String;
          final String? remoteUrl = row['remote_image_url'] as String?;
          final String createdAtRaw = (row['created_at'] as String?) ?? '';
          final String createdAt =
              createdAtRaw.isEmpty ? '' : formatFriendlyIso(createdAtRaw);
          final List<Detection> detections = parseStoredDetectionsJson(
            row['detections_json'] as String?,
          );
          final double sev = severity01(
            bugCount: count,
            confidencePct: confidence,
          );

          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              FutureBuilder<Uint8List?>(
                future: _loadCaptureBytes(
                  localPath: localPath,
                  remoteUrl: remoteUrl,
                ),
                builder: (context, snap) {
                  final Uint8List? bytes = snap.data;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: bytes == null
                        ? Container(
                            height: 220,
                            color: colorScheme.surface,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.image_not_supported,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    remoteUrl == null || remoteUrl.isEmpty
                                        ? 'No image saved for this report.'
                                        : 'Could not load image. Check your connection and try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : InkWell(
                            onTap: () {
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => _SavedDetectionImageViewer(
                                    imageBytes: bytes,
                                    detections: detections,
                                  ),
                                ),
                              );
                            },
                            child: SizedBox(
                              height: 260,
                              width: double.infinity,
                              child: DetectionOverlayImage(
                                imageBytes: bytes,
                                detections: detections,
                              ),
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),
              PineCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fieldLabel,
                      style: (textTheme.titleMedium ?? const TextStyle())
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    _row(
                      'Report status',
                      capturedPhotoStatusLabel(row),
                    ),
                    _row('Mealybug Count', '$count'),
                    _row('Confidence', '$confidence%'),
                    if (detections.isNotEmpty)
                      _row(
                          'Detection Labels', '${detections.length} markers'),
                    if (createdAt.isNotEmpty) _row('Captured at', createdAt),
                    if (lat != null && lng != null)
                      _row('GPS',
                          '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'),
                  ],
                ),
              ),
              if (lat != null && lng != null) ...[
                const SizedBox(height: 14),
                PineCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.my_location,
                            color: severityColor(sev),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 180,
                          child: RepaintBoundary(
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(lat, lng),
                                initialZoom: 18,
                                maxZoom: MapTiles.maxZoomSatellite.toDouble(),
                                minZoom: 3,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.none,
                                ),
                              ),
                              children: [
                                EsriImageryTileLayer(
                                  maxZoom:
                                      MapTiles.maxZoomSatellite.toDouble(),
                                  maxNativeZoom:
                                      MapTiles.maxNativeZoomSatellite,
                                ),
                                MarkerLayer(
                                  markers: <Marker>[
                                    Marker(
                                      point: LatLng(lat, lng),
                                      width: 120,
                                      height: 120,
                                      alignment: Alignment.center,
                                      child: SeverityGlowMarker(
                                        severity01: sev,
                                        baseSize: 22,
                                        pulse: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (expert != null &&
                  (expert['strategy_text'] as String?)?.trim().isNotEmpty ==
                      true) ...<Widget>[
                const SizedBox(height: 14),
                PineCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderColor: AppTheme.primaryGreen.withValues(alpha: 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        expertAdviceTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        (expert['strategy_text'] as String?) ?? '',
                        style: const TextStyle(height: 1.35),
                      ),
                      if ((expert['action_type'] as String?)
                              ?.trim()
                              .isNotEmpty ==
                          true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Action: ${expert['action_type']}',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (isStaff && isPositive) ...<Widget>[
                const SizedBox(height: 14),
                PineCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        staffReplyTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _replyController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Treatment advice or next steps…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'da-action-${row['remote_id']}-$_replyAction',
                          ),
                          initialValue:
                              _replyAction.isEmpty ? null : _replyAction,
                          decoration: const InputDecoration(
                            labelText: 'Action',
                            border: OutlineInputBorder(),
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'monitor',
                              child: Text('Monitor'),
                            ),
                            DropdownMenuItem(
                              value: 'treat',
                              child: Text('Treat'),
                            ),
                            DropdownMenuItem(
                              value: 'inspect',
                              child: Text('Inspect'),
                            ),
                          ],
                          onChanged: (String? v) {
                            setState(() => _replyAction = v ?? '');
                          },
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _replySaving
                                ? null
                                : () async {
                                    final String? rid =
                                        row['remote_id'] as String?;
                                    if (rid == null || rid.trim().isEmpty) {
                                      await ActionPopup.showError(
                                        context,
                                        message:
                                            'Report not synced to cloud yet.',
                                      );
                                      return;
                                    }
                                    setState(() => _replySaving = true);
                                    try {
                                      await _expertFeedback.upsertResponse(
                                        detectionId: rid,
                                        strategyText: _replyController.text,
                                        actionType: _replyAction.isEmpty
                                            ? null
                                            : _replyAction,
                                      );
                                      if (!context.mounted) return;
                                      await ActionPopup.showSuccess(
                                        context,
                                        message: 'Advice saved for farmer.',
                                      );
                                      _refreshDetail();
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      await ActionPopup.showError(
                                        context,
                                        message: 'Save failed: $e',
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _replySaving = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              _replySaving ? 'Saving…' : 'Save agriculturist advice',
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ],
            ],
          );
        },
      ),
    ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedDetectionImageViewer extends StatelessWidget {
  const _SavedDetectionImageViewer({
    required this.imageBytes,
    required this.detections,
  });

  final Uint8List imageBytes;
  final List<Detection> detections;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'Saved Detection Preview',
      usePatternBackground: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ColoredBox(
            color: colorScheme.surface,
            child: DetectionOverlayImage(
              imageBytes: imageBytes,
              detections: detections,
            ),
          ),
        ),
      ),
    );
  }
}
