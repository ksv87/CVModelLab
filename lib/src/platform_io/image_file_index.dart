class ImageFileIndex<T> {
  ImageFileIndex(Iterable<ImageFileEntry<T>> entries) {
    for (final ImageFileEntry<T> entry in entries) {
      final String relativePath = normalizeImagePath(entry.relativePath);
      final String name = basename(relativePath);
      _byRelativePath.putIfAbsent(relativePath, () => entry.value);
      _byBasename.putIfAbsent(name, () => <ImageFileEntry<T>>[]).add(
            ImageFileEntry<T>(
              relativePath: relativePath,
              basename: name,
              value: entry.value,
            ),
          );
    }
  }

  final Map<String, T> _byRelativePath = {};
  final Map<String, List<ImageFileEntry<T>>> _byBasename = {};

  T? resolve(String cocoFileName) {
    final String normalized = normalizeImagePath(cocoFileName);
    final T? exact = _byRelativePath[normalized];
    if (exact != null) {
      return exact;
    }

    final List<ImageFileEntry<T>> suffixMatches = _suffixMatches(normalized);
    if (suffixMatches.length == 1) {
      return suffixMatches.single.value;
    }
    if (suffixMatches.length > 1) {
      return null;
    }

    final List<ImageFileEntry<T>> basenameMatches =
        _byBasename[basename(normalized)] ?? <ImageFileEntry<T>>[];
    if (basenameMatches.length == 1) {
      return basenameMatches.single.value;
    }
    return null;
  }

  List<ImageFileEntry<T>> _suffixMatches(String normalizedCocoFileName) {
    final String suffix = '/$normalizedCocoFileName';
    final List<ImageFileEntry<T>> basenameMatches =
        _byBasename[basename(normalizedCocoFileName)] ?? <ImageFileEntry<T>>[];
    return [
      for (final ImageFileEntry<T> entry in basenameMatches)
        if (entry.relativePath.endsWith(suffix)) entry,
    ];
  }

  bool exists(String cocoFileName) {
    return resolve(cocoFileName) != null;
  }

  List<String> missingImages(Iterable<String> cocoFileNames) {
    return [
      for (final String fileName in cocoFileNames)
        if (!exists(fileName)) fileName,
    ];
  }

  List<String> ambiguityWarnings(Iterable<String> cocoFileNames) {
    final List<String> warnings = [];
    for (final String fileName in cocoFileNames) {
      final String normalized = normalizeImagePath(fileName);
      if (_byRelativePath.containsKey(normalized)) {
        continue;
      }
      final List<ImageFileEntry<T>> suffixMatches = _suffixMatches(normalized);
      if (suffixMatches.length == 1) {
        continue;
      }
      if (suffixMatches.length > 1) {
        warnings.add(
          'Image "$fileName" has ${suffixMatches.length} suffix matches; '
          'select a narrower image directory to resolve it.',
        );
        continue;
      }
      final List<ImageFileEntry<T>> basenameMatches =
          _byBasename[basename(normalized)] ?? <ImageFileEntry<T>>[];
      if (basenameMatches.length > 1) {
        warnings.add(
          'Image "$fileName" has ${basenameMatches.length} basename matches; '
          'select files with relative paths to resolve it.',
        );
      }
    }
    return warnings;
  }
}

class ImageFileEntry<T> {
  const ImageFileEntry({
    required this.relativePath,
    required this.value,
    String? basename,
  }) : basename = basename ?? relativePath;

  final String relativePath;
  final String basename;
  final T value;
}

String normalizeImagePath(String path) {
  return path.replaceAll('\\', '/').split('/').where((String part) {
    return part.isNotEmpty && part != '.';
  }).join('/');
}

String basename(String path) {
  final String normalized = normalizeImagePath(path);
  final int slashIndex = normalized.lastIndexOf('/');
  return slashIndex == -1 ? normalized : normalized.substring(slashIndex + 1);
}
