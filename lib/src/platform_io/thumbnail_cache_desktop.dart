export 'thumbnail_cache_stub.dart' show createThumbnailCache;

import 'dart:io';
import 'dart:typed_data';

import '../core/thumbnail/thumbnail_cache.dart';

ThumbnailCache createThumbnailCache() {
  return DesktopFileThumbnailCache();
}

class DesktopFileThumbnailCache implements ThumbnailCache {
  DesktopFileThumbnailCache({String? rootPath})
      : _rootPath = rootPath ?? _defaultCachePath();

  final String _rootPath;

  @override
  Future<Uint8List?> getThumbnail(String key) async {
    final File file = File(_pathForKey(key));
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  @override
  Future<void> putThumbnail(String key, Uint8List bytes) async {
    final File file = File(_pathForKey(key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<void> clearProjectCache(String projectId) async {
    final Directory dir = Directory('$_rootPath/${_safe(projectId)}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  String _pathForKey(String key) {
    final int split = key.indexOf(':');
    final String project = split == -1 ? 'global' : key.substring(0, split);
    final String rest = split == -1 ? key : key.substring(split + 1);
    return '$_rootPath/${_safe(project)}/${_safe(rest)}.thumb';
  }
}

String _safe(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_');
}

String _defaultCachePath() {
  final Map<String, String> env = Platform.environment;
  if (Platform.isMacOS) {
    return '${env['HOME'] ?? '.'}/Library/Caches/CV Model Lab/thumbnails';
  }
  if (Platform.isWindows) {
    return '${env['LOCALAPPDATA'] ?? env['APPDATA'] ?? '.'}\\CV Model Lab\\thumbnails';
  }
  return '${env['XDG_CACHE_HOME'] ?? '${env['HOME'] ?? '.'}/.cache'}/cv_model_lab/thumbnails';
}
