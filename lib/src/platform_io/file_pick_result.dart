import 'dart:convert';
import 'dart:typed_data';

class PickedDataFile {
  const PickedDataFile({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final String? path;
  final Uint8List bytes;

  String readAsString() {
    return utf8.decode(bytes);
  }
}
