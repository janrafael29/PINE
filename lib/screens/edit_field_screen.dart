// Edit an existing field (name / preview image).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/admin_session.dart';
import '../core/supabase_client.dart';
import '../core/theme.dart';
import '../models/land.dart';
import '../services/database_service.dart';
import '../services/image_storage_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';
import 'land_map_screen.dart';

class EditFieldScreen extends StatefulWidget {
  const EditFieldScreen({super.key, required this.fieldId});

  final String fieldId;

  @override
  State<EditFieldScreen> createState() => _EditFieldScreenState();
}

class _EditFieldScreenState extends State<EditFieldScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final DatabaseService _db = DatabaseService();

  String? _address;
  String? _previewImagePath;
  /// Row owner in Supabase; never replaced with the signed-in admin on save.
  String? _fieldOwnerUserId;
  /// Supabase name at load; used to find local geo-fence row and after rename.
  String _initialFieldName = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final Map<String, dynamic>? data = await SupabaseClientProvider
          .instance.client
          .from('fields')
          .select()
          .eq('id', widget.fieldId)
          .maybeSingle();

      if (data == null) {
        setState(() {
          _error = 'Field not found';
          _loading = false;
        });
        return;
      }

      final String? rowOwner = (data['user_id'] as String?)?.trim();
      if (rowOwner != null &&
          rowOwner.isNotEmpty &&
          rowOwner != uid &&
          !currentUserJwtAdmin()) {
        setState(() {
          _error = 'You do not have access to edit this field';
          _loading = false;
        });
        return;
      }

      setState(() {
        _fieldOwnerUserId = rowOwner?.isNotEmpty == true ? rowOwner : uid;
        _nameController.text = (data['name'] as String?) ?? '';
        _initialFieldName = _nameController.text.trim();
        _address = data['address'] as String?;
        _previewImagePath = data['preview_image_path'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load field: $e';
        _loading = false;
      });
    }
  }

  Future<void> _capturePreview() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo == null || !mounted) return;
    setState(() => _previewImagePath = photo.path);
  }

  Future<void> _openUpdateGeoFence() async {
    await _db.initialize();
    final String typed = _nameController.text.trim();
    final String loaded = _initialFieldName.trim();
    final String label = typed.isNotEmpty ? typed : loaded;
    Land? land = typed.isNotEmpty ? await _db.findLandByFieldName(typed) : null;
    if (land == null && loaded.isNotEmpty && loaded.toLowerCase() != typed.toLowerCase()) {
      land = await _db.findLandByFieldName(loaded);
    }
    if (!mounted) return;
    const LatLng defaultCenter = LatLng(6.2167, 125.0667);
    final LatLng center = land != null && land.polygonCoordinates.isNotEmpty
        ? LatLng(
            land.polygonCoordinates.first.latitude,
            land.polygonCoordinates.first.longitude,
          )
        : defaultCenter;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => LandMapScreen(
          land: land,
          initialLandName: land == null && label.isNotEmpty ? label : null,
          initialCenter: center,
          supabaseFieldId: widget.fieldId,
        ),
      ),
    );
  }

  Future<void> _pickGalleryPreview() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo == null || !mounted) return;
    setState(() => _previewImagePath = photo.path);
  }

  Future<void> _save() async {
    if (_saving) return;
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter field name/number')),
      );
      return;
    }

    final String? uid =
        SupabaseClientProvider.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final String ownerId = _fieldOwnerUserId ?? uid;

    try {
      String? previewPath = _previewImagePath;
      // If user picked a new preview from camera/gallery, persist it to app storage.
      if (previewPath != null && previewPath.isNotEmpty) {
        final File f = File(previewPath);
        if (await f.exists()) {
          final List<int> bytes = await f.readAsBytes();
          previewPath = await ImageStorageService().saveDetectionImage(bytes);
        }
      }
      // Best-effort: upload preview to Storage so it works across devices.
      if (previewPath != null && previewPath.isNotEmpty) {
        final File? file = await ImageStorageService().getImageFile(previewPath);
        if (file != null) {
          try {
            if (ownerId.isNotEmpty) {
              final String storagePath =
                  '$ownerId/field_previews/${widget.fieldId}.jpg';
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
              previewPath = url;
            }
          } catch (_) {
            // keep local previewPath if upload fails
          }
        }
      }
      await _db.initialize();
      Land? landForBoundary =
          await _db.findLandByFieldName(_initialFieldName);
      landForBoundary ??= await _db.findLandByFieldName(name);
      final String? boundaryJson =
          _db.encodeLandBoundaryJsonForSupabase(landForBoundary);

      await SupabaseClientProvider.instance.client
          .from('fields')
          .update(<String, dynamic>{
        'name': name,
        'address': _address ?? '',
        'preview_image_path': previewPath,
        'user_id': ownerId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (boundaryJson != null) 'boundary_json': boundaryJson,
      }).eq('id', widget.fieldId);

      await _db.renameLandMatchingFieldName(
        fromName: _initialFieldName,
        toName: name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Field updated'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to save field: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to save field: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppScaffold(
      title: 'Edit Field',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Field Name/Number',
                          style: (textTheme.bodyMedium ?? const TextStyle())
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Enter field name or number',
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Field Preview',
                          style: (textTheme.bodyMedium ?? const TextStyle())
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _capturePreview,
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Capture field preview'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                  side: const BorderSide(
                                      color: AppTheme.primaryGreen),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickGalleryPreview,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text(
                                  'Pick from gallery',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryGreen,
                                  side: const BorderSide(
                                      color: AppTheme.primaryGreen),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_previewImagePath != null &&
                            File(_previewImagePath!).existsSync()) ...[
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
                        ] else if (_previewImagePath != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'No preview image saved yet on this device.',
                            style: TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Field boundary',
                          style: (textTheme.bodyMedium ?? const TextStyle())
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _openUpdateGeoFence,
                            icon: const Icon(Icons.draw_outlined),
                            label: const Text('Update geo-fence on map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryGreen,
                              side: const BorderSide(color: AppTheme.primaryGreen),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _saving ? 'Saving...' : 'Save Changes',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
