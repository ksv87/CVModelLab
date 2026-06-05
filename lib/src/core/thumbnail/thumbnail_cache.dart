import 'dart:typed_data';

import '../task/long_running_task.dart';

abstract interface class ThumbnailCache {
  Future<Uint8List?> getThumbnail(String key);

  /// Returns cached bytes synchronously when they are already in memory, or
  /// `null` if a read would have to hit slower storage. Lets the UI render a
  /// cached thumbnail in the same frame instead of flashing a placeholder while
  /// an async lookup resolves (important for smooth scrolling).
  Uint8List? peekThumbnail(String key);

  Future<void> putThumbnail(String key, Uint8List bytes);

  Future<void> clearProjectCache(String projectId);
}

/// In-memory thumbnail cache with an approximate byte budget and LRU eviction,
/// so scrolling a large dataset cannot grow memory without bound.
class MemoryThumbnailCache implements ThumbnailCache {
  MemoryThumbnailCache({int maxBytes = 64 * 1024 * 1024}) : _maxBytes = maxBytes;

  final int _maxBytes;
  // A plain map preserves insertion order, which we use for LRU: the first key
  // is the least-recently-used entry.
  final Map<String, Uint8List> _items = <String, Uint8List>{};
  int _bytesInUse = 0;

  @override
  Uint8List? peekThumbnail(String key) {
    final Uint8List? bytes = _items.remove(key);
    if (bytes == null) {
      return null;
    }
    _items[key] = bytes; // Re-insert to mark as most-recently-used.
    return bytes;
  }

  @override
  Future<Uint8List?> getThumbnail(String key) async => peekThumbnail(key);

  @override
  Future<void> putThumbnail(String key, Uint8List bytes) async {
    final Uint8List copy = Uint8List.fromList(bytes);
    final Uint8List? previous = _items.remove(key);
    if (previous != null) {
      _bytesInUse -= previous.length;
    }
    _items[key] = copy;
    _bytesInUse += copy.length;
    while (_bytesInUse > _maxBytes && _items.length > 1) {
      final String oldest = _items.keys.first;
      final Uint8List removed = _items.remove(oldest)!;
      _bytesInUse -= removed.length;
    }
  }

  @override
  Future<void> clearProjectCache(String projectId) async {
    final String prefix = '$projectId:';
    _items.removeWhere((String key, Uint8List bytes) {
      final bool match = key.startsWith(prefix);
      if (match) {
        _bytesInUse -= bytes.length;
      }
      return match;
    });
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

  /// Synchronous, in-memory lookup of an already-cached thumbnail. Returns
  /// `null` when nothing is cached in memory (the caller should then fall back
  /// to [getOrCreateThumbnail]).
  Uint8List? peekThumbnail({
    required String projectId,
    required int imageId,
    required String fileName,
    required int maxSize,
    String? fingerprint,
  }) {
    return _cache.peekThumbnail(
      stableThumbnailKey(
        projectId: projectId,
        imageId: imageId,
        fileName: fileName,
        maxSize: maxSize,
        fingerprint: fingerprint,
      ),
    );
  }

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
