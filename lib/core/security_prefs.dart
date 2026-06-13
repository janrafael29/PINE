/// Persistent security-related preferences.
library;

import 'package:shared_preferences/shared_preferences.dart';

class SecurityPrefs {
  SecurityPrefs._();

  static const String kHasSuccessfulLogin = 'security_has_successful_login';
  static const String kRequireDeviceUnlock = 'security_require_device_unlock';
  static const String kDeviceUnlockPromptShown = 'security_device_unlock_prompt_shown';

  /// Marks that the user has successfully authenticated at least once.
  ///
  /// This does not enable device unlock by default; the user must opt in.
  static Future<void> markSuccessfulLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSuccessfulLogin, true);
  }

  static Future<bool> hasSuccessfulLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasSuccessfulLogin) ?? false;
  }

  static Future<bool> requireDeviceUnlock() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kRequireDeviceUnlock) ?? false;
  }

  static Future<void> setRequireDeviceUnlock(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kRequireDeviceUnlock, value);
  }

  static Future<bool> deviceUnlockPromptShown() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kDeviceUnlockPromptShown) ?? false;
  }

  static Future<void> setDeviceUnlockPromptShown(bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kDeviceUnlockPromptShown, value);
  }
}

