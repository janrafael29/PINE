/// Popup when DA/OMAG left new advice on a farmer's capture.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/expert_reply_notification_prefs.dart';
import '../core/staff_role_labels.dart';
import '../core/theme.dart';
import '../screens/captured_photo_detail_screen.dart';
import '../services/captured_photos_remote_sync.dart';
import '../services/farmer_expert_reply_notifications_service.dart';

enum _ExpertReplyAction { ok, viewReport }

Future<void> showExpertReplyNotificationsIfNeeded(
  BuildContext context,
) async {
  if (currentUserJwtStaff()) return;

  await CapturedPhotosRemoteSync().pullIntoLocalIfSignedIn(limit: 500);

  final FarmerExpertReplyNotificationsService service =
      FarmerExpertReplyNotificationsService();

  while (context.mounted) {
    final List<FarmerExpertReplyNotice> unseen =
        await service.fetchUnseenForCurrentUser(limit: 20);
    if (unseen.isEmpty || !context.mounted) return;

    final FarmerExpertReplyNotice notice = unseen.first;
    final _ExpertReplyAction? action = await showDialog<_ExpertReplyAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _ExpertReplyDialog(notice: notice);
      },
    );

    if (!context.mounted) return;

    await markExpertReplySeen(
      detectionId: notice.detectionId,
      updatedAt: notice.updatedAtIso,
    );

    if (!context.mounted) return;

    if (action == _ExpertReplyAction.viewReport) {
      final int? localId = await CapturedPhotosRemoteSync()
          .ensureLocalCaptureForDetection(notice.detectionId);
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (BuildContext ctx, Animation<double> a1, _) {
            return CapturedPhotoDetailScreen(
              capturedPhotoId: localId,
              remoteDetectionId: notice.detectionId,
            );
          },
          transitionsBuilder: (
            BuildContext ctx,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 220),
        ),
      );
      return;
    }
  }
}

class _ExpertReplyDialog extends StatefulWidget {
  const _ExpertReplyDialog({required this.notice});

  final FarmerExpertReplyNotice notice;

  @override
  State<_ExpertReplyDialog> createState() => _ExpertReplyDialogState();
}

class _ExpertReplyDialogState extends State<_ExpertReplyDialog> {
  bool _preparingReport = true;
  bool _canOpenReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _prepareReport();
    });
  }

  Future<void> _prepareReport() async {
    try {
      await CapturedPhotosRemoteSync()
          .ensureLocalCaptureForDetection(widget.notice.detectionId);
      if (!mounted) return;
      setState(() {
        _preparingReport = false;
        _canOpenReport = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preparingReport = false;
        _canOpenReport = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FarmerExpertReplyNotice notice = widget.notice;
    final String actionLine = notice.actionType != null &&
            notice.actionType!.isNotEmpty
        ? 'Recommended action: ${notice.actionType}.'
        : '';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: cs.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Your report is ready',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textHeading,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Expert review',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'An $staffRoleWithOmag expert reviewed your capture for '
              '${notice.fieldName} and left advice:',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.cream.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.paleLime.withValues(alpha: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '"${notice.strategyPreview}"',
                    style: const TextStyle(
                      color: AppTheme.textBody,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (actionLine.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      actionLine,
                      style: const TextStyle(
                        color: AppTheme.textHeading,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _canOpenReport
                    ? () => Navigator.of(context).pop(_ExpertReplyAction.viewReport)
                    : null,
                child: _preparingReport
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Text(
                        'View report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_ExpertReplyAction.ok),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                  foregroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
