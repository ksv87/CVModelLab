export 'thumbnail_cache_stub.dart' show createThumbnailCache;

import 'dart:io';
import 'dart:typed_data';

import '../core/thumbnail/thumbnail_cache.dart';

ThumbnailCache createThumbnailCache() {
  return DesktopFileThumbnailCache();
}

class DesktopFileThumbnailCache implements ThumbnailCache {
  DesktopFileThumbnailCache({String? rootPath, int hotMaxBytes = 64 * 1024 * 1024})
      : _rootPath = rootPath ?? _defaultCachePath(),
        _hotMaxBytes = hotMaxBytes;

  final String _rootPath;

  // A small in-memory hot layer keeps recently used thumbnails ready for a
  // synchronous peek and avoids re-reading them from disk while scrolling.
  final int _hotMaxBytes;
  final Map<String, Uint8List> _hot = <String, Uint8List>{};
  int _hotBytes = 0;

  @override
  Uint8List? peekThumbnail(String key) {
    final Uint8List? bytes = _hot.remove(key);
    if (bytes == null) {
      return null;
    }
    _hot[key] = bytes; // Mark as most-recently-used.
    return bytes;
  }

  @override
  Future<Uint8List?> getThumbnail(String key) async {
    final Uint8List? hot = peekThumbnail(key);
    if (hot != null) {
      return hot;
    }
    final File file = File(_pathForKey(key));
    if (!await file.exists()) {
      return null;
    }
    final Uint8List bytes = await file.readAsBytes();
    _remember(key, bytes);
    return bytes;
  }

  @override
  Future<void> putThumbnail(String key, Uint8List bytes) async {
    final File file = File(_pathForKey(key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    _remember(key, Uint8List.fromList(bytes));
  }

  @override
  Future<void> clearProjectCache(String projectId) async {
    final String prefix = '$projectId:';
    _hot.removeWhere((String key, Uint8List bytes) {
      final bool match = key.startsWith(prefix);
      if (match) {
        _hotBytes -= bytes.length;
      }
      return match;
    });
    final Directory dir = Directory('$_rootPath/${_safe(projectId)}');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  void _remember(String key, Uint8List bytes) {
    final Uint8List? previous = _hot.remove(key);
    if (previous != null) {
      _hotBytes -= previous.length;
    }
    _hot[key] = bytes;
    _hotBytes += bytes.length;
    while (_hotBytes > _hotMaxBytes && _hot.length > 1) {
      final String oldest = _hot.keys.first;
      final Uint8List removed = _hot.remove(oldest)!;
      _hotBytes -= removed.length;
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
