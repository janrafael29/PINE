// User profile: Supabase `profiles` + Storage avatars bucket.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth_display_message.dart';
import '../core/supabase_client.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/online_required_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _profileImageUrl;
  bool _loading = true;
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final User? user =
        SupabaseClientProvider.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    _phoneController.text = user.phone ?? '';
    _emailController.text = user.email ?? '';
    _usernameController.text = user.phone ?? 'User';
    try {
      final Map<String, dynamic>? row = await SupabaseClientProvider
          .instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        _usernameController.text =
            row['display_name'] as String? ?? _usernameController.text;
        _emailController.text =
            row['email'] as String? ?? _emailController.text;
        _phoneController.text = row['phone'] as String? ?? _phoneController.text;
        if (mounted) {
          setState(() {
            _profileImageUrl = row['photo_url'] as String?;
            _loading = false;
          });
        }
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_savingPhoto) return;
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    if (!await ensureOnline(context)) return;
    if (!mounted) return;
    setState(() => _savingPhoto = true);
    try {
      final String? uid =
          SupabaseClientProvider.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final File file = File(picked.path);
      const String path = 'avatar.jpg';
      final String storagePath = '$uid/$path';
      await SupabaseClientProvider.instance.client.storage
          .from('avatars')
          .upload(
            storagePath,
            file,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final String url = SupabaseClientProvider.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      final String displayUrl =
          '$url?t=${DateTime.now().millisecondsSinceEpoch}';

      await SupabaseClientProvider.instance.client.from('profiles').upsert(
        <String, dynamic>{
          'id': uid,
          'photo_url': displayUrl,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );
      if (mounted) {
        setState(() {
          _profileImageUrl = displayUrl;
          _savingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update photo: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final User? user =
        SupabaseClientProvider.instance.client.auth.currentUser;
    if (user == null) return;
    if (!await ensureOnline(context)) return;
    if (!mounted) return;

    final String newEmail = _emailController.text.trim().toLowerCase();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a valid email address.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final String currentEmail = (user.email ?? '').trim().toLowerCase();
    final bool emailChanged = newEmail != currentEmail;

    try {
      if (emailChanged) {
        await SupabaseClientProvider.instance.client.auth.updateUser(
          UserAttributes(email: newEmail),
        );
      }

      final User? refreshed =
          SupabaseClientProvider.instance.client.auth.currentUser;
      final String emailForProfile = refreshed?.email ?? newEmail;

      await SupabaseClientProvider.instance.client.from('profiles').upsert(
        <String, dynamic>{
          'id': user.id,
          'display_name': _usernameController.text.trim(),
          'email': emailForProfile,
          'phone': _phoneController.text.trim().isEmpty
              ? (refreshed?.phone ?? user.phone)
              : _phoneController.text.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'id',
      );

      if (mounted) {
        _emailController.text = refreshed?.email ?? emailForProfile;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emailChanged
                  ? 'Profile updated. Confirm the new email if you get a message from the app.'
                  : 'Profile updated successfully',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authErrorMessageForUser(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _openPhotoViewer() {
    final String? url = _profileImageUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ProfilePhotoViewerScreen(imageUrl: url),
      ),
    );
  }

  Future<void> _showPhotoActions() async {
    if (_savingPhoto) return;
    final bool hasPhoto =
        _profileImageUrl != null && _profileImageUrl!.isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View photo'),
                enabled: hasPhoto,
                onTap: hasPhoto
                    ? () {
                        Navigator.pop(context);
                        _openPhotoViewer();
                      }
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo (camera)'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        title: 'Profile',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final User? authUser =
        SupabaseClientProvider.instance.client.auth.currentUser;
    final String displayName = _usernameController.text.isNotEmpty
        ? _usernameController.text
        : 'Profile';
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AppScaffold(
      title: displayName,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Center(
              child: GestureDetector(
                onTap: _savingPhoto ? null : _showPhotoActions,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 4,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _profileImageUrl != null &&
                                  _profileImageUrl!.isNotEmpty
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          backgroundColor: cs.primary,
                          child: _profileImageUrl == null ||
                                  _profileImageUrl!.isEmpty
                              ? Text(
                                  _usernameController.text.isNotEmpty
                                      ? _usernameController.text[0].toUpperCase()
                                      : (authUser?.phone?.isNotEmpty == true
                                          ? authUser!.phone![0]
                                          : 'U'),
                                  style: TextStyle(
                                    fontSize: 42,
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (_savingPhoto)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: 22,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildLabel('Display name'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Email'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(
                            Icons.email,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Phone number'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Icon(
                            Icons.phone,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You sign in with your email and password. Changing email may require '
                        'confirming a link sent to your new (or old) address, depending on project settings. '
                        'Optional phone is for your profile only.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          child: const Text(
                            'Update',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ProfilePhotoViewerScreen extends StatelessWidget {
  const _ProfilePhotoViewerScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Profile photo'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.6,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Failed to load photo.'),
              );
            },
          ),
        ),
      ),
    );
  }
}
