import 'file_pick_result.dart';
import 'image_source.dart';

abstract interface class ProjectFileIo {
  /// Opens a project file. Returns null if cancelled.
  Future<PickedDataFile?> openProject();

  /// Saves project JSON to a new file. Returns the saved path, or null if
  /// cancelled.
  Future<String?> saveProjectAs(String jsonContent, String suggestedName);

  /// Saves project JSON to an existing path. Returns true if succeeded.
  Future<bool> saveProjectToPath(String path, String jsonContent);

  /// Reads a file by its absolute local path. Returns null on web or if the
  /// file is missing.
  Future<PickedDataFile?> readFileAtPath(String path);

  /// Opens an image source rooted at the given local directory path. Returns
  /// null on web or if the directory does not exist.
  Future<ImageSource?> openImageSourceAtPath(String path);
}

class UnsupportedProjectFileIo implements ProjectFileIo {
  const UnsupportedProjectFileIo();

  @override
  Future<PickedDataFile?> openProject() {
    throw UnsupportedError(
      'Project file I/O is not available on this platform.',
    );
  }

  @override
  Future<String?> saveProjectAs(String jsonContent, String suggestedName) {
    throw UnsupportedError(
      'Project file I/O is not available on this platform.',
    );
  }

  @override
  Future<bool> saveProjectToPath(String path, String jsonContent) {
    throw UnsupportedError(
      'Project file I/O is not available on this platform.',
    );
  }

  @override
  Future<PickedDataFile?> readFileAtPath(String path) async => null;

  @override
  Future<ImageSource?> openImageSourceAtPath(String path) async => null;
}

ProjectFileIo createProjectFileIo() => const UnsupportedProjectFileIo();
