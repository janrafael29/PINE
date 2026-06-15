// Staff users submit verification details before entering the app.
library;

import 'package:flutter/material.dart';

import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../services/da_access_request_service.dart';
import '../core/staff_role_labels.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';

class StaffOnboardingScreen extends StatefulWidget {
  const StaffOnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<StaffOnboardingScreen> createState() => _StaffOnboardingScreenState();
}

class _StaffOnboardingScreenState extends State<StaffOnboardingScreen> {
  final DaAccessRequestService _service = DaAccessRequestService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _organizationController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  bool _submitting = false;
  bool _staffConfirmed = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _organizationController.dispose();
    _locationController.dispose();
    _positionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool _formIsComplete() {
    return _fullNameController.text.trim().isNotEmpty &&
        _organizationController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty &&
        _positionController.text.trim().isNotEmpty;
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

  Future<void> _submit() async {
    if (!_staffConfirmed || !_formIsComplete()) return;
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
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Request sent'),
            content: const Text(
              'Your staff access request was sent to an administrator. '
              'You can use PineSight as a farmer account while you wait. '
              'Sign out and sign in again after approval to unlock agriculturist tools.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Continue to app'),
              ),
            ],
          );
        },
      );
      if (!mounted) return;
      widget.onComplete();
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AppScaffold(
        title: 'Staff verification',
        leading: const SizedBox.shrink(),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Tell us about your government role',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.pineTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'An administrator will review this before granting '
                    'agriculturist access. You can still explore the app while waiting.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      label: 'Position *',
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
                      'I confirm I work as $staffRoleWithOmagLgu extension staff.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _submitting ||
                              !_staffConfirmed ||
                              !_formIsComplete()
                          ? null
                          : _submit,
                      child: _submitting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Text('Submit and continue'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              // ignore: discarded_futures
                              _signOutAndReturnToWelcome();
                            },
                      child: const Text('Sign out and return to welcome'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOutAndReturnToWelcome() async {
    await SupabaseClientProvider.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil<void>(
      context,
      '/',
      (Route<dynamic> route) => false,
    );
  }
}
