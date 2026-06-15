/// Demo / smoke-test role presets (no hardcoded credentials — saved on device).
library;

import 'package:flutter/foundation.dart';

class DemoAccountPreset {
  const DemoAccountPreset({
    required this.label,
    required this.roleKey,
  });

  final String label;
  /// `farmer` | `da` | `admin`
  final String roleKey;
}

const List<DemoAccountPreset> kDemoAccountPresets = <DemoAccountPreset>[
  DemoAccountPreset(label: 'Farmer', roleKey: 'farmer'),
  DemoAccountPreset(label: 'Agriculturist', roleKey: 'da'),
  DemoAccountPreset(label: 'Admin', roleKey: 'admin'),
];

/// Debug builds, or pass `--dart-define=ENABLE_DEMO_ACCOUNT_SWITCHER=true`.
bool demoAccountSwitcherEnabled() {
  if (kDebugMode) return true;
  return const bool.fromEnvironment(
    'ENABLE_DEMO_ACCOUNT_SWITCHER',
    defaultValue: false,
  );
}

String demoRoleLabelForCurrentUser({
  required bool isFullAdmin,
  required bool isDa,
}) {
  if (isFullAdmin) return 'Admin';
  if (isDa) return 'Agriculturist';
  return 'Farmer';
}

bool demoRoleChipSelected({
  required String roleKey,
  required bool isFullAdmin,
  required bool isDa,
}) {
  switch (roleKey) {
    case 'admin':
      return isFullAdmin;
    case 'da':
      return isDa && !isFullAdmin;
    case 'farmer':
      return !isFullAdmin && !isDa;
    default:
      return false;
  }
}

String demoEmailHint(String email) {
  final String trimmed = email.trim();
  if (trimmed.length <= 22) return trimmed;
  final int at = trimmed.indexOf('@');
  if (at <= 1) return '${trimmed.substring(0, 18)}…';
  return '${trimmed.substring(0, at.clamp(0, 12))}…${trimmed.substring(at)}';
}
