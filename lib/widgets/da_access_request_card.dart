/// More-tab card: request DA/OMAG staff access (approval workflow).
library;

import 'package:flutter/material.dart';

import '../core/admin_session.dart';
import '../services/da_access_request_service.dart';
import '../widgets/online_required_dialog.dart';

class DaAccessRequestCard extends StatefulWidget {
  const DaAccessRequestCard({super.key});

  @override
  State<DaAccessRequestCard> createState() => _DaAccessRequestCardState();
}

class _DaAccessRequestCardState extends State<DaAccessRequestCard> {
  final DaAccessRequestService _service = DaAccessRequestService();
  final TextEditingController _noteController = TextEditingController();

  DaAccessRequestRow? _latest;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reload();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (currentUserJwtStaff()) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _latest = null;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final DaAccessRequestRow? row =
          await _service.fetchLatestForCurrentUser();
      if (!mounted) return;
      setState(() {
        _latest = row;
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

  Future<void> _showRequestSentDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Request sent'),
          content: const Text(
            'Your DA access request was sent. Please wait for confirmation '
            'from an administrator.',
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

  Future<void> _submit() async {
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await _service.submitRequest(note: _noteController.text);
      if (!mounted) return;
      _noteController.clear();
      await _showRequestSentDialog();
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
          content: Text('Could not submit request: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserJwtStaff()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            height: 88,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final DaAccessRequestRow? latest = _latest;
    final DaAccessRequestStatus status =
        latest?.status ?? DaAccessRequestStatus.none;

    Widget body;
    if (status == DaAccessRequestStatus.pending) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hourglass_top, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending admin review',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your DA/OMAG access request was submitted. '
            'Sign out and sign in again after an admin approves it.',
          ),
          if (latest?.note != null && latest!.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Your note: ${latest.note}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      );
    } else if (status == DaAccessRequestStatus.approved) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Approved — sign out and sign in again to activate DA access.',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (status == DaAccessRequestStatus.rejected) ...<Widget>[
            Text(
              'Your previous request was not approved.'
              '${latest?.reviewNote != null && latest!.reviewNote!.isNotEmpty ? ' ${latest.reviewNote}' : ''}',
              style: TextStyle(color: cs.error, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _noteController,
            enabled: !_submitting,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Optional note',
              hintText: 'Office, employee ID, or contact info',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_outlined, size: 20),
              label: Text(_submitting ? 'Sending…' : 'Request DA access'),
            ),
          ),
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
                    child: Icon(Icons.badge_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'DA / OMAG access',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) ...<Widget>[
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
                const SizedBox(height: 8),
              ],
              body,
            ],
          ),
        ),
      ),
    );
  }
}
