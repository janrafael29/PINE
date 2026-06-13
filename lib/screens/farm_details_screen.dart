// Add/edit farm information with field name and location.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/network_reachability.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import 'location_picker_screen.dart';
import '../widgets/online_required_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/image_storage_service.dart';
import '../services/database_service.dart';
import '../models/land.dart';
import 'land_map_screen.dart';
import '../services/geo_fence_service.dart';
import '../utils/uuid_v4.dart';

class FarmDetailsScreen extends StatefulWidget {
  const FarmDetailsScreen({super.key});

  @override
  State<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends State<FarmDetailsScreen> {
  final TextEditingController _fieldNameController = TextEditingController();
  String _selectedLocation = '';
  static const String _otherLocationValue = 'Other';
  bool _otherSelected = false;
  final TextEditingController _customLocationController =
      TextEditingController();
  double? _pickedLat;
  double? _pickedLng;
  String? _previewImagePath;
  final ImagePicker _picker = ImagePicker();
  bool _boundaryDrawn = false;
  final DatabaseService _db = DatabaseService();
  final GeoFenceService _geoFence = GeoFenceService();

  static const List<String> _polomolokBarangays = <String>[
    'Poblacion (Polomolok)',
    'Cannery Site',
    'Magsaysay',
    'Bentung',
    'Crossing Palkan',
    'Glamang',
    'Kinilis',
    'Klinan 6',
    'Koronadal Proper',
    'Lam Caliaf',
    'Landan',
    'Lapu',
    'Lumakil',
    'Maligo',
    'Pagalungang',
    'Pakan',
    'Fulo',
    'Rubber',
    'Silway 7',
    'Silway 8',
    'Sulit',
    'Sumbakil',
    'Upper Klinan',
  ];

  @override
  void dispose() {
    _fieldNameController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  Future<void> _pickFieldPreview(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (photo == null || !mounted) return;
    setState(() => _previewImagePath = photo.path);
  }

  Future<void> _openMapPicker() async {
    if (!mounted) return;
    final dynamic result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => const LocationPickerScreen(),
      ),
    );
    if (result != null && result is LatLng) {
      setState(() {
        _pickedLat = result.latitude;
        _pickedLng = result.longitude;
      });
      // After pinning, take user directly to draw boundary (required).
      await _openBoundaryDrawer();
    }
  }

  Future<Land?> _findLandByName(String name) async {
    await _db.initialize();
    final List<Land> lands = await _db.getAllLands();
    final String n = name.trim().toLowerCase();
    for (final l in lands) {
      if (l.landName.trim().toLowerCase() == n) return l;
    }
    return null;
  }

  Future<void> _openBoundaryDrawer() async {
    final String name = _fieldNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter field name first')),
      );
      return;
    }
    if (_pickedLat == null || _pickedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin a location first')),
      );
      return;
    }
    final Land? existing = await _findLandByName(name);
    if (!mounted) return;
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => LandMapScreen(
          land: existing,
          initialLandName: existing == null ? name : null,
          initialCenter: LatLng(_pickedLat!, _pickedLng!),
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      setState(() => _boundaryDrawn = true);
    }
  }

  bool get _canSubmit {
    final String name = _fieldNameController.text.trim();
    return name.isNotEmpty &&
        _previewImagePath != null &&
        _previewImagePath!.isNotEmpty &&
        _pickedLat != null &&
        _pickedLng != null &&
        _boundaryDrawn;
  }

  String _effectiveAddressString() {
    final String typedOther = _customLocationController.text.trim();
    final String effectiveLocation =
        _otherSelected ? typedOther : _selectedLocation;
    if (effectiveLocation.isNotEmpty) return effectiveLocation;
    if (_pickedLat != null && _pickedLng != null) {
      return '${_pickedLat!.toStringAsFixed(4)}, ${_pickedLng!.toStringAsFixed(4)}';
    }
    return '';
  }

  Future<String?> _persistPreviewToStoredPath() async {
    String? previewPath = _previewImagePath;
    if (previewPath != null && previewPath.isNotEmpty) {
      final File f = File(previewPath);
      if (await f.exists()) {
        final List<int> bytes = await f.readAsBytes();
        previewPath = await ImageStorageService().saveDetectionImage(bytes);
      }
    }
    return previewPath;
  }

  Future<void> _autoAssignUnassignedIntoField({
    required String uid,
    required String name,
    required String newFieldId,
  }) async {
    try {
      await _db.initialize();
      final Land? land = await _db.findLandByFieldName(name);
      if (land == null || newFieldId.trim().isEmpty) return;
      final List<Map<String, dynamic>> unassigned =
          await _db.getUnassignedCapturedPhotosWithLocation(
        userId: uid,
        limit: 3000,
      );
      final List<int> idsToAssign = <int>[];
      final List<String> localPathsToAssign = <String>[];
      for (final Map<String, dynamic> r in unassigned) {
        final double? lat =
            r['latitude'] == null ? null : (r['latitude'] as num).toDouble();
        final double? lng =
            r['longitude'] == null ? null : (r['longitude'] as num).toDouble();
        if (lat == null || lng == null) continue;
        if (_geoFence.isPointInsideLand(lat, lng, land)) {
          idsToAssign.add((r['id'] as num).toInt());
          final String p = (r['local_image_path'] as String?) ?? '';
          if (p.isNotEmpty) localPathsToAssign.add(p);
        }
      }
      if (idsToAssign.isNotEmpty) {
        await _db.assignCapturedPhotosToFieldByIds(
          ids: idsToAssign,
          fieldName: name,
          fieldId: newFieldId,
        );
        await _db.assignPendingUploadsToFieldByLocalPaths(
          localImagePaths: localPathsToAssign,
          fieldId: newFieldId,
        );
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final name = _fieldNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter field name or number')),
      );
      return;
    }
    // Enforce unique field name (case-insensitive) before writing to Supabase.
    // This prevents duplicates even if the user is offline later.
    try {
      await _db.initialize();
      final String? uid =
          SupabaseClientProvider.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final List<Map<String, dynamic>> cached = await _db.getCachedFields(
          userId: uid,
          limit: 1500,
        );
        final String n = name.trim().toLowerCase();
        final bool dup = cached.any((r) {
          final String existing = (r['name'] as String?)?.trim().toLowerCase() ?? '';
          return existing.isNotEmpty && existing == n;
        });
        if (dup && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A field with this name already exists.'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
      }
    } catch (_) {
      // best-effort: do not block field creation if cache is unavailable
    }
    if (!mounted) return;
    if (_previewImagePath == null || _previewImagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a field preview photo')),
      );
      return;
    }
    if (_pickedLat == null || _pickedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin the field location on the map')),
      );
      return;
    }
    if (!_boundaryDrawn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw the field boundary before submitting')),
      );
      return;
    }
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to add a field')),
      );
      return;
    }
    try {
      final String? previewPath = await _persistPreviewToStoredPath();
      if (!mounted) return;
      final String effectiveAddress = _effectiveAddressString();

      if (!await NetworkReachability.isOnline()) {
        final String newFieldId = randomUuidV4();
        await _db.initialize();
        await _db.upsertPendingLocalField(
          id: newFieldId,
          userId: uid,
          name: name,
          address: effectiveAddress,
          previewImagePath: previewPath,
          imageCount: 0,
        );
        await _autoAssignUnassignedIntoField(
          uid: uid,
          name: name,
          newFieldId: newFieldId,
        );
        if (!mounted) return;
        final bool fil = context.read<AppState>().isFilipino;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fil
                  ? 'Naka-save nang lokal. I-sync kapag online.'
                  : 'Saved locally. Will sync when you are online.',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      if (!await ensureOnline(context)) return;
      if (!mounted) return;

      final Map<String, dynamic> inserted =
          await SupabaseClientProvider.instance.client.from('fields').insert(
            <String, dynamic>{
              'user_id': uid,
              'name': name,
              'address': effectiveAddress,
              'preview_image_path': previewPath,
            },
          ).select('id').single();

      final String newFieldId = inserted['id']?.toString() ?? '';
      await _autoAssignUnassignedIntoField(
        uid: uid,
        name: name,
        newFieldId: newFieldId,
      );

      // Persist polygon to Supabase so boundaries restore after reinstall.
      try {
        await _db.initialize();
        final Land? landRow = await _db.findLandByFieldName(name);
        final String? boundaryJson =
            _db.encodeLandBoundaryJsonForSupabase(landRow);
        if (boundaryJson != null && inserted['id'] != null) {
          await SupabaseClientProvider.instance.client
              .from('fields')
              .update(<String, dynamic>{'boundary_json': boundaryJson})
              .eq('id', inserted['id']);
        }
      } catch (_) {}

      // Best-effort: upload preview to Storage so it works across devices.
      if (previewPath != null && previewPath.isNotEmpty) {
        final File? file = await ImageStorageService().getImageFile(previewPath);
        if (file != null) {
          try {
            final String fieldId = inserted['id']?.toString() ?? '';
            final String storagePath =
                '$uid/field_previews/${fieldId.isNotEmpty ? fieldId : DateTime.now().millisecondsSinceEpoch}.jpg';
            await SupabaseClientProvider.instance.client.storage
                .from('detections')
                .upload(
                  storagePath,
                  file,
                  fileOptions: const FileOptions(
                    upsert: true,
                    contentType: 'image/jpeg',
                  ),
                );
            final String url = SupabaseClientProvider.instance.client.storage
                .from('detections')
                .getPublicUrl(storagePath);
            await SupabaseClientProvider.instance.client.from('fields').update(
              <String, dynamic>{'preview_image_path': url},
            ).eq('id', inserted['id']);
          } catch (_) {
            // keep local previewPath if upload fails
          }
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Field saved'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fil = context.watch<AppState>().isFilipino;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(fil ? 'Mga Detalye ng Bukid' : 'Farm Details'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco,
                  size: 36,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fil ? 'Pangalan/Bilang ng Bukid' : 'Field Name/Number',
              style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _fieldNameController,
              decoration: InputDecoration(
                hintText: 'Enter field name or number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              fil ? 'Preview ng Bukid' : 'Field Preview',
              style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFieldPreview(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: Text(
                      fil ? 'Kunan ang preview ng bukid' : 'Capture field preview',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickFieldPreview(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(
                      fil ? 'Pumili mula sa gallery' : 'Pick from gallery',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryGreen,
                      side: const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_previewImagePath != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_previewImagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              fil ? 'Lokasyon (Barangay)' : 'Input Location',
              style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue:
                  _selectedLocation.isEmpty ? null : _selectedLocation,
              hint: Text(fil ? 'Pumili ng barangay' : 'Select location'),
              items: _polomolokBarangays
                  .map((String location) => DropdownMenuItem<String>(
                        value: location,
                        child: Text(location),
                      ))
                  .followedBy(<DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: _otherLocationValue,
                      child: Text(fil ? 'Iba (type)' : 'Other (type)'),
                    ),
                  ])
                  .toList(),
              onChanged: (String? value) {
                final String v = value ?? '';
                setState(() {
                  if (v == _otherLocationValue) {
                    _otherSelected = true;
                    _selectedLocation = _otherLocationValue;
                    _customLocationController.clear();
                  } else {
                    _otherSelected = false;
                    _selectedLocation = v;
                    _customLocationController.clear();
                  }
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            if (_otherSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customLocationController,
                decoration: InputDecoration(
                  hintText: fil
                      ? 'I-type ang barangay / lokasyon'
                      : 'Type your barangay / location',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
                onChanged: (String value) {
                  // Keep dropdown selection as "Other"; we only store typed text on submit.
                },
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _openMapPicker,
                icon: const Icon(Icons.map),
                label: Text(
                  fil ? 'I-pin sa mapa (required)' : 'Pin in the map (required)',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryGreen,
                ),
              ),
            ),
            if (_pickedLat != null && _pickedLng != null) ...[
              const SizedBox(height: 8),
              Text(
                fil
                    ? 'Naka-pin: ${_pickedLat!.toStringAsFixed(4)}, ${_pickedLng!.toStringAsFixed(4)}'
                    : 'Pinned: ${_pickedLat!.toStringAsFixed(4)}, ${_pickedLng!.toStringAsFixed(4)}',
                style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                  fontSize: 12,
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openBoundaryDrawer,
                  icon: Icon(
                    _boundaryDrawn ? Icons.check_circle : Icons.draw_outlined,
                  ),
                  label: Text(
                    _boundaryDrawn
                        ? (fil ? 'Boundary saved' : 'Boundary saved')
                        : (fil
                            ? 'Gumuhit ng boundary (required)'
                            : 'Draw field boundary (required)'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _boundaryDrawn
                        ? AppTheme.primaryGreen
                        : AppTheme.primaryGreen,
                    side: BorderSide(
                      color: _boundaryDrawn
                          ? AppTheme.primaryGreen.withValues(alpha: 0.8)
                          : AppTheme.primaryGreen,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  fil ? 'I-save' : 'Submit',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
