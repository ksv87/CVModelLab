import 'dart:typed_data';

import '../image_source.dart';
import 'cvml_api_client.dart';

/// An [ImageSource] that fetches image bytes from a CV Model Lab server.
///
/// COCO file names are mapped to server image ids; bytes are fetched lazily and
/// never pre-loaded. Slots directly into the existing workspace screens.
class RemoteImageSource implements ImageSource {
  RemoteImageSource({
    required CvmlApiClient client,
    required String sessionId,
    required Map<String, int> imageIdByFileName,
    Iterable<String> expectedFileNames = const <String>[],
    Set<String> missingFileNames = const <String>{},
  })  : _client = client,
        _sessionId = sessionId,
        _imageIdByFileName = imageIdByFileName,
        _expectedFileNames = List<String>.unmodifiable(expectedFileNames),
        _missingFileNames = missingFileNames;

  final CvmlApiClient _client;
  final String _sessionId;
  final Map<String, int> _imageIdByFileName;
  final List<String> _expectedFileNames;
  final Set<String> _missingFileNames;

  /// Absolute URI for a thumbnail (used by the thumbnail cache layer).
  Uri? thumbnailUri(String cocoFileName, {int maxSize = 256}) {
    final int? id = _imageIdByFileName[cocoFileName];
    if (id == null) {
      return null;
    }
    return _client.resolveUri(
      '/api/sessions/$_sessionId/images/$id/thumbnail',
      query: {'max_size': '$maxSize'},
    );
  }

  @override
  ImageSource bindExpectedImages(Iterable<String> cocoFileNames) {
    return RemoteImageSource(
      client: _client,
      sessionId: _sessionId,
      imageIdByFileName: _imageIdByFileName,
      expectedFileNames: cocoFileNames,
      missingFileNames: _missingFileNames,
    );
  }

  @override
  Future<bool> exists(String cocoFileName) async {
    return _imageIdByFileName.containsKey(cocoFileName) &&
        !_missingFileNames.contains(cocoFileName);
  }

  @override
  List<String> missingImages() {
    if (_missingFileNames.isEmpty) {
      return const <String>[];
    }
    return _expectedFileNames
        .where((String name) => _missingFileNames.contains(name))
        .toList();
  }

  @override
  Future<Uint8List?> readImageBytes(String cocoFileName) async {
    final int? id = _imageIdByFileName[cocoFileName];
    if (id == null) {
      return null;
    }
    try {
      return await _client
          .getBytes('/api/sessions/$_sessionId/images/$id/bytes');
    } on RemoteApiException {
      return null;
    }
  }
}
