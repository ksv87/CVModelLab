export 'platform_file_picker_stub.dart' show PlatformFilePicker;
import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_pick_result.dart';
import 'image_file_index.dart';
import 'image_source.dart';
import 'platform_file_picker_stub.dart';

PlatformFilePicker createPlatformFilePicker() {
  return const WebPlatformFilePicker();
}

class WebPlatformFilePicker implements PlatformFilePicker {
  const WebPlatformFilePicker();

  @override
  Future<PickedDataFile?> pickAnnotationsJson({String? initialDirectory}) {
    return _pickJsonFile();
  }

  @override
  Future<PickedDataFile?> pickPredictionsJson({String? initialDirectory}) {
    return _pickJsonFile();
  }

  @override
  Future<PickedDataFile?> pickApMetricsJson({String? initialDirectory}) {
    return _pickJsonFile();
  }

  @override
  Future<ImageSource?> pickImages({String? initialDirectory}) async {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = true;
    input.setAttribute('webkitdirectory', '');
    input.setAttribute('directory', '');
    final List<html.File> files = await _pickFiles(input);
    if (files.isEmpty) {
      return null;
    }
    return WebSelectedFilesImageSource(files: files);
  }

  Future<PickedDataFile?> _pickJsonFile() async {
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = 'application/json,.json';
    final List<html.File> files = await _pickFiles(input);
    final html.File? file = files.isEmpty ? null : files.first;
    if (file == null) {
      return null;
    }
    return PickedDataFile(
      name: file.name,
      bytes: await _readFileAsBytes(file),
    );
  }
}

class WebSelectedFilesImageSource implements ImageSource {
  WebSelectedFilesImageSource({
    required Iterable<html.File> files,
    Iterable<String> expectedFileNames = const <String>[],
  })  : _files = List<html.File>.unmodifiable(files),
        _expectedFileNames = List<String>.unmodifiable(expectedFileNames) {
    _index = ImageFileIndex<html.File>(
      _files.map((html.File file) {
        return ImageFileEntry<html.File>(
          relativePath: _relativePath(file),
          value: file,
        );
      }),
    );
  }

  final List<html.File> _files;
  final List<String> _expectedFileNames;
  late final ImageFileIndex<html.File> _index;

  @override
  ImageSource bindExpectedImages(Iterable<String> cocoFileNames) {
    return WebSelectedFilesImageSource(
      files: _files,
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
    final html.File? file = _index.resolve(cocoFileName);
    if (file == null) {
      return null;
    }
    return _readFileAsBytes(file);
  }
}

Future<List<html.File>> _pickFiles(html.FileUploadInputElement input) async {
  final Completer<List<html.File>> completer = Completer<List<html.File>>();
  input.style.display = 'none';
  html.document.body?.append(input);

  void completeWithCurrentFiles() {
    if (completer.isCompleted) {
      return;
    }
    completer.complete(input.files ?? const <html.File>[]);
  }

  late final StreamSubscription<html.Event> changeSub;
  late final StreamSubscription<html.Event> focusSub;
  changeSub = input.onChange.listen((_) => completeWithCurrentFiles());
  focusSub = html.window.onFocus.listen((_) {
    Timer(const Duration(milliseconds: 250), completeWithCurrentFiles);
  });

  input.click();
  final List<html.File> files = await completer.future;
  await changeSub.cancel();
  await focusSub.cancel();
  input.remove();
  return files;
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

String _relativePath(html.File file) {
  final Object? webkitRelativePath = _webkitRelativePath(file);
  if (webkitRelativePath is String && webkitRelativePath.isNotEmpty) {
    return webkitRelativePath;
  }

  final String relativePath = file.relativePath ?? '';
  return relativePath.isEmpty ? file.name : relativePath;
}

Object? _webkitRelativePath(html.File file) {
  try {
    return (file as dynamic).webkitRelativePath;
  } on Object {
    return null;
  }
}
