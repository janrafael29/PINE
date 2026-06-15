/// More-tab card: request DA/OMAG staff access (approval workflow).
library;

import 'package:flutter/material.dart';

import '../core/account_intent.dart';
import '../core/admin_session.dart';
import '../core/staff_role_labels.dart';
import '../services/da_access_request_service.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/pine_card.dart';

class DaAccessRequestCard extends StatefulWidget {
  const DaAccessRequestCard({super.key, this.onRequestStatusSeen});

  final VoidCallback? onRequestStatusSeen;

  @override
  State<DaAccessRequestCard> createState() => _DaAccessRequestCardState();
}

class _DaAccessRequestCardState extends State<DaAccessRequestCard> {
  final DaAccessRequestService _service = DaAccessRequestService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  DaAccessRequestRow? _latest;
  AccountIntent? _accountIntent;
  bool _loading = true;
  bool _submitting = false;
  bool _formExpanded = false;
  bool _staffConfirmed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _reload();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationController.dispose();
    _locationController.dispose();
    _positionController.dispose();
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
      final AccountIntent? intent =
          await AccountIntentService().fetchCurrent();
      final DaAccessRequestRow? row =
          await _service.fetchLatestForCurrentUser();
      if (!mounted) return;
      if (row != null &&
          (row.status == DaAccessRequestStatus.approved ||
              row.status == DaAccessRequestStatus.rejected)) {
        widget.onRequestStatusSeen?.call();
      }
      if (!mounted) return;
      setState(() {
        _accountIntent = intent;
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

  bool _formIsComplete() {
    return _fullNameController.text.trim().isNotEmpty &&
        _organizationController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        _positionController.text.trim().isNotEmpty;
  }

  Future<bool> _confirmStaffRequest() async {
    final String name = _fullNameController.text.trim();
    final String org = _organizationController.text.trim();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Submit $staffRoleSingular staff request?'),
          content: Text(
            'You are requesting $staffRoleWithOmag staff access as $name '
            'from $org.\n\n'
            'This is only for government extension staff. Farmers should not '
            'submit this request.\n\n'
            'Continue only if you are $staffRoleWithOmagLgu extension staff.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, submit request'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _showRequestSentDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Request sent'),
          content: const Text(
            'Your agriculturist access request was sent. Please wait for '
            'confirmation from an administrator.',
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
    if (!_staffConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Confirm that you are government staff before submitting.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (!_formIsComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fill in all required fields.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    if (!await _confirmStaffRequest()) return;
    if (!mounted) return;
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      await _service.submitRequest(
        fullName: _fullNameController.text,
        organization: _organizationController.text,
        companyLocation: _locationController.text,
        position: _positionController.text,
        note: _noteController.text,
      );
      if (!mounted) return;
      _fullNameController.clear();
      _organizationController.clear();
      _locationController.clear();
      _positionController.clear();
      _noteController.clear();
      setState(() {
        _formExpanded = false;
        _staffConfirmed = false;
      });
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

  Widget _farmerWarningBanner({required bool compact}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.warning_amber_rounded,
            color: cs.error,
            size: compact ? 18 : 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              compact
                  ? 'For $staffRoleWithOmagLgu staff only — not for regular farmers.'
                  : 'This request is for government extension staff only '
                      '(agriculturist, OMAG, LGU). Regular farmers already have full '
                      'farmer access and should not submit this.',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: compact ? 12 : 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 108,
            child: Text(
              label,
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

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  bool _shouldShowCard() {
    if (currentUserJwtStaff()) return false;
    if (_accountIntent == AccountIntent.farmer) return false;
    if (_accountIntent == AccountIntent.staff) return true;
    final DaAccessRequestStatus status =
        _latest?.status ?? DaAccessRequestStatus.none;
    return status != DaAccessRequestStatus.none;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_shouldShowCard()) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;

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
            'Your $staffRoleWithOmag staff access request was submitted. '
            'Sign out and sign in again after an admin approves it.',
          ),
          _detailRow('Full name', latest?.fullName),
          _detailRow('Organization', latest?.organization),
          _detailRow('Office location', latest?.companyLocation),
          _detailRow('Position', latest?.position),
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
            'Approved — sign out and sign in again to activate agriculturist access.',
            style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary),
          ),
        ],
      );
    } else {
      if (!_formExpanded) {
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
            _farmerWarningBanner(compact: false),
            const SizedBox(height: 12),
            Text(
              'Only tap below if you are an agriculturist, OMAG, or LGU '
              'extension officer who needs to review farmer reports.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting
                  ? null
                  : () => setState(() => _formExpanded = true),
              icon: const Icon(Icons.badge_outlined, size: 20),
              label: Text('I work for $staffRoleWithOmagLgu'),
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
            _farmerWarningBanner(compact: true),
            const SizedBox(height: 10),
            Text(
              'Tell the admin who you are and which organization you represent.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _fullNameController,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                label: 'Full name *',
                hint: 'Juan Dela Cruz',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _organizationController,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                label: 'Organization *',
                hint: 'DA Region XI, OMAG, LGU…',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                label: 'Office location *',
                hint: 'City, province, or office address',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _positionController,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: _fieldDecoration(
                label: 'Position in company *',
                hint: 'Agriculturist, extension officer…',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              enabled: !_submitting,
              maxLines: 2,
              decoration: _fieldDecoration(
                label: 'Optional note',
                hint: 'Employee ID or contact number',
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _staffConfirmed,
              onChanged: _submitting
                  ? null
                  : (bool? value) {
                      setState(() => _staffConfirmed = value ?? false);
                    },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'I confirm I am $staffRoleWithOmagLgu staff requesting expert access, '
                'not a regular farmer account.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: _submitting || !_staffConfirmed || !_formIsComplete()
                    ? null
                    : _submit,
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
                label: Text(_submitting ? 'Sending…' : 'Submit staff request'),
              ),
            ),
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                        _formExpanded = false;
                        _staffConfirmed = false;
                      }),
              child: const Text('Back — I am a farmer'),
            ),
          ],
        );
      }
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Padding(
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
                    child: Icon(Icons.badge_outlined, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Text(
                        staffAccessCardTitle,
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
