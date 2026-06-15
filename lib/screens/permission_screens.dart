// Camera, GPS, Gallery permission UIs; photo source picker; result; camera modes; albums.
library;

import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/supabase_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../core/app_state.dart';
import '../core/dashboard_guide_keys.dart';
import '../core/service_locator.dart';
import '../core/app_logger.dart';
import '../core/network_reachability.dart';
import '../core/theme.dart';
import '../widgets/app_scaffold.dart';
import '../models/detection_result.dart';
import '../services/cloud_sync_service.dart';
import '../services/image_storage_service.dart';
import '../services/database_service.dart';
import '../services/inference_service.dart';
import '../services/geo_service.dart';
import '../services/geo_fence_service.dart';
import '../data/detection_advisory_messages.dart';
import '../data/insight_catalog.dart';
import '../utils/severity_score.dart';
import '../utils/field_boundary_check.dart';
import '../models/land.dart';
import 'captured_photos_screen.dart';
import 'location_picker_screen.dart';
import '../widgets/online_required_dialog.dart';
import '../widgets/action_popup.dart';
import '../widgets/inference_progress_dialog.dart';
import '../widgets/detection_showcase_dialog.dart';
import '../widgets/detection_markers_painter.dart';
import '../widgets/scan_flow_step_indicator.dart';
import '../utils/oriented_image.dart';
import '../utils/detection_tiers.dart';
import '../utils/exif_gps_reader.dart';
import '../utils/upload_name_hint.dart';
import '../utils/welcome_navigation.dart';
import 'assign_field_screen.dart';
import 'bulk_gallery_pin_screen.dart';
import 'register_screen.dart';

/// Shown after picking from gallery: optional map pin for where the photo was taken.
enum _WherePhotoTakenChoice { chooseOnMap, continueWithout }

int _meanConfidencePct(List<Detection> detections) {
  if (detections.isEmpty) return 0;
  final List<Detection> confirmed = confirmedDetections(detections);
  final Iterable<Detection> basis = confirmed.isNotEmpty ? confirmed : detections;
  final double mean = basis.map((d) => d.confidence).reduce((a, b) => a + b) /
      basis.length;
  return (mean * 100).round().clamp(0, 100);
}

/// Best-effort device GPS at the moment a gallery photo was chosen (fallback vs EXIF).
Future<({double? lat, double? lng})> _deviceGpsWhenGalleryPhotoChosen() async {
  try {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return (lat: null, lng: null);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (lat: null, lng: null);
    }
    final GeoLocationResult r = await GeoService().getCurrentPosition();
    if (r.isSuccess) {
      return (lat: r.latitude, lng: r.longitude);
    }
    return (lat: null, lng: null);
  } catch (_) {
    return (lat: null, lng: null);
  }
}

/// Guest gallery flow: map pin and full features need an account.
///
/// Returns `true` when the user chooses **Not now** (caller should treat as Skip).
Future<bool> _showGuestAuthRequiredDialog(BuildContext context) async {
  final bool fil = context.read<AppState>().isFilipino;
  final bool? skip = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(fil ? 'Kailangan ng account' : 'Account required'),
        content: Text(
          fil
              ? 'Mag-sign up o mag-log in muna para magamit ang mapa at lahat ng feature ng app.'
              : 'Sign up or log in first to use the map and access all features.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(fil ? 'Bumalik' : 'Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pushNamed('/login');
            },
            child: Text(fil ? 'Mag-log in' : 'Log in'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const RegisterScreen(),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(fil ? 'Mag-sign up' : 'Sign up'),
          ),
        ],
      );
    },
  );
  return skip == true;
}

Future<latlong2.LatLng?> _promptOptionalWherePhotoTaken(
  BuildContext context, {
  Land? fieldBoundaryLand,
  bool guestMode = false,
}) async {
  final bool fil = context.read<AppState>().isFilipino;
  final _WherePhotoTakenChoice? choice =
      await showModalBottomSheet<_WherePhotoTakenChoice>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                fil ? 'Saan kinunan ang larawan?' : 'Where was this photo taken?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.pineTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fil
                    ? 'Opsyonal. Kung laktawan, gagamitin ang iyong lokasyon ngayon (o GPS sa larawan kung mayroon).'
                    : 'Optional. If you skip, we use your current location now (or GPS from the file if present).',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  if (guestMode) {
                    final bool skipNow =
                        await _showGuestAuthRequiredDialog(sheetContext);
                    if (skipNow && sheetContext.mounted) {
                      Navigator.pop(
                        sheetContext,
                        _WherePhotoTakenChoice.continueWithout,
                      );
                    }
                    return;
                  }
                  Navigator.pop(
                    sheetContext,
                    _WherePhotoTakenChoice.chooseOnMap,
                  );
                },
                icon: const Icon(Icons.map),
                label: Text(fil ? 'Pumili sa mapa' : 'Choose on map'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(sheetContext, _WherePhotoTakenChoice.continueWithout),
                child: Text(fil ? 'Laktawan' : 'Skip'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted) return null;
  if (choice != _WherePhotoTakenChoice.chooseOnMap) return null;
  if (!await ensureOnline(context)) return null;
  if (!context.mounted) return null;
  final Object? r = await Navigator.push<Object?>(
    context,
    MaterialPageRoute<Object?>(
      builder: (_) => LocationPickerScreen(
        fieldBoundaryLand: fieldBoundaryLand,
      ),
    ),
  );
  if (r is latlong2.LatLng) return r;
  return null;
}

String _noDetectionsDetailMessage(BuildContext context) {
  final bool fil = context.read<AppState>().isFilipino;
  return fil
      ? DetectionAdvisoryMessages.noDetectionPopupDetailFil
      : DetectionAdvisoryMessages.noDetectionPopupDetailEn;
}

String detectionNextStepsText({required bool fil, required bool hasHits}) {
  return hasHits
      ? DetectionAdvisoryMessages.possibleDetectionNextSteps(fil: fil)
      : DetectionAdvisoryMessages.noDetectionNextSteps(fil: fil);
}

// --- Camera Permission ---
class CameraPermissionScreen extends StatelessWidget {
  const CameraPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Permission',
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.camera_alt,
                  size: 80,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  'Pine-Sight would like to access your Camera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.pineTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only when using the app',
                  style: TextStyle(fontSize: 14, color: context.pineTextSecondary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Allow', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Deny',
                    style: TextStyle(fontSize: 16, color: context.pineTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- GPS Permission ---
class GpsPermissionScreen extends StatelessWidget {
  const GpsPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Permission',
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.location_on,
                  size: 80,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  'Allow Pine-Sight to access this device\'s location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.pineTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only when using the app',
                  style: TextStyle(fontSize: 14, color: context.pineTextSecondary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Allow', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Deny',
                    style: TextStyle(fontSize: 16, color: context.pineTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Gallery Permission ---
class GalleryPermissionScreen extends StatelessWidget {
  const GalleryPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Permission',
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.photo_library,
                  size: 80,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 24),
                Text(
                  'Pine-Sight would like to access your Gallery',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.pineTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Only when using the app',
                  style: TextStyle(fontSize: 14, color: context.pineTextSecondary),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Allow', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Deny',
                    style: TextStyle(fontSize: 16, color: context.pineTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row of work during bulk gallery upload (inference done; GPS resolved later).
class _BulkPendingSave {
  _BulkPendingSave({
    required this.bytes,
    required this.originalPath,
    required this.result,
    this.exifLat,
    this.exifLng,
  });

  final Uint8List bytes;
  final String originalPath;
  final DetectionResult result;
  final double? exifLat;
  final double? exifLng;
}

// --- Photo Source Picker (Camera / Gallery) ---
class PhotoSourcePicker extends StatefulWidget {
  const PhotoSourcePicker({
    super.key,
    this.fieldName = 'Field',
    this.fieldId,
    this.guestMode = false,
  });

  final String fieldName;

  /// When set, Save uses these for Supabase sync (required for "Please select a field" when missing).
  final String? fieldId;

  /// Try-without-account: no save, no cloud sync.
  final bool guestMode;

  @override
  State<PhotoSourcePicker> createState() => _PhotoSourcePickerState();
}

class _PhotoSourcePickerState extends State<PhotoSourcePicker> {
  final ImagePicker _picker = ImagePicker();
  InferenceService get _inferenceService =>
      ServiceLocator.instance.get<InferenceService>();
  bool _busy = false;
  bool _gpsPromptShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _promptForGpsIfNeeded();
    });
  }

  Future<void> _promptForGpsIfNeeded() async {
    if (!mounted || _gpsPromptShown) return;
    _gpsPromptShown = true;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final LocationPermission permission = await Geolocator.checkPermission();
    final bool needsPrompt = !serviceEnabled ||
        permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
    if (!needsPrompt || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          title: const Text('Turn on GPS for better accuracy'),
          content: const Text(
            'For best tagging accuracy, please enable GPS/location before taking or selecting a photo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () async {
                if (!serviceEnabled) {
                  await Geolocator.openLocationSettings();
                } else {
                  await Geolocator.requestPermission();
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Enable GPS'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFromGalleryAndDetect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final String path = picked.path;
      Land? boundaryLand;
      try {
        final DatabaseService db = DatabaseService();
        await db.initialize();
        boundaryLand = await db.findLandByFieldName(widget.fieldName);
      } catch (_) {}
      if (!mounted) return;
      final latlong2.LatLng? mapPick = await _promptOptionalWherePhotoTaken(
        context,
        fieldBoundaryLand: boundaryLand,
        guestMode: widget.guestMode,
      );
      if (!mounted) return;
      final ({double? lat, double? lng}) pickGps =
          await _deviceGpsWhenGalleryPhotoChosen();
      final double? chosenTakeLat = mapPick?.latitude;
      final double? chosenTakeLng = mapPick?.longitude;
      final double? pickMomentLat = pickGps.lat;
      final double? pickMomentLng = pickGps.lng;

      int confidence = 0;
      int count = 0;
      List<Detection> detections = const <Detection>[];
      int? originalImageWidth;
      int? originalImageHeight;
      Uint8List? imageBytes;
      try {
        imageBytes = Uint8List.fromList(await picked.readAsBytes());
        if (!mounted) return;
        final bool fil = context.read<AppState>().isFilipino;
        final DetectionResult result = await runInferenceWithProgressUi(
          context: context,
          inferenceService: _inferenceService,
          imageBytes: imageBytes,
          filipino: fil,
          detectionThresholdOverride: null,
        );
        if (!mounted) return;
        detections = result.detections;
        count = confirmedCount(detections);
        originalImageWidth = result.originalWidth;
        originalImageHeight = result.originalHeight;
        confidence = _meanConfidencePct(detections);
        if (visibleCount(detections) == 0 && mounted) {
          await ActionPopup.showInfo(
            context,
            title: context.read<AppState>().isFilipino
                ? DetectionAdvisoryMessages.noDetectionPopupTitleFil
                : DetectionAdvisoryMessages.noDetectionPopupTitleEn,
            message: _noDetectionsDetailMessage(context),
          );
        }
      } catch (e) {
        AppLogger.error('Inference ERROR (gallery direct)', e);
        if (mounted) {
          await ActionPopup.showError(
            context,
            message: 'Detection failed: $e',
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoResultScreen(
            fieldName: widget.fieldName,
            imagePath: path,
            imageBytes: imageBytes,
            confidence: confidence,
            count: count,
            detections: detections,
            originalImageWidth: originalImageWidth,
            originalImageHeight: originalImageHeight,
            fieldId: widget.fieldId,
            guestMode: widget.guestMode,
            takeLocationChosenLat: chosenTakeLat,
            takeLocationChosenLng: chosenTakeLng,
            pickMomentLat: pickMomentLat,
            pickMomentLng: pickMomentLng,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureFromCameraAndDetect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
      );
      if (photo == null || !mounted) return;
      final String path = photo.path;

      final GeoLocationResult captureGps = await GeoService().getCurrentPosition();

      int confidence = 0;
      int count = 0;
      List<Detection> detections = const <Detection>[];
      int? originalImageWidth;
      int? originalImageHeight;
      Uint8List? imageBytes;

      try {
        final File file = File(path);
        final List<int> bytes = await file.readAsBytes();
        if (!mounted) return;
        imageBytes = Uint8List.fromList(bytes);
        final bool fil = context.read<AppState>().isFilipino;
        final DetectionResult result = await runInferenceWithProgressUi(
          context: context,
          inferenceService: _inferenceService,
          imageBytes: imageBytes,
          filipino: fil,
          detectionThresholdOverride: null,
        );
        if (!mounted) return;
        detections = result.detections;
        count = confirmedCount(detections);
        originalImageWidth = result.originalWidth;
        originalImageHeight = result.originalHeight;
        confidence = _meanConfidencePct(detections);
        if (visibleCount(detections) == 0 && mounted) {
          await ActionPopup.showInfo(
            context,
            title: context.read<AppState>().isFilipino
                ? DetectionAdvisoryMessages.noDetectionPopupTitleFil
                : DetectionAdvisoryMessages.noDetectionPopupTitleEn,
            message: _noDetectionsDetailMessage(context),
          );
        }
      } catch (e) {
        AppLogger.error('Inference ERROR (camera direct)', e);
        if (mounted) {
          await ActionPopup.showError(
            context,
            message: 'Detection failed: $e',
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoResultScreen(
            fieldName: widget.fieldName,
            imagePath: path,
            imageBytes: imageBytes,
            confidence: confidence,
            count: count,
            detections: detections,
            originalImageWidth: originalImageWidth,
            originalImageHeight: originalImageHeight,
            fieldId: widget.fieldId,
            guestMode: widget.guestMode,
            pickMomentLat:
                captureGps.isSuccess ? captureGps.latitude : null,
            pickMomentLng:
                captureGps.isSuccess ? captureGps.longitude : null,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manualSyncPressed() async {
    if (_busy) return;
    final bool fil = context.read<AppState>().isFilipino;
    setState(() => _busy = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return _AddPhotoManualSyncDialog(filipino: fil);
        },
      );
      if (!mounted) return;
      context.read<AppState>().bumpCapturedPhotos();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkPickFromGalleryDetectAndSave() async {
    if (_busy || widget.guestMode) return;
    setState(() => _busy = true);
    final ActionPopupController progress = ActionPopupController();
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (picked.isEmpty || !mounted) return;

      final bool fil = context.read<AppState>().isFilipino;
      final Map<String, String?>? pickedField =
          await Navigator.push<Map<String, String?>>(
        context,
        MaterialPageRoute<Map<String, String?>>(
          builder: (_) => AssignFieldScreen(
            initialFieldId: widget.fieldId,
            title: fil ? 'Pumili ng field' : 'Choose a field',
          ),
        ),
      );
      if (!mounted) return;
      final String? fieldId = (pickedField?['id']?.trim().isNotEmpty == true)
          ? pickedField!['id']!.trim()
          : null;
      final String fieldName = (pickedField?['name']?.trim().isNotEmpty == true)
          ? pickedField!['name']!.trim()
          : (fil ? 'Walang field' : 'Unassigned');

      progress.showBlockingProgress(
        context,
        message: fil ? 'Sinusuri ang mga larawan…' : 'Scanning photos…',
      );

      final DatabaseService db = DatabaseService();
      await db.initialize();
      final String userId =
          SupabaseClientProvider.instance.client.auth.currentUser?.id ?? '';
      final GeoFenceService fence = GeoFenceService();
      Land? selectedFieldLand;
      if (fieldId != null && fieldId.trim().isNotEmpty) {
        selectedFieldLand = await db.findLandByFieldName(fieldName);
      }

      final bool online = await NetworkReachability.isOnline();
      final List<_BulkPendingSave> work = <_BulkPendingSave>[];
      int fail = 0;

      for (int i = 0; i < picked.length; i++) {
        final XFile xf = picked[i];
        try {
          final File f = File(xf.path);
          if (!await f.exists()) {
            fail++;
            continue;
          }
          final Uint8List bytes = Uint8List.fromList(await f.readAsBytes());
          final ({double lat, double lng})? exif = await readGpsFromImage(
            bytes: bytes,
            path: xf.path,
          );
          final DetectionResult result =
              await _inferenceService.runInference(bytes);
          work.add(
            _BulkPendingSave(
              bytes: bytes,
              originalPath: xf.path,
              result: result,
              exifLat: exif?.lat,
              exifLng: exif?.lng,
            ),
          );
        } catch (_) {
          fail++;
        }
      }

      if (!mounted) return;

      List<latlong2.LatLng>? manualPins;
      final int needPin = work
          .where(
            (_BulkPendingSave s) => s.exifLat == null || s.exifLng == null,
          )
          .length;

      if (needPin > 0 &&
          selectedFieldLand != null &&
          online &&
          selectedFieldLand.polygonCoordinates.length >= 3) {
        progress.close();
        if (!mounted) return;
        manualPins = await Navigator.push<List<latlong2.LatLng>>(
          context,
          MaterialPageRoute<List<latlong2.LatLng>>(
            builder: (_) => BulkGalleryPinScreen(
              land: selectedFieldLand!,
              count: needPin,
              fieldName: fieldName,
              filipino: fil,
              fence: fence,
            ),
          ),
        );
        if (!mounted) return;
        if (manualPins == null || manualPins.length != needPin) {
          await ActionPopup.showInfo(
            context,
            title: fil ? 'Kinansela' : 'Cancelled',
            message: fil ? 'Walang na-save.' : 'Nothing was saved.',
          );
          return;
        }
        progress.showBlockingProgress(
          context,
          message: fil ? 'Sine-save…' : 'Saving…',
        );
      }

      if (!mounted) return;

      int ok = 0;
      int pinCursor = 0;

      for (final _BulkPendingSave item in work) {
        try {
          double? lat = item.exifLat;
          double? lng = item.exifLng;
          if (lat == null || lng == null) {
            if (manualPins != null && pinCursor < manualPins.length) {
              lat = manualPins[pinCursor].latitude;
              lng = manualPins[pinCursor].longitude;
              pinCursor++;
            }
          }
          if (lat == null || lng == null) {
            final ({double? lat, double? lng}) dev =
                await _deviceGpsWhenGalleryPhotoChosen();
            lat = dev.lat;
            lng = dev.lng;
          }

          final DetectionResult result = item.result;
          final int count = confirmedCount(result.detections);
          final int confidence = _meanConfidencePct(result.detections);

          final String localPath =
              await ImageStorageService().saveDetectionImage(item.bytes);

          await db.insertCapturedPhoto(
            localImagePath: localPath,
            fieldName: fieldName,
            fieldId: fieldId,
            confidence: confidence,
            count: count,
            detectionsJson: jsonEncode(
              result.detections
                  .map((d) => <String, dynamic>{
                        'left': d.left,
                        'top': d.top,
                        'width': d.width,
                        'height': d.height,
                        'confidence': d.confidence,
                        'classIndex': d.classIndex,
                        'label': d.label,
                      })
                  .toList(),
            ),
            userId: userId.isEmpty ? null : userId,
            latitude: lat,
            longitude: lng,
          );
          await db.enqueueUpload(
            localImagePath: localPath,
            confidence: confidence,
            count: count,
            fieldId: fieldId,
            latitude: lat,
            longitude: lng,
            nameHint: buildUploadNameHint(
              fieldLabel: fieldName,
              originalFilePath: item.originalPath,
            ),
          );
          ok++;
        } catch (_) {
          fail++;
        }
      }

      if (!mounted) return;
      context.read<AppState>().bumpCapturedPhotos();

      if (userId.isNotEmpty && await NetworkReachability.isOnline()) {
        await CloudSyncService(databaseService: db).syncPending(limit: 10);
      } else if (userId.isNotEmpty) {
        CloudSyncService(databaseService: db).syncInBackground();
      }

      progress.close();
      if (!mounted) return;
      await ActionPopup.showSuccess(
        context,
        title: fil ? 'Saved' : 'Saved',
        message: fil
            ? 'Na-process: $ok\nFailed: $fail'
            : 'Processed: $ok\nFailed: $fail',
      );
    } finally {
      progress.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String fieldLabel = widget.fieldName.trim().isEmpty
        ? (fil ? 'Walang field' : 'No field')
        : widget.fieldName.trim();

    return AppScaffold(
      title: widget.guestMode
          ? (fil ? 'Guest scan' : 'Guest scan')
          : (fil ? 'Kumuha ng larawan' : 'Add Photo'),
      leading: widget.guestMode ? welcomeBackButton(context) : null,
      usePatternBackground: false,
      actions: <Widget>[
        if (!widget.guestMode)
          IconButton(
            tooltip: fil ? 'Mga nai-save na larawan' : 'Captured pictures',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CapturedPhotosScreen(),
                ),
              );
            },
          ),
      ],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ScanFlowStepIndicator(
                currentStep: 2,
                filipino: fil,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScanContextBanner(
                filipino: fil,
                guestMode: widget.guestMode,
                fieldLabel: fieldLabel,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      fil
                          ? 'Paano mo gustong kunin ang larawan?'
                          : 'How do you want to capture?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.pineTextPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fil
                          ? 'Pumili ng camera o gallery. Susuriin ng AI ang mealybug pagkatapos.'
                          : 'Use camera or gallery. AI scans for mealybugs after you pick.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _CaptureChoiceCard(
                            icon: Icons.camera_alt_rounded,
                            title: fil ? 'Camera' : 'Camera',
                            subtitle: fil
                                ? 'Kumuha ng bagong litrato'
                                : 'Take a new photo',
                            onTap: _busy ? null : _captureFromCameraAndDetect,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CaptureChoiceCard(
                            icon: Icons.photo_library_rounded,
                            title: fil ? 'Gallery' : 'Gallery',
                            subtitle: widget.guestMode
                                ? (fil
                                    ? 'Pumili ng isang larawan'
                                    : 'Pick one photo')
                                : (fil
                                    ? 'Isa o maraming larawan'
                                    : 'One or many photos'),
                            onTap: _busy
                                ? null
                                : () {
                                    if (widget.guestMode) {
                                      _pickFromGalleryAndDetect();
                                    } else {
                                      _showGalleryOptions(context, fil);
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (_busy) ...<Widget>[
                      const SizedBox(height: 20),
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                    if (!widget.guestMode) ...<Widget>[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        key: DashboardGuideKeyHolder.addPhotoSyncKey,
                        onPressed: _busy ? null : _manualSyncPressed,
                        icon: const Icon(Icons.cloud_sync_outlined),
                        label: Text(
                          fil
                              ? 'I-sync sa cloud'
                              : 'Sync to cloud',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGalleryOptions(BuildContext context, bool fil) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(fil ? 'Isang larawan' : 'Single photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickFromGalleryAndDetect();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.collections_outlined),
                  title: Text(fil ? 'Maraming larawan' : 'Bulk upload'),
                  subtitle: Text(
                    fil
                        ? 'I-scan lahat, tapos i-pin ang walang GPS sa mapa'
                        : 'Scan all, then pin no-GPS shots on the map',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _bulkPickFromGalleryDetectAndSave();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Field / guest context under the step indicator.
class _ScanContextBanner extends StatelessWidget {
  const _ScanContextBanner({
    required this.filipino,
    required this.guestMode,
    required this.fieldLabel,
  });

  final bool filipino;
  final bool guestMode;
  final String fieldLabel;

  @override
  Widget build(BuildContext context) {
    if (guestMode) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.person_outline,
              color: AppTheme.primaryGreen.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                filipino
                    ? 'Guest scan — hindi nase-save'
                    : 'Guest scan — not saved',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.pineTextPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.agriculture,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  filipino ? 'Napiling field' : 'Selected field',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fieldLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.pineTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureChoiceCard extends StatelessWidget {
  const _CaptureChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppTheme.primaryGreen),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.pineTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSyncEta(Duration? d, {required bool filipino}) {
  if (d == null) {
    return filipino ? 'Tinatantya…' : 'Estimating…';
  }
  if (d.inSeconds <= 5) {
    return filipino ? 'Halos tapos na' : 'Almost done';
  }
  final int m = d.inMinutes;
  final int s = d.inSeconds % 60;
  if (m >= 1) {
    return filipino
        ? 'Mga ~$m min $s seg natitira'
        : '~$m min $s sec remaining';
  }
  return filipino ? 'Mga ~$s seg natitira' : '~$s sec remaining';
}

String _formatSyncElapsed(Duration d) {
  final int m = d.inMinutes;
  final int s = d.inSeconds % 60;
  if (m > 0) {
    return '${m}m ${s}s';
  }
  return '${s}s';
}

/// Manual upload progress while syncing the offline queue from Add Photo.
class _AddPhotoManualSyncDialog extends StatefulWidget {
  const _AddPhotoManualSyncDialog({required this.filipino});

  final bool filipino;

  @override
  State<_AddPhotoManualSyncDialog> createState() =>
      _AddPhotoManualSyncDialogState();
}

class _AddPhotoManualSyncDialogState extends State<_AddPhotoManualSyncDialog> {
  ManualSyncProgress? _progress;
  ManualSyncSummary? _summary;
  Object? _error;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _run();
  }

  Future<void> _run() async {
    try {
      final ManualSyncSummary summary =
          await CloudSyncService().syncAllPendingWithProgress(
        onProgress: (ManualSyncProgress p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool fil = widget.filipino;
    final ManualSyncProgress? p = _progress;
    final ManualSyncSummary? s = _summary;
    final Object? err = _error;

    final bool done = s != null || err != null;
    final double? barValue = p == null || p.totalInitial <= 0
        ? null
        : p.progress01.clamp(0.0, 1.0);

    String subtitle = '';
    if (err != null) {
      subtitle = '$err';
    } else if (s != null) {
      if (s.wasSkipped) {
        subtitle = s.message ?? (fil ? 'Hindi na-sync.' : 'Sync skipped.');
      } else if (s.remainingPending == 0 && s.syncedCount == 0) {
        subtitle = s.message ?? (fil ? 'Walang naka-queue.' : 'Nothing to sync.');
      } else if (s.remainingPending == 0) {
        subtitle = fil
            ? 'Tapos na — ${s.syncedCount} na-sync (mga field at/o larawan).'
            : 'Done — synced ${s.syncedCount} item(s) (fields and/or photos).';
      } else {
        subtitle = fil
            ? 'Na-sync: ${s.syncedCount}. Natitirang upload sa queue: ${s.remainingPending}.'
            : 'Synced: ${s.syncedCount}. Still pending in queue: ${s.remainingPending}.';
        if (s.message != null) {
          subtitle = '$subtitle\n${s.message}';
        }
      }
    } else if (p != null && p.totalInitial > 0) {
      subtitle = fil
          ? '${p.uploadedSoFar} / ${p.totalInitial} (mga field + detection) • ${_formatSyncElapsed(p.elapsed)}\n${_formatSyncEta(p.estimatedRemaining, filipino: fil)}'
          : '${p.uploadedSoFar} / ${p.totalInitial} (fields + detections) • ${_formatSyncElapsed(p.elapsed)}\n${_formatSyncEta(p.estimatedRemaining, filipino: fil)}';
    } else {
      subtitle = fil ? 'Sinusuri…' : 'Checking…';
    }

    return PopScope(
      canPop: done,
      child: AlertDialog(
        title: Text(fil ? 'Nagse-sync sa cloud' : 'Syncing to cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done ? 1.0 : barValue,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          if (done)
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(fil ? 'OK' : 'OK'),
            ),
        ],
      ),
    );
  }
}

// --- Photo Result (after detection) ---
class PhotoResultScreen extends StatefulWidget {
  const PhotoResultScreen({
    super.key,
    required this.fieldName,
    this.imagePath,
    this.imageBytes,
    this.confidence = 70,
    this.count = 100,
    this.detections = const <Detection>[],
    this.originalImageWidth,
    this.originalImageHeight,
    this.fieldId,
    this.guestMode = false,
    this.takeLocationChosenLat,
    this.takeLocationChosenLng,
    this.pickMomentLat,
    this.pickMomentLng,
  });

  final String fieldName;

  /// Optional path to the image file. When set, Save will upload via Supabase.
  final String? imagePath;
  final Uint8List? imageBytes;
  final int confidence;
  final int count;
  final List<Detection> detections;
  final int? originalImageWidth;
  final int? originalImageHeight;

  /// When set, Save uses these for Supabase (`detections` + local queue).
  final String? fieldId;

  /// Guest try-scan: no local DB insert or cloud upload.
  final bool guestMode;

  /// User-picked “where taken” from map after gallery pick (highest priority).
  final double? takeLocationChosenLat;
  final double? takeLocationChosenLng;

  /// Device GPS captured when the gallery photo was chosen (after optional sheet).
  final double? pickMomentLat;
  final double? pickMomentLng;

  @override
  State<PhotoResultScreen> createState() => _PhotoResultScreenState();
}

class _PhotoResultScreenState extends State<PhotoResultScreen>
    with SingleTickerProviderStateMixin {
  double? _taggedLat;
  double? _taggedLng;
  GeoFenceResult? _fence;
  FieldBoundarySaveGate? _selectedFieldBoundaryGate;
  bool _saving = false;
  bool _gettingGps = false;
  bool _showAllDetections = false;
  List<Detection> _liveDetections = const <Detection>[];
  int _liveCount = 0;
  int _liveConfidencePct = 0;
  /// Pre-sorted in [initState] so [build] does not sort on every frame.
  late List<Detection> _sortedDetectionsUi;
  late int _overallPctUi;
  late int _topPctUi;
  late final AnimationController _pulse;
  late final GeoFenceService _geoFence;
  late final DatabaseService _db;
  bool _showcaseShown = false;

  @override
  void initState() {
    super.initState();
    _geoFence = GeoFenceService();
    _db = DatabaseService();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    final double? cLat = widget.takeLocationChosenLat;
    final double? cLng = widget.takeLocationChosenLng;
    if (cLat != null && cLng != null) {
      _taggedLat = cLat;
      _taggedLng = cLng;
    }
    // ignore: discarded_futures
    _tagFromExifThenDevice();

    _liveDetections = widget.detections;
    _liveCount = widget.count;
    _liveConfidencePct = widget.confidence;
    _recomputeDetectionDerived();

    // Show the 3-step popup after the first frame so the results page is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: discarded_futures
      _maybeShowShowcaseAfterDetection();
    });
  }

  String _resultsAppBarTitle(bool filipino) {
    final String? fid = widget.fieldId?.trim();
    if (fid != null && fid.isNotEmpty) return widget.fieldName;
    return 'Results';
  }

  Future<void> _maybeShowShowcaseAfterDetection() async {
    if (!mounted || _showcaseShown) return;
    _showcaseShown = true;
    final bool fil = context.read<AppState>().isFilipino;
    final double sev = severity01(
      bugCount: _liveCount,
      confidencePct: _overallPctUi,
    );
    final InsightEntry insight = insightForSeverity(sev);
    await showDetectionShowcaseDialog(
      context: context,
      filipino: fil,
      imagePath: widget.imagePath,
      imageBytes: widget.imageBytes,
      detections: confirmedDetections(_liveDetections),
      originalImageWidth: widget.originalImageWidth,
      originalImageHeight: widget.originalImageHeight,
      overallConfidencePct: _overallPctUi,
      count: _liveCount,
      insightsTitle: fil ? insight.titleFil : insight.titleEn,
      insightsBody: fil ? insight.bodyFil : insight.bodyEn,
    );
  }

  String? get _effectiveFieldId {
    final String? v = widget.fieldId?.trim();
    return (v != null && v.isNotEmpty) ? v : null;
  }

  String get _effectiveFieldName {
    final String? fid = widget.fieldId?.trim();
    if (fid != null &&
        fid.isNotEmpty &&
        widget.fieldName.trim().isNotEmpty) {
      return widget.fieldName;
    }
    if ((_fence?.isInside ?? false) &&
        (_fence?.land?.landName.trim().isNotEmpty ?? false)) {
      return _fence!.land!.landName;
    }
    return widget.fieldName;
  }

  void _recomputeDetectionDerived() {
    _liveCount = confirmedCount(_liveDetections);
    _sortedDetectionsUi = List<Detection>.from(_liveDetections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<Detection> basis = confirmedDetections(_liveDetections);
    final Iterable<Detection> confBasis =
        basis.isNotEmpty ? basis : _sortedDetectionsUi;
    final double overallConfidence = confBasis.isEmpty
        ? (_liveConfidencePct.clamp(0, 100) / 100.0)
        : (confBasis.map((Detection d) => d.confidence).reduce((a, b) => a + b) /
            confBasis.length);
    _overallPctUi = (overallConfidence * 100).round().clamp(0, 100);
    final double topConfidence = _sortedDetectionsUi.isEmpty
        ? (_liveConfidencePct.clamp(0, 100) / 100.0)
        : _sortedDetectionsUi.first.confidence;
    _topPctUi = (topConfidence * 100).round().clamp(0, 100);
  }

  /// Priority: user map pick → EXIF → GPS when gallery photo was chosen → live device.
  Future<void> _tagFromExifThenDevice() async {
    if (_taggedLat != null && _taggedLng != null) {
      await _updateGeoFence();
      return;
    }
    final ({double lat, double lng})? exifGps = await readGpsFromImage(
      bytes: widget.imageBytes,
      path: widget.imagePath,
    );
    if (!mounted) return;
    if (exifGps != null) {
      setState(() {
        _taggedLat = exifGps.lat;
        _taggedLng = exifGps.lng;
      });
      await _updateGeoFence();
      return;
    }
    final double? mLat = widget.pickMomentLat;
    final double? mLng = widget.pickMomentLng;
    if (mLat != null && mLng != null) {
      setState(() {
        _taggedLat = mLat;
        _taggedLng = mLng;
      });
      await _updateGeoFence();
      return;
    }
    await _autoTagCurrentLocation();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _autoTagCurrentLocation() async {
    if (_taggedLat != null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final GeoLocationResult r = await GeoService().getCurrentPosition();
      if (!mounted) return;
      if (r.isSuccess) {
        setState(() {
          _taggedLat = r.latitude;
          _taggedLng = r.longitude;
        });
        await _updateGeoFence();
      }
    } catch (_) {
      // If location isn't available/permission denied, keep manual tagging only.
    }
  }

  Future<bool> _ensureTaggedLocation({
    required bool showUi,
  }) async {
    if (_taggedLat != null && _taggedLng != null) return true;
    if (_gettingGps) return false;
    _gettingGps = true;
    final ActionPopupController popup = ActionPopupController();
    try {
      final double? chosenLat = widget.takeLocationChosenLat;
      final double? chosenLng = widget.takeLocationChosenLng;
      if (chosenLat != null && chosenLng != null) {
        setState(() {
          _taggedLat = chosenLat;
          _taggedLng = chosenLng;
        });
        await _updateGeoFence();
        return true;
      }

      // User may save before initState EXIF read finishes; try EXIF next.
      final ({double lat, double lng})? exifGps = await readGpsFromImage(
        bytes: widget.imageBytes,
        path: widget.imagePath,
      );
      if (!mounted) return false;
      if (exifGps != null) {
        setState(() {
          _taggedLat = exifGps.lat;
          _taggedLng = exifGps.lng;
        });
        await _updateGeoFence();
        return true;
      }

      final double? pmLat = widget.pickMomentLat;
      final double? pmLng = widget.pickMomentLng;
      if (pmLat != null && pmLng != null) {
        setState(() {
          _taggedLat = pmLat;
          _taggedLng = pmLng;
        });
        await _updateGeoFence();
        return true;
      }

      if (showUi && mounted) {
        popup.showBlockingProgress(
          context,
          message: 'Getting GPS…',
        );
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final GeoLocationResult r = await GeoService().getCurrentPosition();
      if (!mounted) return false;
      if (!r.isSuccess) return false;
      setState(() {
        _taggedLat = r.latitude;
        _taggedLng = r.longitude;
      });
      await _updateGeoFence();
      return true;
    } catch (_) {
      return false;
    } finally {
      popup.close();
      _gettingGps = false;
    }
  }

  Future<void> _updateGeoFence() async {
    final double? lat = _taggedLat;
    final double? lng = _taggedLng;
    if (lat == null || lng == null) return;
    final String? existingFieldId = widget.fieldId?.trim();
    if (existingFieldId != null && existingFieldId.isNotEmpty) {
      await _refreshSelectedFieldBoundary();
      return;
    }
    try {
      await _db.initialize();
      final List<Land> lands = await _db.getAllLands();
      final GeoFenceResult res = _geoFence.findLandForPoint(lat, lng, lands);
      if (!mounted) return;
      setState(() => _fence = res);
    } catch (_) {}
  }

  Future<void> _refreshSelectedFieldBoundary() async {
    if (!mounted) return;
    final FieldBoundarySaveGate gate = await fieldBoundarySaveGate(
      db: _db,
      fieldId: _effectiveFieldId,
      fieldName: widget.fieldName,
      latitude: _taggedLat,
      longitude: _taggedLng,
    );
    Land? boundaryLand;
    final List<LatLngPoint>? ring = await loadFieldBoundaryRing(
      _db,
      fieldId: _effectiveFieldId,
      fieldName: widget.fieldName,
    );
    if (ring != null && ring.length >= 3) {
      final String label = widget.fieldName.trim().isEmpty
          ? 'Field'
          : widget.fieldName.trim();
      boundaryLand = Land(
        landName: label,
        polygonCoordinates: ring,
        createdAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    setState(() {
      _selectedFieldBoundaryGate = gate;
      if (boundaryLand != null) {
        _fence = GeoFenceResult(
          land: boundaryLand,
          isInside: gate == FieldBoundarySaveGate.inside,
        );
      }
    });
  }

  Future<Land?> _selectedFieldBoundaryLand() async {
    if (_fence?.land != null &&
        (_fence!.land!.polygonCoordinates.length >= 3)) {
      return _fence!.land;
    }
    await _db.initialize();
    final List<LatLngPoint>? ring = await loadFieldBoundaryRing(
      _db,
      fieldId: _effectiveFieldId,
      fieldName: widget.fieldName,
    );
    if (ring == null || ring.length < 3) return null;
    final String label = widget.fieldName.trim().isEmpty
        ? 'Field'
        : widget.fieldName.trim();
    return Land(
      landName: label,
      polygonCoordinates: ring,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> _confirmSaveAllowedForFieldBoundary(
    BuildContext context,
    bool fil,
  ) async {
    final FieldBoundarySaveGate gate = await fieldBoundarySaveGate(
      db: _db,
      fieldId: _effectiveFieldId,
      fieldName: widget.fieldName,
      latitude: _taggedLat,
      longitude: _taggedLng,
    );
    if (!mounted) return false;
    setState(() => _selectedFieldBoundaryGate = gate);

    switch (gate) {
      case FieldBoundarySaveGate.unassigned:
      case FieldBoundarySaveGate.noBoundary:
      case FieldBoundarySaveGate.inside:
        return true;
      case FieldBoundarySaveGate.locationRequired:
        if (!context.mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(fil ? 'Kailangan ang lokasyon' : 'Location required'),
            content: Text(
              fil
                  ? 'I-on ang GPS o pindutin ang mapa sa ibaba para itakda kung saan kinuha ang larawan bago i-save.'
                  : 'Turn on GPS or tap the map below to set where this photo was taken before saving.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(fil ? 'OK' : 'OK'),
              ),
            ],
          ),
        );
        return false;
      case FieldBoundarySaveGate.outside:
        if (!context.mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              fil ? 'Labas sa piniling field' : 'Out of bounds',
            ),
            content: Text(
              fil
                  ? 'Nasa labas ka ng hangganan ng field na pinili mo (“${widget.fieldName}”). Pumunta sa loob ng field, pumili ng ibang field, o itakda ang tamang lokasyon sa mapa.'
                  : 'You are outside the boundary of the field you chose (“${widget.fieldName}”). Move inside the field, choose a different field, or set the correct location on the map.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(fil ? 'OK' : 'OK'),
              ),
            ],
          ),
        );
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final bool hasMealybugHits = visibleCount(_liveDetections) > 0;
    return AppScaffold(
      title: _resultsAppBarTitle(fil),
      bottomNavigationBar: widget.guestMode
          ? _guestResultBottomBar(context, fil)
          : _saveRetakeBottomBar(context, fil),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          // Required: vertical scroll gives unbounded max height; default
          // mainAxisSize.max makes the column expand infinitely and can yield
          // a blank body (no laid-out children) on some devices/build modes.
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ScanFlowStepIndicator(
              currentStep: 3,
              filipino: fil,
            ),
            const SizedBox(height: 12),
            _ScanContextBanner(
              filipino: fil,
              guestMode: widget.guestMode,
              fieldLabel: _effectiveFieldName,
            ),
            const SizedBox(height: 16),
            if (widget.imagePath != null && widget.imagePath!.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => _DetectionImageViewerScreen(
                        imagePath: widget.imagePath!,
                        imageBytes: widget.imageBytes,
                        detections: confirmedDetections(_liveDetections),
                        manualCheckDetections:
                            manualCheckDetections(_liveDetections),
                        originalImageWidth: widget.originalImageWidth,
                        originalImageHeight: widget.originalImageHeight,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                  height: 280,
                  child: _DetectionPreviewImage(
                    imagePath: widget.imagePath!,
                    imageBytes: widget.imageBytes,
                    detections: confirmedDetections(_liveDetections),
                    manualCheckDetections:
                        manualCheckDetections(_liveDetections),
                    originalImageWidth: widget.originalImageWidth,
                    originalImageHeight: widget.originalImageHeight,
                  ),
                ),
                ),
              ),
              if (manualCheckDetections(_liveDetections).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  fil
                      ? DetectionAdvisoryMessages.manualCheckLegendFil
                      : DetectionAdvisoryMessages.manualCheckLegendEn,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF39C12),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppTheme.primaryGreen,
                    AppTheme.secondaryGreen,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    fil
                        ? 'Kumpiyansa ng deteksyon'
                        : 'Detection confidence',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    fil ? '(scan na ito)' : '(this scan)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_overallPctUi%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    fil
                        ? 'Karaniwan sa mga deteksyon'
                        : 'Average detection score',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                    ),
                  ),
                  if (_sortedDetectionsUi.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      fil
                          ? 'Pinakamalakas na box: $_topPctUi%'
                          : 'Strongest detection: $_topPctUi%',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  Text(
                    hasMealybugHits
                        ? (fil
                            ? DetectionAdvisoryMessages
                                .possibleDetectionResultLabelFil
                            : DetectionAdvisoryMessages
                                .possibleDetectionResultLabelEn)
                        : (fil
                            ? DetectionAdvisoryMessages
                                .noDetectionResultLabelFil
                            : DetectionAdvisoryMessages
                                .noDetectionResultLabelEn),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (hasMealybugHits) ...[
                    const SizedBox(height: 4),
                    Text(
                      fil
                          ? DetectionAdvisoryMessages
                              .possibleDetectionVerifyFil
                          : DetectionAdvisoryMessages
                              .possibleDetectionVerifyEn,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    fil
                        ? 'Hindi ito accuracy ng modelo (mAP) o porsyento ng sakit sa buong halaman.'
                        : 'Not model accuracy (mAP) or whole-plant infestation %.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: <Widget>[
                            const Icon(Icons.bug_report, color: Colors.white),
                            Text(
                              fil
                                  ? 'Mealybug: $_liveCount'
                                  : 'Mealybugs: $_liveCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      fil ? 'Ano ang susunod?' : 'What to do next',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.pineTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detectionNextStepsText(
                          fil: fil, hasHits: hasMealybugHits),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_sortedDetectionsUi.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _showAllDetections = !_showAllDetections),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  fil ? 'Mga Deteksyon' : 'Detections',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.pineTextPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                _showAllDetections
                                    ? (fil ? 'I-collapse' : 'Collapse')
                                    : (fil ? 'Ipakita lahat' : 'Show all'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                _showAllDetections
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List<Widget>.generate(
                        _showAllDetections
                            ? _sortedDetectionsUi.length
                            : math.min(5, _sortedDetectionsUi.length),
                        (int i) {
                          final Detection d = _sortedDetectionsUi[i];
                        final int pct = (d.confidence * 100).round().clamp(0, 100);
                        final String label = d.label ?? (fil ? 'Mealybug' : 'Mealybug');
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: i ==
                                    (_showAllDetections
                                            ? _sortedDetectionsUi.length
                                            : math.min(5, _sortedDetectionsUi.length)) -
                                        1
                                ? 0
                                : 10,
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 28,
                                height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: context.pineTextPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: context.pineTextPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                        },
                      ),
                      if (!_showAllDetections && _sortedDetectionsUi.length > 5) ...[
                        const SizedBox(height: 8),
                        Text(
                          fil
                              ? '+${_sortedDetectionsUi.length - 5} pang deteksyon'
                              : '+${_sortedDetectionsUi.length - 5} more detections',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        fil
                            ? 'Ang porsyento ay kumpiyansa ng AI sa bawat deteksyon.'
                            : 'Percent is the AI confidence for each detection.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            _LocationPreviewCard(
              pulse: _pulse,
              bugCount: _liveCount,
              lat: _taggedLat,
              lng: _taggedLng,
              onTap: () async {
                if (!await ensureOnline(context)) return;
                if (!context.mounted) return;
                final Land? boundaryLand = await _selectedFieldBoundaryLand();
                if (!context.mounted) return;
                final dynamic result = await Navigator.push<Object?>(
                  context,
                  MaterialPageRoute<Object?>(
                    builder: (_) => LocationPickerScreen(
                      initialCenter: _taggedLat != null && _taggedLng != null
                          ? latlong2.LatLng(_taggedLat!, _taggedLng!)
                          : null,
                      animateZoomIn: boundaryLand == null,
                      fieldBoundaryLand: boundaryLand ?? _fence?.land,
                      fieldBoundaryLabel: _effectiveFieldId != null
                          ? widget.fieldName.trim()
                          : null,
                    ),
                  ),
                );
                if (result != null && result is latlong2.LatLng && context.mounted) {
                  final latlong2.LatLng point = result;
                  setState(() {
                    _taggedLat = point.latitude;
                    _taggedLng = point.longitude;
                  });
                  await _updateGeoFence();
                }
              },
            ),
            if (_effectiveFieldId != null &&
                _selectedFieldBoundaryGate ==
                    FieldBoundarySaveGate.inside) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fil
                            ? 'Nasa loob ng piniling field: ${widget.fieldName}'
                            : 'Inside chosen field: ${widget.fieldName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_effectiveFieldId != null &&
                _selectedFieldBoundaryGate ==
                    FieldBoundarySaveGate.outside) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fil
                            ? 'Nasa labas ng piniling field. Hindi maise-save hanggang nasa loob ka ng hangganan.'
                            : 'Outside chosen field. Save is blocked until you are inside the boundary.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if ((widget.fieldId == null || widget.fieldId!.trim().isEmpty) &&
                (_fence?.isInside ?? false) &&
                (_fence?.land?.landName.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.fence,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.9),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fil
                            ? 'Nasa loob ng field: ${_fence!.land!.landName}'
                            : 'Inside field boundary: ${_fence!.land!.landName}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.pineTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (widget.guestMode)
              Text(
                fil
                    ? 'Guest scan — hindi nase-save. Mag-sign up para i-track ang mga field.'
                    : 'Guest scan — not saved. Sign up to save scans and track fields.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _saveRetakeBottomBar(BuildContext context, bool fil) {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : () => _saveDetection(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          fil ? 'I-save' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).pushAndRemoveUntil<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => PhotoSourcePicker(
                                fieldName: widget.fieldName,
                                fieldId: widget.fieldId,
                              ),
                            ),
                            (Route<dynamic> route) => route.isFirst,
                          );
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.primaryGreen),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    fil ? 'Ulit' : 'Retake',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guestResultBottomBar(BuildContext context, bool fil) {
    return Material(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterScreen(),
                      ),
                      (Route<dynamic> r) => r.isFirst,
                    );
                  },
                  child: Text(fil ? 'Mag-sign up / Log in' : 'Sign up / Log in'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const PhotoSourcePicker(
                          fieldName: 'Guest scan',
                          guestMode: true,
                        ),
                      ),
                      (Route<dynamic> route) => route.isFirst,
                    );
                  },
                  child: Text(fil ? 'Ulit' : 'Retake'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDetection(BuildContext context) async {
    if (widget.guestMode) return;
    if (_saving) return;
    setState(() => _saving = true);

    // Make sure we try to tag a location before saving (works offline via last-known).
    await _ensureTaggedLocation(showUi: true);

    if (!context.mounted) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    final bool fil = context.read<AppState>().isFilipino;
    if (!await _confirmSaveAllowedForFieldBoundary(context, fil)) {
      setState(() => _saving = false);
      return;
    }

    if (widget.imagePath == null || widget.imagePath!.isEmpty) {
      if (context.mounted) {
        Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);
      }
      setState(() => _saving = false);
      return;
    }
    final File file = File(widget.imagePath!);
    if (!await file.exists()) {
      if (context.mounted) {
        await ActionPopup.showError(
          context,
          message: 'Image file not found.',
        );
      }
      setState(() => _saving = false);
      return;
    }
    // Always save locally first so the app works offline.
    final bytes = await file.readAsBytes();
    final String localPath =
        await ImageStorageService().saveDetectionImage(bytes);

    // Enqueue for cloud sync when online.
    final db = DatabaseService();
    await db.initialize();

    final String userId =
        SupabaseClientProvider.instance.client.auth.currentUser?.id ?? '';
    final String effectiveFieldName = _effectiveFieldName;
    final int capturedId = await db.insertCapturedPhoto(
      localImagePath: localPath,
      fieldName: effectiveFieldName,
      confidence: widget.confidence,
      count: widget.count,
      detectionsJson: jsonEncode(
        confirmedDetections(_liveDetections)
            .map((d) => <String, dynamic>{
                  'left': d.left,
                  'top': d.top,
                  'width': d.width,
                  'height': d.height,
                  'confidence': d.confidence,
                  'classIndex': d.classIndex,
                  'label': d.label,
                })
            .toList(),
      ),
      fieldId: _effectiveFieldId,
      userId: userId.isEmpty ? null : userId,
      latitude: _taggedLat,
      longitude: _taggedLng,
    );
    final int queueId = await db.enqueueUpload(
      localImagePath: localPath,
      confidence: widget.confidence,
      count: widget.count,
      fieldId: _effectiveFieldId,
      latitude: _taggedLat,
      longitude: _taggedLng,
      nameHint: buildUploadNameHint(
        fieldLabel: effectiveFieldName,
        originalFilePath: widget.imagePath,
      ),
    );

    if (!context.mounted) return;
    final bool online = await NetworkReachability.isOnline();
    if (!context.mounted) return;
    final bool canUploadLater = userId.isNotEmpty;
    final String message = online
        ? (canUploadLater
            ? (fil ? 'Na-save ang larawan.' : 'Picture saved.')
            : (fil
                ? 'Na-save sa phone. Mag-sign in para ma-upload.'
                : 'Saved on your phone. Sign in to upload.'))
        : (fil
            ? 'Na-save nang offline. Ia-upload kapag online.'
            : 'Saved offline. Will upload when online.');

    final bool noGps = _taggedLat == null || _taggedLng == null;
    final String fullMessage = noGps
        ? '$message\n\n${fil ? 'Paalala: Na-save nang walang GPS sa mapa.' : 'Note: Saved without a GPS location on the map.'}'
        : message;

    // Field-first flow: field was chosen before capture — skip post-save assign.
    final Map<String, String?>? pickedField = _effectiveFieldId != null
        ? null
        : await Navigator.push<Map<String, String?>>(
            context,
            MaterialPageRoute<Map<String, String?>>(
              builder: (_) => AssignFieldScreen(
                initialFieldId: _effectiveFieldId,
                title: fil ? 'Pumili ng field' : 'Choose a field',
              ),
            ),
          );
    if (!context.mounted) return;
    if (pickedField != null) {
      final String? newFieldId = pickedField['id'];
      final String? newFieldName = pickedField['name'];
      final String finalName =
          (newFieldName != null && newFieldName.trim().isNotEmpty)
              ? newFieldName
              : (fil ? 'Walang field' : 'Unassigned');
      await db.updateCapturedPhotoField(
        id: capturedId,
        fieldName: finalName,
        fieldId: (newFieldId != null && newFieldId.trim().isNotEmpty)
            ? newFieldId
            : null,
      );
      await db.updateUploadQueueField(
        id: queueId,
        fieldId: (newFieldId != null && newFieldId.trim().isNotEmpty)
            ? newFieldId
            : null,
      );
    }

    // Upload immediately (when possible) so the Field page updates right away.
    // If upload fails, keep the capture saved locally and show a clear message.
    final bool canTryUploadNow =
        userId.isNotEmpty && await NetworkReachability.isOnline();
    if (!context.mounted) return;
    if (canTryUploadNow) {
      final ActionPopupController uploading = ActionPopupController();
      uploading.showBlockingProgress(
        context,
        message: fil ? 'Ina-upload…' : 'Uploading…',
      );
      try {
        await CloudSyncService(databaseService: db).syncPending(limit: 1);
      } finally {
        uploading.close();
      }

      final Map<String, dynamic>? q = await db.getUploadQueueById(queueId);
      final String? status = q?['status']?.toString();
      final String? lastError = q?['last_error']?.toString();
      if (status != 'synced' && lastError != null && lastError.trim().isNotEmpty) {
        if (!context.mounted) return;
        await ActionPopup.showInfo(
          context,
          title: fil ? 'Na-save' : 'Saved',
          message: (fil
                  ? 'Na-save ang larawan, pero hindi na-upload ngayon.\n\n'
                  : 'Saved locally, but upload did not complete.\n\n') +
              lastError,
        );
      }
    } else if (userId.isNotEmpty) {
      // Signed in but offline: kick off sync later.
      CloudSyncService(databaseService: db).syncInBackground();
    }

    if (!context.mounted) return;

    final AppState appState = context.read<AppState>();
    final String? savedFieldId = _effectiveFieldId;
    final String savedFieldName = _effectiveFieldName;
    final double? savedPinLat = _taggedLat;
    final double? savedPinLng = _taggedLng;

    await ActionPopup.showSuccessAutoDismiss(
      context,
      title: fil ? 'Na-save' : 'Saved',
      message: fullMessage,
      dismissAfter: const Duration(milliseconds: 1500),
      countdownLabel: (double r) {
        if (r <= 0) return '';
        final String s = r < 1 ? r.toStringAsFixed(1) : r.toStringAsFixed(0);
        return fil ? 'Magpapatuloy sa ${s}s…' : 'Continuing in ${s}s…';
      },
    );
    if (!context.mounted) return;

    Navigator.popUntil(context, (Route<dynamic> route) => route.isFirst);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.bumpCapturedPhotos();
      if (savedFieldId != null && savedFieldId.isNotEmpty) {
        appState.requestNavigateToFieldAfterScan(
          fieldId: savedFieldId,
          fieldName: savedFieldName,
          pinLat: savedPinLat,
          pinLng: savedPinLng,
        );
      } else {
        appState.requestDashboardHomeTab();
      }
    });
  }
}

class _LocationPreviewCard extends StatelessWidget {
  const _LocationPreviewCard({
    required this.pulse,
    required this.bugCount,
    required this.lat,
    required this.lng,
    required this.onTap,
  });

  final Animation<double> pulse;
  final int bugCount;
  final double? lat;
  final double? lng;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final has = lat != null && lng != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 118,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppTheme.primaryGreen.withValues(alpha: 0.10),
                Colors.white,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MiniMapPainter(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.16),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: pulse,
                      builder: (context, _) {
                        final t = pulse.value;
                        final radius = 12 + (t * 12);
                        final double s01 = (bugCount / 12.0).clamp(0.0, 1.0);
                        final Color base = Color.lerp(
                              const Color(0xFF2ECC71),
                              const Color(0xFFE74C3C),
                              s01,
                            ) ??
                            AppTheme.primaryGreen;
                        return SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (has)
                                CustomPaint(
                                  size: Size(radius * 2, radius * 2),
                                  painter: _HexPulsePainter(
                                    color: base,
                                    t: t,
                                  ),
                                ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      has ? base : Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                size: 22,
                                color: has ? base : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            has
                                ? (fil ? 'Naka-tag na lokasyon' : 'Tagged location')
                                : (fil
                                    ? 'Awtomatikong pagta-tag ng lokasyon…'
                                    : 'Auto-tagging location…'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: context.pineTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            has
                                ? '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                                : (fil ? 'Pindutin para pumili sa mapa' : 'Tap to choose on map'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: has
                                  ? context.pineTextPrimary
                                  : context.pineTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.pineTextSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Subtle "map grid" + a couple of curvy "roads".
    const grid = 18.0;
    for (double x = 0; x < size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final road = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final p1 = Path()
      ..moveTo(0, size.height * 0.65)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.50,
        size.width * 0.42,
        size.height * 0.82,
        size.width * 0.72,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.44,
        size.width,
        size.height * 0.50,
      );
    canvas.drawPath(p1, road);

    final p2 = Path()
      ..moveTo(size.width * 0.08, 0)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.22,
        size.width * 0.22,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.12,
        size.height * 0.66,
        size.width * 0.20,
        size.height,
      );
    canvas.drawPath(p2, road);
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HexPulsePainter extends CustomPainter {
  _HexPulsePainter({
    required this.color,
    required this.t,
  });

  final Color color;
  final double t;

  Path _hexPath(Size size, double scale) {
    final Offset c = size.center(Offset.zero);
    final double r = (size.shortestSide / 2) * scale;
    final Path p = Path();
    for (int i = 0; i < 6; i++) {
      final double a = (3.141592653589793 / 3.0) * i - (3.141592653589793 / 2);
      final Offset pt = Offset(
        c.dx + r * math.cos(a),
        c.dy + r * math.sin(a),
      );
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double alpha = (1.0 - t).clamp(0.0, 1.0);
    final Path outer = _hexPath(size, 1.0 + (t * 0.35));
    final Path inner = _hexPath(size, 0.62);

    final Paint fill = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    canvas.drawPath(inner, fill);

    final Paint ring = Paint()
      ..color = color.withValues(alpha: 0.25 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(outer, ring);
  }

  @override
  bool shouldRepaint(covariant _HexPulsePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.t != t;
  }
}

class _DetectionPreviewImage extends StatefulWidget {
  const _DetectionPreviewImage({
    required this.imagePath,
    this.imageBytes,
    required this.detections,
    this.manualCheckDetections = const <Detection>[],
    this.originalImageWidth,
    this.originalImageHeight,
  });

  final String imagePath;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final List<Detection> manualCheckDetections;
  final int? originalImageWidth;
  final int? originalImageHeight;

  @override
  State<_DetectionPreviewImage> createState() => _DetectionPreviewImageState();
}

class _DetectionPreviewImageState extends State<_DetectionPreviewImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _markerPulse;
  OrientedImageData? _oriented;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _markerPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    // ignore: discarded_futures
    _loadOrientedImage();
  }

  @override
  void didUpdateWidget(covariant _DetectionPreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.imagePath != widget.imagePath) {
      // ignore: discarded_futures
      _loadOrientedImage();
    }
  }

  @override
  void dispose() {
    _markerPulse.dispose();
    super.dispose();
  }

  Future<void> _loadOrientedImage() async {
    setState(() => _loading = true);
    try {
      Uint8List? raw = widget.imageBytes;
      if (raw == null && widget.imagePath.isNotEmpty) {
        raw = await File(widget.imagePath).readAsBytes();
      }
      OrientedImageData? data;
      if (raw != null) {
        data = bakeImageBytes(raw);
      }
      if (!mounted) return;
      setState(() {
        _oriented = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _oriented = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    final OrientedImageData? oriented = _oriented;
    if (oriented == null) {
      return const Center(child: Icon(Icons.broken_image_outlined));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ({Offset offset, double scale, Size drawnSize}) layout =
              detectionOverlayLayout(
            imageSize: oriented.size,
            constraints: constraints,
          );

          final Widget scene = Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: layout.offset.dx,
                top: layout.offset.dy,
                width: layout.drawnSize.width,
                height: layout.drawnSize.height,
                child: Image.memory(
                  oriented.bytes,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              if (widget.detections.isNotEmpty ||
                  widget.manualCheckDetections.isNotEmpty)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _markerPulse,
                    builder: (BuildContext context, Widget? _) {
                      return CustomPaint(
                        painter: DetectionMarkersPainter(
                          detections: widget.detections,
                          manualCheckDetections: widget.manualCheckDetections,
                          imageOffset: layout.offset,
                          imageScale: layout.scale,
                          pulse: _markerPulse.value,
                        ),
                      );
                    },
                  ),
                ),
            ],
          );

          return ColoredBox(
            color: Colors.black.withValues(alpha: 0.04),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(64),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: scene,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetectionImageViewerScreen extends StatelessWidget {
  const _DetectionImageViewerScreen({
    required this.imagePath,
    required this.imageBytes,
    required this.detections,
    this.manualCheckDetections = const <Detection>[],
    required this.originalImageWidth,
    required this.originalImageHeight,
  });

  final String imagePath;
  final Uint8List? imageBytes;
  final List<Detection> detections;
  final List<Detection> manualCheckDetections;
  final int? originalImageWidth;
  final int? originalImageHeight;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Detection Preview',
      usePatternBackground: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Pinch to zoom · drag to pan',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _DetectionPreviewImage(
                  imagePath: imagePath,
                  imageBytes: imageBytes,
                  detections: detections,
                  manualCheckDetections: manualCheckDetections,
                  originalImageWidth: originalImageWidth,
                  originalImageHeight: originalImageHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Camera Mode Selector ---
class CameraModeSelector extends StatefulWidget {
  const CameraModeSelector({
    super.key,
    required this.fieldName,
    this.fieldId,
  });

  final String fieldName;
  final String? fieldId;

  @override
  State<CameraModeSelector> createState() => _CameraModeSelectorState();
}

class _CameraModeSelectorState extends State<CameraModeSelector> {
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();
  InferenceService get _inferenceService =>
      ServiceLocator.instance.get<InferenceService>();

  Future<void> _captureAndDetect() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 100,
      );
      if (photo == null || !mounted) {
        setState(() => _isCapturing = false);
        return;
      }
      final String path = photo.path;
      int confidence = 0;
      int count = 0;
      List<Detection> detections = const <Detection>[];
      int? originalImageWidth;
      int? originalImageHeight;
      Uint8List? imageBytes;
      try {
        final File file = File(path);
        final List<int> bytes = await file.readAsBytes();
        if (!mounted) return;
        imageBytes = Uint8List.fromList(bytes);
        final bool fil = context.read<AppState>().isFilipino;
        final DetectionResult result = await runInferenceWithProgressUi(
          context: context,
          inferenceService: _inferenceService,
          imageBytes: imageBytes,
          filipino: fil,
        );
        if (!mounted) return;
        detections = result.detections;
        count = confirmedCount(detections);
        originalImageWidth = result.originalWidth;
        originalImageHeight = result.originalHeight;
        confidence = _meanConfidencePct(detections);
        if (visibleCount(detections) == 0 && mounted) {
          await ActionPopup.showInfo(
            context,
            title: context.read<AppState>().isFilipino
                ? DetectionAdvisoryMessages.noDetectionPopupTitleFil
                : DetectionAdvisoryMessages.noDetectionPopupTitleEn,
            message: _noDetectionsDetailMessage(context),
          );
        }
      } catch (e) {
        // Make inference failures visible instead of silently showing 0%.
        AppLogger.error('Inference ERROR (camera)', e);
        if (mounted) {
          await ActionPopup.showError(
            context,
            message: 'Detection failed: $e',
          );
        }
      }
      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoResultScreen(
            fieldName: widget.fieldName,
            imagePath: path,
            imageBytes: imageBytes,
            confidence: confidence,
            count: count,
            detections: detections,
            originalImageWidth: originalImageWidth,
            originalImageHeight: originalImageHeight,
            fieldId: widget.fieldId,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        await ActionPopup.showError(
          context,
          message: 'Could not capture photo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.fieldName,
      usePatternBackground: false,
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Expanded(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text(
                          'Camera',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isCapturing ? null : _captureAndDetect,
                          icon: _isCapturing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                              _isCapturing ? 'Processing...' : 'Take Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

// --- Albums Screen ---
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({
    super.key,
    required this.fieldName,
    this.fieldId,
  });

  final String fieldName;
  final String? fieldId;

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  bool _isProcessing = false;
  bool _loadingAlbums = true;
  List<({String name, int count})> _albums = <({String name, int count})>[];
  String? _loadError;
  final ImagePicker _picker = ImagePicker();
  InferenceService get _inferenceService =>
      ServiceLocator.instance.get<InferenceService>();

  @override
  void initState() {
    super.initState();
    _loadDeviceAlbums();
  }

  Future<void> _loadDeviceAlbums() async {
    try {
      final PermissionState state =
          await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (!state.isAuth) {
        setState(() {
          _loadingAlbums = false;
          _loadError = 'Gallery permission denied';
        });
        return;
      }
      final List<AssetPathEntity> paths =
          await PhotoManager.getAssetPathList(type: RequestType.image);
      final List<({String name, int count})> list =
          <({String name, int count})>[];
      for (final AssetPathEntity path in paths) {
        final int count = await path.assetCountAsync;
        if (!mounted) return;
        list.add((name: path.name, count: count));
      }
      if (!mounted) return;
      setState(() {
        _albums = list;
        _loadingAlbums = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAlbums = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _pickAndDetect() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null || !mounted) {
        setState(() => _isProcessing = false);
        return;
      }
      final String path = picked.path;
      Land? boundaryLand;
      try {
        final DatabaseService db = DatabaseService();
        await db.initialize();
        boundaryLand = await db.findLandByFieldName(widget.fieldName);
      } catch (_) {}
      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }
      final latlong2.LatLng? mapPick = await _promptOptionalWherePhotoTaken(
        context,
        fieldBoundaryLand: boundaryLand,
      );
      if (!mounted) {
        setState(() => _isProcessing = false);
        return;
      }
      final ({double? lat, double? lng}) pickGps =
          await _deviceGpsWhenGalleryPhotoChosen();
      final double? chosenTakeLat = mapPick?.latitude;
      final double? chosenTakeLng = mapPick?.longitude;
      final double? pickMomentLat = pickGps.lat;
      final double? pickMomentLng = pickGps.lng;

      int confidence = 0;
      int count = 0;
      List<Detection> detections = const <Detection>[];
      int? originalImageWidth;
      int? originalImageHeight;
      Uint8List? imageBytes;
      try {
        final List<int> bytes = await picked.readAsBytes();
        if (!mounted) return;
        imageBytes = Uint8List.fromList(bytes);
        final bool fil = context.read<AppState>().isFilipino;
        final DetectionResult result = await runInferenceWithProgressUi(
          context: context,
          inferenceService: _inferenceService,
          imageBytes: imageBytes,
          filipino: fil,
        );
        if (!mounted) return;
        detections = result.detections;
        count = confirmedCount(detections);
        originalImageWidth = result.originalWidth;
        originalImageHeight = result.originalHeight;
        confidence = _meanConfidencePct(detections);
        if (visibleCount(detections) == 0 && mounted) {
          await ActionPopup.showInfo(
            context,
            title: context.read<AppState>().isFilipino
                ? DetectionAdvisoryMessages.noDetectionPopupTitleFil
                : DetectionAdvisoryMessages.noDetectionPopupTitleEn,
            message: _noDetectionsDetailMessage(context),
          );
        }
      } catch (e) {
        AppLogger.error('Inference ERROR (gallery)', e);
        if (mounted) {
          await ActionPopup.showError(
            context,
            message: 'Detection failed: $e',
          );
        }
      }
      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PhotoResultScreen(
            fieldName: widget.fieldName,
            imagePath: path,
            imageBytes: imageBytes,
            confidence: confidence,
            count: count,
            detections: detections,
            originalImageWidth: originalImageWidth,
            originalImageHeight: originalImageHeight,
            fieldId: widget.fieldId,
            takeLocationChosenLat: chosenTakeLat,
            takeLocationChosenLng: chosenTakeLng,
            pickMomentLat: pickMomentLat,
            pickMomentLng: pickMomentLng,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        await ActionPopup.showError(
          context,
          message: 'Could not pick image.',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Albums',
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : _loadingAlbums
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (_loadError != null) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _loadError!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      _buildAlbumTile(context, 'Pick from gallery', 0),
                    ] else if (_albums.isEmpty) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No albums found'),
                        ),
                      ),
                      _buildAlbumTile(context, 'Pick from gallery', 0),
                    ] else ...[
                      const Text(
                        'My Albums',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      for (final album in _albums)
                        _buildAlbumTile(context, album.name, album.count),
                    ],
                  ],
                ),
    );
  }

  Widget _buildAlbumTile(BuildContext context, String name, int count) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.photo_album, color: AppTheme.primaryGreen),
      ),
      title: Text(name),
      trailing: count > 0
          ? Text(
              count.toString(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: _pickAndDetect,
    );
  }
}
