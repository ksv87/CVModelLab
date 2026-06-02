import '../comparison/comparison_models.dart';
import '../model/coco_dataset.dart';
import '../model/eval_result.dart';
import 'annotated_export_models.dart';

/// Resolves which images an annotated export covers, in order, and builds their
/// output file names. UI-free and fully testable: it works on plain data
/// (ids, summaries, comparison result) so the scope selection logic is not
/// entangled with rendering or platform code.
class AnnotatedExportSelector {
  const AnnotatedExportSelector();

  /// Ordered, de-duplicated image ids for [config.scope], before applying
  /// [AnnotatedImageExportConfig.maxImages].
  List<int> selectImageIds({
    required AnnotatedImageExportConfig config,
    required EvalResult evalResult,
    int? currentImageId,
    List<int> filteredImageIds = const <int>[],
    ModelComparisonResult? comparison,
  }) {
    final Iterable<int> raw = switch (config.scope) {
      AnnotatedExportScope.currentImage =>
        currentImageId == null ? const <int>[] : <int>[currentImageId],
      AnnotatedExportScope.currentFilteredImages => filteredImageIds,
      AnnotatedExportScope.falsePositiveImages => _summariesSorted(
          evalResult,
          predicate: (ImageEvalSummary s) => s.fp > 0,
          score: (ImageEvalSummary s) => s.fp,
        ),
      AnnotatedExportScope.falseNegativeImages => _summariesSorted(
          evalResult,
          predicate: (ImageEvalSummary s) => s.fn > 0,
          score: (ImageEvalSummary s) => s.fn,
        ),
      AnnotatedExportScope.classConfusionImages => _summariesSorted(
          evalResult,
          predicate: (ImageEvalSummary s) => s.hasClassConfusion,
          score: (ImageEvalSummary s) => s.fp + s.fn,
        ),
      AnnotatedExportScope.worstImages => _summariesSorted(
          evalResult,
          predicate: (ImageEvalSummary s) => s.fp + s.fn > 0,
          score: (ImageEvalSummary s) => s.fp + s.fn,
        ),
      AnnotatedExportScope.comparisonFixedImages =>
        comparison?.fixedImageIds ?? const <int>[],
      AnnotatedExportScope.comparisonBrokenImages =>
        comparison?.brokenImageIds ?? const <int>[],
      AnnotatedExportScope.comparisonImprovedImages =>
        comparison?.improvedImageIds ?? const <int>[],
      AnnotatedExportScope.comparisonRegressedImages =>
        comparison?.regressedImageIds ?? const <int>[],
    };

    final List<int> result = [];
    final Set<int> seen = {};
    for (final int id in raw) {
      if (seen.add(id)) {
        result.add(id);
      }
    }
    return result;
  }

  /// Resolves [selectImageIds], caps to [AnnotatedImageExportConfig.maxImages]
  /// and produces [AnnotatedExportTarget]s with sanitized output file names.
  List<AnnotatedExportTarget> resolveTargets({
    required AnnotatedImageExportConfig config,
    required CocoDataset dataset,
    required EvalResult evalResult,
    int? currentImageId,
    List<int> filteredImageIds = const <int>[],
    ModelComparisonResult? comparison,
  }) {
    final List<int> ids = selectImageIds(
      config: config,
      evalResult: evalResult,
      currentImageId: currentImageId,
      filteredImageIds: filteredImageIds,
      comparison: comparison,
    );
    final int limit = config.maxImages <= 0
        ? ids.length
        : (ids.length < config.maxImages ? ids.length : config.maxImages);
    final String status = _statusTag(config.scope);

    final List<AnnotatedExportTarget> targets = [];
    for (int i = 0; i < limit; i++) {
      final int imageId = ids[i];
      final String fileName = dataset.imagesById[imageId]?.fileName ?? '$imageId';
      targets.add(
        AnnotatedExportTarget(
          imageId: imageId,
          fileName: fileName,
          status: status,
          index: i,
          outputFileName: buildFileName(
            template: config.fileNameTemplate,
            index: i,
            status: status,
            fileName: fileName,
            imageId: imageId,
          ),
        ),
      );
    }
    return targets;
  }

  List<int> _summariesSorted(
    EvalResult evalResult, {
    required bool Function(ImageEvalSummary) predicate,
    required int Function(ImageEvalSummary) score,
  }) {
    final List<ImageEvalSummary> summaries = evalResult.imageSummaries.values
        .where(predicate)
        .toList()
      ..sort((ImageEvalSummary a, ImageEvalSummary b) {
        final int byScore = score(b).compareTo(score(a));
        if (byScore != 0) {
          return byScore;
        }
        return a.imageId.compareTo(b.imageId);
      });
    return [for (final ImageEvalSummary s in summaries) s.imageId];
  }

  static String _statusTag(AnnotatedExportScope scope) {
    return switch (scope) {
      AnnotatedExportScope.currentImage => 'current',
      AnnotatedExportScope.currentFilteredImages => 'filtered',
      AnnotatedExportScope.falsePositiveImages => 'fp',
      AnnotatedExportScope.falseNegativeImages => 'fn',
      AnnotatedExportScope.classConfusionImages => 'confusion',
      AnnotatedExportScope.worstImages => 'worst',
      AnnotatedExportScope.comparisonFixedImages => 'fixed',
      AnnotatedExportScope.comparisonBrokenImages => 'broken',
      AnnotatedExportScope.comparisonImprovedImages => 'improved',
      AnnotatedExportScope.comparisonRegressedImages => 'regressed',
    };
  }

  /// Expands [template] and sanitizes the result into a safe single-segment
  /// PNG file name. Supported tokens: `{index}`, `{status}`, `{fileName}`,
  /// `{imageId}`.
  static String buildFileName({
    required String template,
    required int index,
    required String status,
    required String fileName,
    required int imageId,
  }) {
    // Use the basename of the COCO file_name and drop its extension so the
    // template controls the final extension.
    final String base = sanitizeSegment(_stripExtension(_basename(fileName)));
    String name = template
        .replaceAll('{index}', index.toString())
        .replaceAll('{status}', status)
        .replaceAll('{imageId}', imageId.toString())
        .replaceAll('{fileName}', base);
    name = sanitizeSegment(name);
    if (name.isEmpty) {
      name = 'image_$index';
    }
    return '$name.png';
  }

  /// Strips path separators and characters that are unsafe in file names.
  static String sanitizeSegment(String value) {
    final String replaced = value.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return replaced.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _basename(String path) {
    final String normalized = path.replaceAll('\\', '/');
    final int slash = normalized.lastIndexOf('/');
    return slash == -1 ? normalized : normalized.substring(slash + 1);
  }

  static String _stripExtension(String name) {
    final int dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }
}
