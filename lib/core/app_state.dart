library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'service_locator.dart';
import '../services/inference_service.dart';

const String _kInferenceAccuracyMode = 'inference_accuracy_mode';
const String _kDarkMode = 'dark_mode_enabled';

/// Simple global app state for auth-related flags.
///
/// This is intentionally minimal and can be extended to cover more flows
/// (e.g., dashboard filters, lands selection) as the app grows.
class AppState extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _languageCode = 'en';
  int _capturedPhotosRevision = 0;
  int _fieldRecencyRevision = 0;
  bool _inferenceAccuracyMode = false;
  bool _darkMode = false;
  bool _dashboardHomeTabRequested = false;
  String? _pendingScanFieldId;
  String? _pendingScanFieldName;
  double? _pendingScanPinLat;
  double? _pendingScanPinLng;

  bool get isLoggedIn => _isLoggedIn;
  String get languageCode => _languageCode;
  bool get isFilipino => _languageCode == 'fil';
  int get capturedPhotosRevision => _capturedPhotosRevision;
  int get fieldRecencyRevision => _fieldRecencyRevision;
  bool get inferenceAccuracyMode => _inferenceAccuracyMode;
  bool get darkMode => _darkMode;
  bool get dashboardHomeTabRequested => _dashboardHomeTabRequested;

  bool get hasPendingScanFieldNavigation =>
      _pendingScanFieldId != null &&
      _pendingScanFieldId!.trim().isNotEmpty;

  ThemeMode get themeMode =>
      _darkMode ? ThemeMode.dark : ThemeMode.light;

  AppConfig get inferenceConfig {
    return _inferenceAccuracyMode ? AppConfig.accuracy() : AppConfig.balanced();
  }

  void _applyInferenceConfigToService() {
    if (!ServiceLocator.instance.isRegistered<InferenceService>()) return;
    ServiceLocator.instance
        .get<InferenceService>()
        .updateConfig(inferenceConfig);
  }

  void bumpCapturedPhotos() {
    _capturedPhotosRevision++;
    notifyListeners();
  }

  void bumpFieldRecency() {
    _fieldRecencyRevision++;
    notifyListeners();
  }

  void requestDashboardHomeTab() {
    _dashboardHomeTabRequested = true;
    notifyListeners();
  }

  void clearDashboardHomeTabRequest() {
    if (!_dashboardHomeTabRequested) return;
    _dashboardHomeTabRequested = false;
  }

  /// After a field-first scan save, open that field's map with the new pin.
  void requestNavigateToFieldAfterScan({
    required String fieldId,
    required String fieldName,
    double? pinLat,
    double? pinLng,
  }) {
    _pendingScanFieldId = fieldId.trim();
    _pendingScanFieldName = fieldName.trim();
    _pendingScanPinLat = pinLat;
    _pendingScanPinLng = pinLng;
    notifyListeners();
  }

  /// Consumes [requestNavigateToFieldAfterScan] payload (one-shot).
  ({String fieldId, String fieldName, double? pinLat, double? pinLng})?
      takePendingScanFieldNavigation() {
    final String? id = _pendingScanFieldId?.trim();
    if (id == null || id.isEmpty) return null;
    final String name = _pendingScanFieldName?.trim() ?? 'Field';
    final ({String fieldId, String fieldName, double? pinLat, double? pinLng})
        payload = (
      fieldId: id,
      fieldName: name,
      pinLat: _pendingScanPinLat,
      pinLng: _pendingScanPinLng,
    );
    _pendingScanFieldId = null;
    _pendingScanFieldName = null;
    _pendingScanPinLat = null;
    _pendingScanPinLng = null;
    return payload;
  }

  void setLoggedIn(bool value) {
    if (_isLoggedIn == value) return;
    _isLoggedIn = value;
    notifyListeners();
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('language_code') ?? 'en';
    final bool acc = prefs.getBool(_kInferenceAccuracyMode) ?? false;
    // Always launch in light mode (do not follow system theme or a prior session).
    const bool dark = false;
    if (prefs.getBool(_kDarkMode) != false) {
      await prefs.setBool(_kDarkMode, false);
    }
    var changed = false;
    if (_languageCode != code) {
      _languageCode = code;
      changed = true;
    }
    if (_inferenceAccuracyMode != acc) {
      _inferenceAccuracyMode = acc;
      changed = true;
    }
    if (_darkMode != dark) {
      _darkMode = dark;
      changed = true;
    }
    _applyInferenceConfigToService();
    if (changed) notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
  }

  Future<void> setDarkMode(bool enabled) async {
    if (_darkMode == enabled) return;
    _darkMode = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, enabled);
  }

  Future<void> setInferenceAccuracyMode(bool enabled) async {
    if (_inferenceAccuracyMode == enabled) return;
    _inferenceAccuracyMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInferenceAccuracyMode, enabled);
    _applyInferenceConfigToService();
    notifyListeners();
  }
}

