library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/theme.dart';
import '../services/admin_reports_service.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../utils/friendly_datetime.dart';
import '../widgets/capture_thumbnail.dart';
import '../widgets/online_required_dialog.dart';
import 'captured_photo_detail_screen.dart';

/// DA/OMAG queue: positive farmer reports with per-image advice entry.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final AdminReportsService _reports = AdminReportsService();
  final DatabaseService _db = DatabaseService();
  final ImageStorageService _images = ImageStorageService();

  bool _loading = true;
  bool _pendingOnly = false;
  String? _error;
  List<AdminReportItem> _items = <AdminReportItem>[];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!currentUserJwtStaff()) {
      setState(() {
        _loading = false;
        _error = 'Staff access required (admin or DA).';
        _items = <AdminReportItem>[];
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
      final List<AdminReportItem> rows = await _reports.fetchPositiveReports(
        pendingReplyOnly: _pendingOnly,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
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

  Future<void> _openReport(AdminReportItem item) async {
    await _db.initialize();
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer reports'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Positive mealybug sightings from all farmers. Open a report to write DA/OMAG advice per image.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('All positive'),
                  selected: !_pendingOnly,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(() => _pendingOnly = false);
                          _reload();
                        },
                ),
                ChoiceChip(
                  label: const Text('Pending reply'),
                  selected: _pendingOnly,
                  onSelected: _loading
                      ? null
                      : (bool v) {
                          if (!v) return;
                          setState(() => _pendingOnly = true);
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
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              _pendingOnly
                                  ? 'No positive reports waiting for DA advice.'
                                  : 'No positive farmer reports yet.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (BuildContext context, int i) {
                                final AdminReportItem item = _items[i];
                                final String when = item.createdAtIso.isEmpty
                                    ? ''
                                    : formatFriendlyIso(item.createdAtIso);
                                return Material(
                                  color: cs.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _openReport(item),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: SizedBox(
                                              width: 72,
                                              height: 72,
                                              child: captureThumbnail(
                                                localImagePath: DatabaseService
                                                    .remoteOnlyLocalPath,
                                                remoteImageUrl: item.imageUrl,
                                                images: _images,
                                                displayLogicalWidth: 72,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  item.fieldName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.farmerLabel,
                                                  style: TextStyle(
                                                    color: cs.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Count ${item.count} · ${item.confidencePct}% confidence',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (when.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 4),
                                                    child: Text(
                                                      when,
                                                      style: TextStyle(
                                                        color:
                                                            cs.onSurfaceVariant,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.hasExpertReply
                                                  ? AppTheme.primaryGreen
                                                      .withValues(alpha: 0.14)
                                                  : Colors.orange
                                                      .withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              item.hasExpertReply
                                                  ? 'Replied'
                                                  : 'Pending',
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
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
