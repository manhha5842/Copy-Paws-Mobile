import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Service for storing and managing clipboard images
class ImageStorageService {
  ImageStorageService._();
  static final ImageStorageService instance = ImageStorageService._();

  // Image cache directory
  Directory? _imageDir;
  bool _initialized = false;

  // Configuration
  static const int maxCachedImages = 50;
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB

  /// Initialize service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _imageDir = Directory('${appDir.path}/clipboard_images');

      if (!await _imageDir!.exists()) {
        await _imageDir!.create(recursive: true);
        AppLogger.info('Created image cache directory');
      }

      _initialized = true;
      AppLogger.info('ImageStorageService initialized');
    } catch (e, stack) {
      AppLogger.error(
        'Failed to initialize ImageStorageService',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Save image from base64 data
  /// Returns local file path if successful
  Future<String?> saveImageFromBase64({
    required String base64Data,
    required String clipId,
    String? mimeType,
  }) async {
    if (!_initialized) await initialize();

    try {
      final bytes = base64Decode(base64Data);

      // Validate size
      if (bytes.length > maxImageSizeBytes) {
        AppLogger.warning(
          'Image too large: ${bytes.length} bytes > $maxImageSizeBytes',
        );
        return null;
      }

      // Determine file extension from mime type
      String extension = 'png';
      if (mimeType != null) {
        if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
          extension = 'jpg';
        } else if (mimeType.contains('gif')) {
          extension = 'gif';
        } else if (mimeType.contains('webp')) {
          extension = 'webp';
        }
      }

      final filename =
          '${clipId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${_imageDir!.path}/$filename');

      await file.writeAsBytes(bytes);
      AppLogger.info('Saved image: $filename (${bytes.length} bytes)');

      // Clean up old images if necessary
      await _cleanupOldImages();

      return file.path;
    } catch (e, stack) {
      AppLogger.error('Failed to save image', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Save image from bytes
  Future<String?> saveImageFromBytes({
    required Uint8List bytes,
    required String clipId,
    String? mimeType,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Validate size
      if (bytes.length > maxImageSizeBytes) {
        AppLogger.warning(
          'Image too large: ${bytes.length} bytes > $maxImageSizeBytes',
        );
        return null;
      }

      // Determine file extension
      String extension = 'png';
      if (mimeType != null) {
        if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
          extension = 'jpg';
        } else if (mimeType.contains('gif')) {
          extension = 'gif';
        } else if (mimeType.contains('webp')) {
          extension = 'webp';
        }
      }

      final filename =
          '${clipId}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final file = File('${_imageDir!.path}/$filename');

      await file.writeAsBytes(bytes);
      AppLogger.info('Saved image: $filename (${bytes.length} bytes)');

      // Clean up old images if necessary
      await _cleanupOldImages();

      return file.path;
    } catch (e, stack) {
      AppLogger.error(
        'Failed to save image from bytes',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  /// Load image as bytes from local path
  Future<Uint8List?> loadImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      AppLogger.warning('Image not found: $path');
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to load image', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Load image as base64 from local path
  Future<String?> loadImageAsBase64(String path) async {
    final bytes = await loadImage(path);
    if (bytes != null) {
      return base64Encode(bytes);
    }
    return null;
  }

  /// Delete image by path
  Future<bool> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        AppLogger.info('Deleted image: $path');
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('Failed to delete image', error: e);
      return false;
    }
  }

  /// Delete image by clip ID
  Future<void> deleteImagesByClipId(String clipId) async {
    if (!_initialized) return;

    try {
      final files = await _imageDir!.list().toList();
      for (final entity in files) {
        if (entity is File && entity.path.contains(clipId)) {
          await entity.delete();
          AppLogger.debug('Deleted image for clip: $clipId');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to delete images for clip', error: e);
    }
  }

  /// Get all cached images
  Future<List<File>> getCachedImages() async {
    if (!_initialized) await initialize();

    try {
      final files = await _imageDir!.list().toList();
      return files.whereType<File>().toList()..sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
    } catch (e) {
      AppLogger.error('Failed to list cached images', error: e);
      return [];
    }
  }

  /// Get total cache size
  Future<int> getCacheSize() async {
    if (!_initialized) return 0;

    try {
      int totalSize = 0;
      final files = await _imageDir!.list().toList();
      for (final entity in files) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    if (!_initialized) return;

    try {
      final files = await _imageDir!.list().toList();
      for (final entity in files) {
        if (entity is File) {
          await entity.delete();
        }
      }
      AppLogger.info('Cleared image cache');
    } catch (e) {
      AppLogger.error('Failed to clear image cache', error: e);
    }
  }

  /// Clean up old images to keep cache size manageable
  Future<void> _cleanupOldImages() async {
    try {
      final files = await getCachedImages();
      if (files.length > maxCachedImages) {
        // Delete oldest files
        final toDelete = files.skip(maxCachedImages);
        for (final file in toDelete) {
          await file.delete();
          AppLogger.debug('Cleaned up old image: ${file.path}');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to cleanup old images', error: e);
    }
  }

  /// Check if image exists
  Future<bool> imageExists(String path) async {
    return await File(path).exists();
  }

  /// Get MIME type from file extension
  String getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'png':
      default:
        return 'image/png';
    }
  }
}
