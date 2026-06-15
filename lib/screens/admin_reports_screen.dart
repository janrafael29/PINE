library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/theme.dart';
import '../services/admin_reports_service.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/image_storage_service.dart';
import '../utils/friendly_datetime.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/pine_card.dart';
import '../widgets/action_popup.dart';
import 'captured_photo_detail_screen.dart';

/// DA/OMAG queue: positive farmer reports grouped by field.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({
    super.key,
    this.initialFilter = AdminReportFilter.all,
  });

  final AdminReportFilter initialFilter;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminReportsService _reports = AdminReportsService();
  final DatabaseService _db = DatabaseService();
  final ImageStorageService _images = ImageStorageService();
  final ExportService _export = ExportService();

  bool _loading = true;
  bool _exporting = false;
  AdminReportFilter _filter = AdminReportFilter.all;
  String? _error;
  List<AdminReportItem> _items = <AdminReportItem>[];
  List<AdminReportFieldGroup> _groups = <AdminReportFieldGroup>[];
  final Set<String> _expandedFieldKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _reload();
  }

  void _applyGroups(List<AdminReportItem> items) {
    _items = items;
    _groups = groupAdminReportsByField(items);
    _expandedFieldKeys.removeWhere(
      (String key) => !_groups.any((AdminReportFieldGroup g) => g.key == key),
    );
  }

  Future<void> _reload() async {
    if (!currentUserJwtStaff()) {
      setState(() {
        _loading = false;
        _error = 'Staff access required (admin or agriculturist).';
        _items = <AdminReportItem>[];
        _groups = <AdminReportFieldGroup>[];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!await ensureOnline(context)) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Internet required to load farmer reports.';
        });
        return;
      }
      await CapturedPhotosRemoteSync(databaseService: _db)
          .pullIntoLocalIfSignedIn(limit: 500);
      final List<AdminReportItem> rows =
          await _reports.fetchReports(filter: _filter);
      if (!mounted) return;
      setState(() {
        _applyGroups(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _toggleField(String key) {
    setState(() {
      if (_expandedFieldKeys.contains(key)) {
        _expandedFieldKeys.remove(key);
      } else {
        _expandedFieldKeys.add(key);
      }
    });
  }

  Future<void> _openReport(AdminReportItem item) async {
    await _db.initialize();
    await CapturedPhotosRemoteSync(databaseService: _db)
        .ensureLocalCaptureForDetection(item.detectionId);
    if (!mounted) return;
    Map<String, dynamic>? local =
        await _db.getCapturedPhotoByRemoteId(item.detectionId);
    if (!mounted) return;
    if (local != null) {
      final int? localId = (local['id'] as num?)?.toInt();
      if (localId != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CapturedPhotoDetailScreen(
              capturedPhotoId: localId,
            ),
          ),
        );
        if (mounted) await _reload();
        return;
      }
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CapturedPhotoDetailScreen(
          remoteDetectionId: item.detectionId,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _exportReviewed({String? fieldId}) async {
    if (_exporting) return;
    if (!await ensureOnline(context)) return;
    setState(() => _exporting = true);
    final ActionPopupController popup = ActionPopupController();
    popup.showBlockingProgress(context, message: 'Preparing export…');
    try {
      final ({String path, int count}) result =
          await _export.exportReviewedImagesCsvZip(fieldId: fieldId);
      popup.close();
      if (!mounted) return;
      await ActionPopup.showSuccess(
        context,
        message: ExportService.downloadSuccessMessage(
          result.path,
          count: result.count,
        ),
      );
    } catch (e) {
      popup.close();
      if (!mounted) return;
      await ActionPopup.showError(context, message: 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int pendingCount =
        _items.where((AdminReportItem i) => !i.hasExpertReply).length;
    final int reviewedCount =
        _items.where((AdminReportItem i) => i.hasExpertReply).length;

    return AppScaffold(
      title: 'Farmer reports',
      actions: <Widget>[
        IconButton(
          tooltip: 'Export reviewed images',
          onPressed: (_loading || _exporting || reviewedCount == 0)
              ? null
              : () => _exportReviewed(),
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'Reports are grouped by field. Expand a field to review captures '
              'and write agriculturist / OMAG advice per image.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
          if (!_loading && _error == null && _groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: PineCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    _SummaryStat(
                      value: '${_groups.length}',
                      label: 'Fields',
                    ),
                    _SummaryDivider(color: cs.outlineVariant),
                    _SummaryStat(
                      value: '${_items.length}',
                      label: 'Captures',
                    ),
                    _SummaryDivider(color: cs.outlineVariant),
                    _SummaryStat(
                      value: '$reviewedCount',
                      label: 'Reviewed',
                    ),
                    _SummaryDivider(color: cs.outlineVariant),
                    _SummaryStat(
                      value: '$pendingCount',
                      label: 'Pending',
                      highlight: pendingCount > 0,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == AdminReportFilter.all,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(() => _filter = AdminReportFilter.all);
                          _reload();
                        },
                ),
                ChoiceChip(
                  label: const Text('Positive only'),
                  selected: _filter == AdminReportFilter.positiveOnly,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(
                              () => _filter = AdminReportFilter.positiveOnly);
                          _reload();
                        },
                ),
                ChoiceChip(
                  label: const Text('Negative only'),
                  selected: _filter == AdminReportFilter.negativeOnly,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(
                              () => _filter = AdminReportFilter.negativeOnly);
                          _reload();
                        },
                ),
                ChoiceChip(
                  label: const Text('Pending reply'),
                  selected: _filter == AdminReportFilter.pendingReply,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(
                              () => _filter = AdminReportFilter.pendingReply);
                          _reload();
                        },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _groups.isEmpty
                        ? Center(
                            child: Text(
                              switch (_filter) {
                                AdminReportFilter.pendingReply =>
                                  'No positive reports waiting for agriculturist advice.',
                                AdminReportFilter.negativeOnly =>
                                  'No negative scans yet.',
                                AdminReportFilter.positiveOnly =>
                                  'No positive farmer reports yet.',
                                AdminReportFilter.all =>
                                  'No farmer reports yet.',
                              },
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: _groups.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int i) {
                                final AdminReportFieldGroup group = _groups[i];
                                return _FieldReportGroupCard(
                                  group: group,
                                  expanded:
                                      _expandedFieldKeys.contains(group.key),
                                  exporting: _exporting,
                                  onToggle: () => _toggleField(group.key),
                                  onOpenReport: _openReport,
                                  onExportField: group.fieldId == null ||
                                          group.fieldId!.isEmpty ||
                                          group.reviewedCount == 0
                                      ? null
                                      : () => _exportReviewed(
                                            fieldId: group.fieldId,
                                          ),
                                  images: _images,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? Colors.orange.shade800 : cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: color.withValues(alpha: 0.5),
    );
  }
}

class _FieldReportGroupCard extends StatelessWidget {
  const _FieldReportGroupCard({
    required this.group,
    required this.expanded,
    required this.exporting,
    required this.onToggle,
    required this.onOpenReport,
    required this.onExportField,
    required this.images,
  });

  final AdminReportFieldGroup group;
  final bool expanded;
  final bool exporting;
  final VoidCallback onToggle;
  final Future<void> Function(AdminReportItem item) onOpenReport;
  final VoidCallback? onExportField;
  final ImageStorageService images;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool hasPending = group.pendingCount > 0;

    return PineCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.landscape_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          group.fieldName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${group.farmerLabel} · ${group.captureCount} '
                          '${group.captureCount == 1 ? 'capture' : 'captures'}'
                          '${hasPending ? ' · ${group.pendingCount} pending' : ''}',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasPending)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${group.pendingCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  if (onExportField != null)
                    IconButton(
                      tooltip: 'Export reviewed for this field',
                      onPressed: exporting ? null : onExportField,
                      icon: const Icon(Icons.download_outlined, size: 20),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: <Widget>[
                Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < group.items.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 8),
                        _CaptureReportTile(
                          item: group.items[i],
                          onTap: () => onOpenReport(group.items[i]),
                          images: images,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

class _CaptureReportTile extends StatelessWidget {
  const _CaptureReportTile({
    required this.item,
    required this.onTap,
    required this.images,
  });

  final AdminReportItem item;
  final VoidCallback onTap;
  final ImageStorageService images;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String when = item.createdAtIso.isEmpty
        ? ''
        : formatFriendlyIso(item.createdAtIso);

    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: captureThumbnail(
                    localImagePath: DatabaseService.remoteOnlyLocalPath,
                    remoteImageUrl: item.imageUrl,
                    images: images,
                    displayLogicalWidth: 64,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Count ${item.count} · ${item.confidencePct}% confidence',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (when.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          when,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      item.hasExpertReply
                          ? 'Tap to view or edit advice'
                          : 'Tap to review and write advice',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.hasExpertReply
                      ? AppTheme.primaryGreen.withValues(alpha: 0.14)
                      : Colors.orange.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.hasExpertReply ? 'Replied' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: item.hasExpertReply
                        ? AppTheme.primaryGreen
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
