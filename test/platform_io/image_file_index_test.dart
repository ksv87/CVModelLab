import 'dart:typed_data';

import 'package:cv_model_lab/src/platform_io/image_file_index.dart';
import 'package:cv_model_lab/src/platform_io/image_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves image files by exact relative path and basename fallback',
      () async {
    final ImageFileIndex<String> index = ImageFileIndex<String>(const [
      ImageFileEntry<String>(
        relativePath: 'val2017/image_001.jpg',
        value: 'exact',
      ),
      ImageFileEntry<String>(relativePath: 'image_002.jpg', value: 'basename'),
    ]);

    expect(index.resolve('val2017/image_001.jpg'), 'exact');
    expect(index.resolve('nested/image_002.jpg'), 'basename');
  });

  test('does not resolve ambiguous basename fallback', () {
    final ImageFileIndex<String> index = ImageFileIndex<String>(const [
      ImageFileEntry<String>(relativePath: 'a/image_001.jpg', value: 'a'),
      ImageFileEntry<String>(relativePath: 'b/image_001.jpg', value: 'b'),
    ]);

    expect(index.resolve('nested/image_001.jpg'), isNull);
    expect(index.resolve('a/image_001.jpg'), 'a');
    expect(index.ambiguityWarnings(['nested/image_001.jpg']), hasLength(1));
  });

  test('detects missing expected images', () async {
    final MemoryImageSource source = MemoryImageSource(
      index: ImageFileIndex<Uint8List>([
        ImageFileEntry<Uint8List>(
          relativePath: 'image_001.jpg',
          value: Uint8List.fromList([1, 2, 3]),
        ),
      ]),
    ).bindExpectedImages([
      'image_001.jpg',
      'nested/image_002.jpg',
    ]) as MemoryImageSource;

    expect(await source.exists('image_001.jpg'), isTrue);
    expect(await source.exists('nested/image_002.jpg'), isFalse);
    expect(source.missingImages(), ['nested/image_002.jpg']);
    expect(await source.readImageBytes('other/image_001.jpg'), [1, 2, 3]);
  });

  test('resolves image files by unique suffix path', () {
    final ImageFileIndex<String> index = ImageFileIndex<String>(const [
      ImageFileEntry<String>(
        relativePath: 'selected/images/val/00.00.00.jpg',
        value: 'file',
      ),
    ]);

    expect(index.resolve('val/00.00.00.jpg'), 'file');
    expect(index.missingImages(['val/00.00.00.jpg']), isEmpty);
  });

  test('does not resolve ambiguous suffix path', () {
    final ImageFileIndex<String> index = ImageFileIndex<String>(const [
      ImageFileEntry<String>(relativePath: 'a/val/00.00.00.jpg', value: 'a'),
      ImageFileEntry<String>(relativePath: 'b/val/00.00.00.jpg', value: 'b'),
    ]);

    expect(index.resolve('val/00.00.00.jpg'), isNull);
    expect(index.ambiguityWarnings(['val/00.00.00.jpg']), hasLength(1));
  });
}
