import 'dart:typed_data';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stable thumbnail key includes project, image, size, and file', () {
    expect(
      stableThumbnailKey(
        projectId: 'p',
        imageId: 7,
        fileName: r'nested\image.jpg',
        maxSize: 96,
        fingerprint: 'mtime-size',
      ),
      'p:7:96:nested/image.jpg:mtime-size',
    );
  });

  test('memory thumbnail cache put, get, and clear project cache', () async {
    final cache = MemoryThumbnailCache();
    await cache.putThumbnail('p:1:a', Uint8List.fromList([1, 2, 3]));
    await cache.putThumbnail('other:1:a', Uint8List.fromList([4]));

    expect(await cache.getThumbnail('p:1:a'), [1, 2, 3]);
    await cache.clearProjectCache('p');
    expect(await cache.getThumbnail('p:1:a'), isNull);
    expect(await cache.getThumbnail('other:1:a'), [4]);
  });

  test('thumbnail service does not corrupt cache after cancellation', () async {
    final cache = MemoryThumbnailCache();
    final service = ThumbnailService(cache: cache);
    final token = CancellationToken()..cancel();

    expect(
      () => service.getOrCreateThumbnail(
        projectId: 'p',
        imageId: 1,
        fileName: 'a.jpg',
        loadImageBytes: () async => Uint8List.fromList([1]),
        maxSize: 96,
        cancellationToken: token,
      ),
      throwsA(isA<TaskCancelledException>()),
    );
    expect(await cache.getThumbnail('p:1:96:a.jpg'), isNull);
  });
}
