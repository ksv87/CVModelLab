import 'file_pick_result.dart';
import 'image_source.dart';

PlatformFilePicker createPlatformFilePicker() {
  return const UnsupportedPlatformFilePicker();
}

abstract interface class PlatformFilePicker {
  Future<PickedDataFile?> pickAnnotationsJson({String? initialDirectory});

  Future<PickedDataFile?> pickPredictionsJson({String? initialDirectory});

  Future<PickedDataFile?> pickApMetricsJson({String? initialDirectory});

  Future<ImageSource?> pickImages({String? initialDirectory});
}

class UnsupportedPlatformFilePicker implements PlatformFilePicker {
  const UnsupportedPlatformFilePicker();

  @override
  Future<PickedDataFile?> pickAnnotationsJson({String? initialDirectory}) {
    throw UnsupportedError('File picking is not available on this platform.');
  }

  @override
  Future<PickedDataFile?> pickApMetricsJson({String? initialDirectory}) {
    throw UnsupportedError('File picking is not available on this platform.');
  }

  @override
  Future<ImageSource?> pickImages({String? initialDirectory}) {
    throw UnsupportedError('File picking is not available on this platform.');
  }

  @override
  Future<PickedDataFile?> pickPredictionsJson({String? initialDirectory}) {
    throw UnsupportedError('File picking is not available on this platform.');
  }
}
