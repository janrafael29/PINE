/// More-tab card: full admin reviews pending DA access requests.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../services/da_access_request_service.dart';
import '../widgets/online_required_dialog.dart';

class DaAccessRequestAdminCard extends StatefulWidget {
  const DaAccessRequestAdminCard({super.key});

  @override
  State<DaAccessRequestAdminCard> createState() =>
      _DaAccessRequestAdminCardState();
}

class _DaAccessRequestAdminCardState extends State<DaAccessRequestAdminCard> {
  final DaAccessRequestService _service = DaAccessRequestService();

  List<DaAccessRequestRow> _pending = <DaAccessRequestRow>[];
  bool _loading = true;
  String? _error;
  String? _busyRequestId;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reload();
  }

  Future<void> _reload() async {
    if (!currentUserJwtFullAdmin()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pending = <DaAccessRequestRow>[];
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<DaAccessRequestRow> rows =
          await _service.fetchPendingForAdmin();
      if (!mounted) return;
      setState(() {
        _pending = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _review(String requestId, String action) async {
    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    if (action == 'reject') {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Reject request?'),
            content: const Text(
              'This farmer will not receive DA access. They can submit a new request later.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busyRequestId = requestId);
    try {
      await _service.reviewRequest(requestId: requestId, action: action);
      if (!mounted) return;
      if (action == 'approve') {
        await _showApprovedDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('DA request rejected.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
      await _reload();
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not review request: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyRequestId = null);
    }
  }

  Future<void> _showApprovedDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('DA access approved'),
          content: const Text(
            'The user now has DA access. Ask them to sign out and sign in again.',
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  String _requesterLabel(DaAccessRequestRow row) {
    final String? name = row.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String? email = row.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final String? uid = row.userId?.trim();
    if (uid != null && uid.isNotEmpty) return shortAppUserIdLabel(uid);
    return 'Unknown user';
  }

  @override
  Widget build(BuildContext context) {
    if (!currentUserJwtFullAdmin()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;

    Widget body;
    if (_loading) {
      body = const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      );
    } else if (_pending.isEmpty) {
      body = Text(
        'No pending requests. Farmers submit from More → DA / OMAG access.',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
      );
    } else {
      body = Column(
        children: <Widget>[
          for (int i = 0; i < _pending.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            _PendingRequestTile(
              row: _pending[i],
              label: _requesterLabel(_pending[i]),
              busy: _busyRequestId == _pending[i].id,
              onApprove: () => _review(_pending[i].id, 'approve'),
              onReject: () => _review(_pending[i].id, 'reject'),
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.admin_panel_settings_outlined,
                        color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'DA access requests',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!_loading)
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _busyRequestId == null ? _reload : null,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Approve to grant DA access. User must sign out and sign in again.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.row,
    required this.label,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final DaAccessRequestRow row;
  final String label;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? email = row.email?.trim();
    final String? note = row.note?.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (email != null && email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(email, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
          if (note != null && note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(note, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text('Approve DA'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
