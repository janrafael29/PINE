/// More-tab card: full admin reviews pending DA access requests.
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../core/staff_role_labels.dart';
import '../services/da_access_request_service.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/pine_card.dart';

class DaAccessRequestAdminCard extends StatefulWidget {
  const DaAccessRequestAdminCard({super.key, this.fullScreen = false});

  final bool fullScreen;

  @override
  State<DaAccessRequestAdminCard> createState() =>
      DaAccessRequestAdminCardState();
}

class DaAccessRequestAdminCardState extends State<DaAccessRequestAdminCard> {
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

  Future<void> reload() => _reload();

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
              'This user will not receive agriculturist access. They can '
              'register again as staff or submit a new request after sign-up.',
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
    } else if (action == 'approve') {
      DaAccessRequestRow? row;
      for (final DaAccessRequestRow candidate in _pending) {
        if (candidate.id == requestId) {
          row = candidate;
          break;
        }
      }
      if (row != null) {
        final DaAccessRequestRow approvedRow = row;
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Approve $staffRoleSingular access?'),
              content: Text(
                '${_requesterLabel(approvedRow)} wants access as ${_organizationLabel(approvedRow)} staff.\n\n'
                'They must sign out and sign in again after approval.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
        if (confirmed != true || !mounted) return;
      }
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
            content: Text('$staffRoleSingular access request rejected.'),
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
          title: Text('$staffRoleSingular access approved'),
          content: Text(
            'The user now has agriculturist access. Ask them to sign out '
            'and sign in again.',
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
    final String? full = row.fullName?.trim();
    if (full != null && full.isNotEmpty) return full;
    final String? name = row.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final String? email = row.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final String? uid = row.userId?.trim();
    if (uid != null && uid.isNotEmpty) return shortAppUserIdLabel(uid);
    return 'Unknown user';
  }

  String _organizationLabel(DaAccessRequestRow row) {
    final String? org = row.organization?.trim();
    return (org != null && org.isNotEmpty) ? org : 'unspecified organization';
  }

  @override
  Widget build(BuildContext context) {
    if (!currentUserJwtFullAdmin()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;

    if (widget.fullScreen) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: <Widget>[
                    _PendingCountChip(count: _pending.length, loading: _loading),
                    const Spacer(),
                    Text(
                      '${_pending.length} pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 40, color: cs.error),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.error, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_pending.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.inbox_outlined,
                        size: 52,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No pending requests',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        staffAccessEmptyAdminHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        staffAccessEmptyAdminFollowUp,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int i) {
                      final DaAccessRequestRow row = _pending[i];
                      return Padding(
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                        child: _PendingRequestTile(
                          row: row,
                          label: _requesterLabel(row),
                          organization: _organizationLabel(row),
                          busy: _busyRequestId == row.id,
                          onApprove: () => _review(row.id, 'approve'),
                          onReject: () => _review(row.id, 'reject'),
                        ),
                      );
                    },
                    childCount: _pending.length,
                  ),
                ),
              ),
          ],
        ),
      );
    }

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
        staffAccessEmptyEmbedded,
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
              organization: _organizationLabel(_pending[i]),
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
      child: PineCard(
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
                    staffAccessRequestsTitle,
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
              'Approve to grant agriculturist access. User must sign out '
              'and sign in again.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  const _PendingRequestTile({
    required this.row,
    required this.label,
    required this.organization,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final DaAccessRequestRow row;
  final String label;
  final String organization;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  Widget _detail(String title, String? value, ColorScheme cs) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 104,
            child: Text(
              title,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value.trim(), style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? email = row.email?.trim();
    final String? note = row.note?.trim();

    return PineCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      organization,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB8560F),
                  ),
                ),
              ),
            ],
          ),
          if (email != null && email.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(email, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ],
          _detail('Office', row.companyLocation, cs),
          _detail('Position', row.position, cs),
          if (note != null && note.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              note,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
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

class _PendingCountChip extends StatelessWidget {
  const _PendingCountChip({required this.count, required this.loading});

  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        loading ? 'Loading…' : 'Review queue',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
