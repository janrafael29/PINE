/// Persistence for the post-login app navigation tour and repeat preference.
library;

import 'package:shared_preferences/shared_preferences.dart';

const String _kNavGuideFinishedChoice = 'nav_guide_finished_user_choice';
const String _kNavGuideShowEachSession = 'nav_guide_show_each_session';

/// Whether to present the navigation guide (first time, or every session if chosen).
Future<bool> shouldShowNavigationGuide() async {
  final SharedPreferences p = await SharedPreferences.getInstance();
  final bool showEach = p.getBool(_kNavGuideShowEachSession) ?? false;
  if (showEach) return true;
  final bool finished = p.getBool(_kNavGuideFinishedChoice) ?? false;
  return !finished;
}

/// Call when the user finishes the last step of the guide.
Future<void> setNavigationGuidePreference({required bool showEachSession}) async {
  final SharedPreferences p = await SharedPreferences.getInstance();
  await p.setBool(_kNavGuideFinishedChoice, true);
  await p.setBool(_kNavGuideShowEachSession, showEachSession);
}

/// Current preference: show the guide on every app entry (after sign-in/unlock).
Future<bool> getNavigationGuideShowEachSession() async {
  final SharedPreferences p = await SharedPreferences.getInstance();
  return p.getBool(_kNavGuideShowEachSession) ?? false;
}

/// Updates repeat-on-open without running the tour (e.g. Settings switch).
Future<void> setNavigationGuideShowEachSession(bool showEachSession) async {
  final SharedPreferences p = await SharedPreferences.getInstance();
  await p.setBool(_kNavGuideFinishedChoice, true);
  await p.setBool(_kNavGuideShowEachSession, showEachSession);
}
