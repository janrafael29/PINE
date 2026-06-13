/// Demo / smoke-test account presets (emails only — no passwords in repo).
library;

import 'package:flutter/foundation.dart';

class DemoAccountPreset {
  const DemoAccountPreset({
    required this.label,
    required this.email,
    required this.roleKey,
  });

  final String label;
  final String email;
  /// `farmer` | `da` | `admin`
  final String roleKey;
}

const List<DemoAccountPreset> kDemoAccountPresets = <DemoAccountPreset>[
  DemoAccountPreset(
    label: 'Farmer',
    email: 'morillo3580225@gmail.com',
    roleKey: 'farmer',
  ),
  DemoAccountPreset(
    label: 'DA',
    email: 'rgist45@gmail.com',
    roleKey: 'da',
  ),
  DemoAccountPreset(
    label: 'Admin',
    email: 'morgajanrafael1793@gmail.com',
    roleKey: 'admin',
  ),
];

/// Debug builds, or pass `--dart-define=ENABLE_DEMO_ACCOUNT_SWITCHER=true`.
bool demoAccountSwitcherEnabled() {
  if (kDebugMode) return true;
  return const bool.fromEnvironment(
    'ENABLE_DEMO_ACCOUNT_SWITCHER',
    defaultValue: false,
  );
}

/// Optional shared password for all demo accounts:
/// `--dart-define=DEMO_SWITCH_PASSWORD=your_password`
String demoSwitchPasswordFromEnv() {
  return const String.fromEnvironment('DEMO_SWITCH_PASSWORD', defaultValue: '');
}

DemoAccountPreset? demoPresetForEmail(String? email) {
  final String normalized = (email ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return null;
  for (final DemoAccountPreset p in kDemoAccountPresets) {
    if (p.email.toLowerCase() == normalized) return p;
  }
  return null;
}

String demoRoleLabelForCurrentUser({
  required String? email,
  required bool isFullAdmin,
  required bool isDa,
}) {
  final DemoAccountPreset? preset = demoPresetForEmail(email);
  if (preset != null) return preset.label;
  if (isFullAdmin) return 'Admin';
  if (isDa) return 'DA';
  return 'Farmer';
}
