/// Popup when a DA access request was approved or rejected since last seen.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/da_request_notification_prefs.dart';
import '../core/staff_role_labels.dart';
import '../core/supabase_client.dart';
import '../services/da_access_request_service.dart';

Future<void> showDaAccessRequestOutcomeDialogIfNeeded(
  BuildContext context,
) async {
  if (currentUserJwtStaff()) return;

  final DaAccessRequestService service = DaAccessRequestService();
  final DaAccessRequestRow? row = await service.fetchLatestForCurrentUser();
  if (row == null || !context.mounted) return;

  final bool unseen = await isDaRequestStatusUnseen(
    status: row.status.name,
    reviewedAt: row.reviewedAt?.toUtc().toIso8601String(),
  );
  if (!unseen || !context.mounted) return;

  final bool approved = row.status == DaAccessRequestStatus.approved;
  final bool rejected = row.status == DaAccessRequestStatus.rejected;
  if (!approved && !rejected) return;

  final String? reviewNote = row.reviewNote?.trim();
  final String body = approved
      ? 'Your $staffRoleWithOmag staff access request was approved.\n\n'
          'Tap OK to sign out, then sign in again to unlock $staffToolsLabel '
          'on this device.'
      : 'Your $staffRoleWithOmag staff access request was not approved.'
          '${reviewNote != null && reviewNote.isNotEmpty ? '\n\nNote from admin: $reviewNote' : ''}\n\n'
          'Register as $staffRoleWithOmagLgu during sign-up to submit a new '
          'access request, or resubmit from More → $staffAccessCardTitle if '
          'you already have a staff account.';

  final String reviewedAtIso = row.reviewedAt?.toUtc().toIso8601String() ?? '';
  final String statusName = row.status.name;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        icon: Icon(
          approved ? Icons.check_circle_outline : Icons.info_outline,
          color: approved
              ? Theme.of(dialogContext).colorScheme.primary
              : Theme.of(dialogContext).colorScheme.error,
          size: 28,
        ),
        title: Text(approved ? 'Access approved' : 'Access not approved'),
        content: Text(body),
        actions: <Widget>[
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;

  await markDaRequestStatusSeen(
    status: statusName,
    reviewedAt: reviewedAtIso,
  );

  if (approved && context.mounted) {
    await SupabaseClientProvider.instance.client.auth.signOut();
    if (!context.mounted) return;
    await Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (Route<dynamic> route) => false,
    );
  }
}
