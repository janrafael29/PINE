/// Debug-only saved email/password per demo role (Farmer / DA / Admin).
///
/// Used only when [demoAccountSwitcherEnabled] is true. Not for production builds.
library;

import 'package:shared_preferences/shared_preferences.dart';

import 'demo_accounts.dart';

class DemoAccountCredentials {
  const DemoAccountCredentials({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class DemoAccountCredentialsStore {
  static String _prefKey(String roleKey, String field) =>
      'demo_cred_${roleKey}_$field';

  static Future<DemoAccountCredentials?> load(String roleKey) async {
    if (!demoAccountSwitcherEnabled()) return null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String email = (prefs.getString(_prefKey(roleKey, 'email')) ?? '')
        .trim()
        .toLowerCase();
    final String password =
        prefs.getString(_prefKey(roleKey, 'password')) ?? '';
    if (email.isEmpty || password.isEmpty) return null;
    return DemoAccountCredentials(email: email, password: password);
  }

  static Future<void> save({
    required String roleKey,
    required DemoAccountCredentials credentials,
  }) async {
    if (!demoAccountSwitcherEnabled()) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey(roleKey, 'email'),
      credentials.email.trim().toLowerCase(),
    );
    await prefs.setString(_prefKey(roleKey, 'password'), credentials.password);
  }

  static Future<void> clear(String roleKey) async {
    if (!demoAccountSwitcherEnabled()) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey(roleKey, 'email'));
    await prefs.remove(_prefKey(roleKey, 'password'));
  }

  static Future<Map<String, DemoAccountCredentials>> loadAll() async {
    final Map<String, DemoAccountCredentials> out =
        <String, DemoAccountCredentials>{};
    for (final DemoAccountPreset preset in kDemoAccountPresets) {
      final DemoAccountCredentials? creds = await load(preset.roleKey);
      if (creds != null) {
        out[preset.roleKey] = creds;
      }
    }
    return out;
  }
}
