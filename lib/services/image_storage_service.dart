/// Local image storage for detection photos.
///
/// Saves captured images to app documents and returns path for DB.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Service for persisting detection images locally.
class ImageStorageService {
  static const _detectionsDir = 'detections';

  /// Saves [imageBytes] (JPEG) and returns the relative path for DB storage.
  Future<String> saveDetectionImage(List<int> imageBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final detectionsDir = Directory('${dir.path}/$_detectionsDir');
    if (!await detectionsDir.exists()) {
      await detectionsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'detection_$timestamp.jpg';
    final file = File('${detectionsDir.path}/$filename');
    await file.writeAsBytes(imageBytes);

    // Store relative path for portability
    return '$_detectionsDir/$filename';
  }

  /// Resolves stored path to full file path for loading.
  Future<File?> getImageFile(String relativePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$relativePath');
    if (await file.exists()) return file;
    return null;
  }
}
