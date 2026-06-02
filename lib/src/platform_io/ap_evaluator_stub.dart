import '../core/ap_eval/ap_eval_models.dart';

ApEvaluator createApEvaluator() => const _UnavailableApEvaluator();

class _UnavailableApEvaluator implements ApEvaluator {
  const _UnavailableApEvaluator();

  @override
  Future<String?> checkAvailability() async =>
      'COCO AP evaluation is available in Desktop mode. '
      'In the web app, use "Import AP metrics JSON" to load precomputed results.';

  @override
  Future<ApEvalResult> evaluate({
    required String annotationsPath,
    required String predictionsPath,
    ApEvalConfig config = const ApEvalConfig(),
  }) =>
      Future.error('AP evaluation is not available on this platform.');

  @override
  Future<ApEvalResult> evaluateFromJson({
    required String annotationsJson,
    required String predictionsJson,
    ApEvalConfig config = const ApEvalConfig(),
  }) =>
      Future.error('AP evaluation is not available on this platform.');
}
