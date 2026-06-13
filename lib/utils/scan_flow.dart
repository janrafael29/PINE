// Field-first scan entry: choose field, then camera/gallery.
library;

import 'package:flutter/material.dart';

import '../screens/assign_field_screen.dart';
import '../screens/permission_screens.dart';

/// Opens [AssignFieldScreen], then [PhotoSourcePicker] with the chosen field.
///
/// When [guestMode] is true, skips field pick (no account / no saved fields).
Future<void> startFieldFirstScan(
  BuildContext context, {
  bool guestMode = false,
}) async {
  if (guestMode) {
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const PhotoSourcePicker(
          fieldName: 'Guest scan',
          guestMode: true,
        ),
      ),
    );
    return;
  }

  final Map<String, String?>? pickedField =
      await Navigator.push<Map<String, String?>>(
    context,
    MaterialPageRoute<Map<String, String?>>(
      builder: (_) => const AssignFieldScreen(
        title: 'Choose a field',
        backToHomeOnCancel: true,
      ),
    ),
  );
  if (!context.mounted) return;
  if (pickedField == null) return;

  final String? fieldId = (pickedField['id']?.trim().isNotEmpty == true)
      ? pickedField['id']!.trim()
      : null;
  final String fieldName = (pickedField['name']?.trim().isNotEmpty == true)
      ? pickedField['name']!.trim()
      : 'Unassigned';

  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => PhotoSourcePicker(
        fieldName: fieldName,
        fieldId: fieldId,
      ),
    ),
  );
}
