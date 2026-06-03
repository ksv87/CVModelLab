import 'dart:typed_data';

import '../task/long_running_task.dart';

abstract interface class ThumbnailCache {
  Future<Uint8List?> getThumbnail(String key);

  Future<void> putThumbnail(String key, Uint8List bytes);

  Future<void> clearProjectCache(String projectId);
}

class MemoryThumbnailCache implements ThumbnailCache {
  final Map<String, Uint8List> _items = <String, Uint8List>{};

  @override
  Future<Uint8List?> getThumbnail(String key) async => _items[key];

  @override
  Future<void> putThumbnail(String key, Uint8List bytes) async {
    _items[key] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> clearProjectCache(String projectId) async {
    final String prefix = '$projectId:';
    _items.removeWhere((String key, _) => key.startsWith(prefix));
  }
}

String stableThumbnailKey({
  required String projectId,
  required int imageId,
  required String fileName,
  required int maxSize,
  String? fingerprint,
}) {
  final String normalized = fileName.replaceAll('\\', '/');
  final String suffix =
      fingerprint == null || fingerprint.isEmpty ? '' : ':$fingerprint';
  return '$projectId:$imageId:$maxSize:$normalized$suffix';
}

class ThumbnailService {
  const ThumbnailService({required ThumbnailCache cache}) : _cache = cache;

  final ThumbnailCache _cache;

  Future<Uint8List?> getOrCreateThumbnail({
    required String projectId,
    required int imageId,
    required String fileName,
    required Future<Uint8List?> Function() loadImageBytes,
    required int maxSize,
    String? fingerprint,
    CancellationToken? cancellationToken,
  }) async {
    final String key = stableThumbnailKey(
      projectId: projectId,
      imageId: imageId,
      fileName: fileName,
      maxSize: maxSize,
      fingerprint: fingerprint,
    );
    cancellationToken?.throwIfCancelled();
    final Uint8List? cached = await _cache.getThumbnail(key);
    if (cached != null) {
      return cached;
    }
    cancellationToken?.throwIfCancelled();
    final Uint8List? bytes = await loadImageBytes();
    cancellationToken?.throwIfCancelled();
    if (bytes == null) {
      return null;
    }
    // Flutter decodes the bytes in the widget. The cache still avoids repeated
    // file reads and gives desktop implementations a stable place to store
    // generated thumbnails later.
    await _cache.putThumbnail(key, bytes);
    return bytes;
  }
}
