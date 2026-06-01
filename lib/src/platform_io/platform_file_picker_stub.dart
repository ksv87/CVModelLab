import 'file_pick_result.dart';
import 'image_source.dart';

PlatformFilePicker createPlatformFilePicker() {
  return const UnsupportedPlatformFilePicker();
}

abstract interface class PlatformFilePicker {
  Future<PickedDataFile?> pickAnnotationsJson();

  Future<PickedDataFile?> pickPredictionsJson();

  Future<ImageSource?> pickImages();
}

class UnsupportedPlatformFilePicker implements PlatformFilePicker {
  const UnsupportedPlatformFilePicker();

  @override
  Future<PickedDataFile?> pickAnnotationsJson() {
    throw UnsupportedError('File picking is not available on this platform.');
  }

  @override
  Future<ImageSource?> pickImages() {
    throw UnsupportedError('File picking is not available on this platform.');
  }

  @override
  Future<PickedDataFile?> pickPredictionsJson() {
    throw UnsupportedError('File picking is not available on this platform.');
  }
}
