export 'project_file_io_stub.dart' show ProjectFileIo;

import 'dart:async';
import 'dart:convert';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_pick_result.dart';
import 'image_source.dart';
import 'project_file_io_stub.dart';

ProjectFileIo createProjectFileIo() => const WebProjectFileIo();

class WebProjectFileIo implements ProjectFileIo {
  const WebProjectFileIo();

  @override
  Future<PickedDataFile?> openProject() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'application/json,.json';
    input.click();
    await input.onChange.first;
    final html.File? file =
        input.files?.isEmpty ?? true ? null : input.files!.first;
    if (file == null) {
      return null;
    }
    final Uint8List bytes = await _readFileAsBytes(file);
    return PickedDataFile(name: file.name, bytes: bytes);
  }

  @override
  Future<String?> saveProjectAs(
    String jsonContent,
    String suggestedName,
  ) async {
    final List<int> bytes = utf8.encode(jsonContent);
    final html.Blob blob =
        html.Blob(<Uint8List>[Uint8List.fromList(bytes)], 'application/json');
    final String url = html.Url.createObjectUrlFromBlob(blob);
    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..download = suggestedName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    // On web we can't get the real save path; return the suggested name.
    return suggestedName;
  }

  @override
  Future<bool> saveProjectToPath(String path, String jsonContent) async {
    // On web there is no concept of a persistent local path.
    return false;
  }

  @override
  Future<PickedDataFile?> readFileAtPath(String path) async => null;

  @override
  Future<ImageSource?> openImageSourceAtPath(String path) async => null;
}

Future<Uint8List> _readFileAsBytes(html.File file) {
  final Completer<Uint8List> completer = Completer<Uint8List>();
  final html.FileReader reader = html.FileReader();
  reader.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(StateError('Could not read ${file.name}.'));
    }
  });
  reader.onLoad.first.then((_) {
    final Object? result = reader.result;
    if (result is String) {
      completer.complete(UriData.parse(result).contentAsBytes());
    } else {
      completer.completeError(StateError('Could not read ${file.name}.'));
    }
  });
  reader.readAsDataUrl(file);
  return completer.future;
}
