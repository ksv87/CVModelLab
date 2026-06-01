import 'dart:typed_data';

import 'image_file_index.dart';

abstract interface class ImageSource {
  Future<Uint8List?> readImageBytes(String cocoFileName);

  Future<bool> exists(String cocoFileName);

  List<String> missingImages();

  ImageSource bindExpectedImages(Iterable<String> cocoFileNames);
}

class EmptyImageSource implements ImageSource {
  const EmptyImageSource([this._expectedFileNames = const <String>[]]);

  final List<String> _expectedFileNames;

  @override
  ImageSource bindExpectedImages(Iterable<String> cocoFileNames) {
    return EmptyImageSource(List<String>.unmodifiable(cocoFileNames));
  }

  @override
  Future<bool> exists(String cocoFileName) async {
    return false;
  }

  @override
  List<String> missingImages() {
    return _expectedFileNames;
  }

  @override
  Future<Uint8List?> readImageBytes(String cocoFileName) async {
    return null;
  }
}

class MemoryImageSource implements ImageSource {
  MemoryImageSource({
    required ImageFileIndex<Uint8List> index,
    Iterable<String> expectedFileNames = const <String>[],
  })  : _index = index,
        _expectedFileNames = List<String>.unmodifiable(expectedFileNames);

  final ImageFileIndex<Uint8List> _index;
  final List<String> _expectedFileNames;

  @override
  ImageSource bindExpectedImages(Iterable<String> cocoFileNames) {
    return MemoryImageSource(
      index: _index,
      expectedFileNames: cocoFileNames,
    );
  }

  @override
  Future<bool> exists(String cocoFileName) async {
    return _index.exists(cocoFileName);
  }

  @override
  List<String> missingImages() {
    return _index.missingImages(_expectedFileNames);
  }

  @override
  Future<Uint8List?> readImageBytes(String cocoFileName) async {
    return _index.resolve(cocoFileName);
  }
}
