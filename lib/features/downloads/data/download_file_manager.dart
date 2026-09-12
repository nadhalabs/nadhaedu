import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class DownloadFileManager {
  Future<String> getRootDirectory();
  Future<String> resolveAbsolutePath(String relativePath);
  Future<bool> fileExists(String relativePath);
  Future<int> getFileSize(String relativePath);
  Future<String> computeSha256(String relativePath);
  Future<void> deleteFile(String relativePath);
  Future<void> deleteDirectory(String relativePath);
  Future<int> getAvailableDiskSpace();
  Future<void> ensureDirectoryExists(String directoryPath);
}

final class PlatformDownloadFileManager implements DownloadFileManager {
  PlatformDownloadFileManager({String? customRootPath})
    : _customRootPath = customRootPath;

  final String? _customRootPath;
  String? _cachedRoot;
  static const _storageChannel = MethodChannel('com.learningplatform/storage');

  @override
  Future<String> getRootDirectory() async {
    if (_customRootPath != null) return _customRootPath;
    if (_cachedRoot != null) return _cachedRoot!;
    try {
      final base = await getApplicationSupportDirectory();
      final downloadsDir = Directory(p.join(base.path, 'downloads', 'secure'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      _cachedRoot = downloadsDir.path;
      return _cachedRoot!;
    } on Object catch (_) {
      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(
        p.join(docDir.path, 'downloads', 'secure'),
      );
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      _cachedRoot = downloadsDir.path;
      return _cachedRoot!;
    }
  }

  @override
  Future<String> resolveAbsolutePath(String relativePath) async {
    final root = await getRootDirectory();
    // Prevent directory traversal
    final normalized = p.normalize(relativePath);
    if (normalized.startsWith('..') || p.isAbsolute(normalized)) {
      throw ArgumentError('Invalid relative path: $relativePath');
    }
    return p.join(root, normalized);
  }

  @override
  Future<bool> fileExists(String relativePath) async {
    try {
      final fullPath = await resolveAbsolutePath(relativePath);
      return await File(fullPath).exists();
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<int> getFileSize(String relativePath) async {
    try {
      final fullPath = await resolveAbsolutePath(relativePath);
      final file = File(fullPath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } on Object catch (_) {
      return 0;
    }
  }

  @override
  Future<String> computeSha256(String relativePath) async {
    final fullPath = await resolveAbsolutePath(relativePath);
    final file = File(fullPath);
    if (!await file.exists()) {
      throw StateError('File not found: $fullPath');
    }
    final stream = file.openRead();
    final digest = await sha256.bind(stream).first;
    return digest.toString();
  }

  @override
  Future<void> deleteFile(String relativePath) async {
    try {
      final fullPath = await resolveAbsolutePath(relativePath);
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
      }
    } on Object catch (_) {
      // Ignore file deletion errors
    }
  }

  @override
  Future<void> deleteDirectory(String relativePath) async {
    try {
      final fullPath = await resolveAbsolutePath(relativePath);
      final dir = Directory(fullPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on Object catch (_) {
      // Ignore deletion errors
    }
  }

  @override
  Future<int> getAvailableDiskSpace() async {
    final bytes = await _storageChannel.invokeMethod<int>('getAvailableBytes');
    if (bytes == null || bytes < 0) {
      throw StateError('Platform did not return valid available disk space.');
    }
    return bytes;
  }

  @override
  Future<void> ensureDirectoryExists(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
