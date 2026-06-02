import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

ApEvalResult _sampleApResult() {
  return ApEvalResult(
    evaluatorName: 'pycocotools',
    generatedAt: DateTime.utc(2026, 6, 2, 10, 0, 0),
    ap: 0.458,
    ap50: 0.621,
    ap75: 0.512,
    perClass: const [
      ClassApMetric(
        categoryId: 1,
        categoryName: 'person',
        ap: 0.412,
        ap50: 0.598,
        ap75: 0.441,
        ar: 0.478,
      ),
    ],
    warnings: const [],
  );
}

CvmlProject _sampleProject({ApEvalResult? apEvalResult}) {
  final DateTime now = DateTime.utc(2026, 6, 2);
  return CvmlProject(
    schemaVersion: '1',
    id: 'p1',
    name: 'Test project',
    createdAt: now,
    updatedAt: now,
    datasetSource: const ProjectDatasetSource(),
    modelRuns: [
      ProjectModelRunSource(
        id: 'run-1',
        name: 'Model A',
        addedAt: now,
        apEvalResult: apEvalResult,
      ),
    ],
    defaultEvalConfig: const EvalConfig(),
  );
}

void main() {
  const ProjectSerializer serializer = ProjectSerializer();

  test('save project with AP metrics round-trips correctly', () {
    final ApEvalResult apResult = _sampleApResult();
    final CvmlProject project = _sampleProject(apEvalResult: apResult);

    final String json = serializer.toJsonString(project);
    final CvmlProject loaded = serializer.fromJsonString(json);

    expect(loaded.modelRuns, hasLength(1));
    final ProjectModelRunSource run = loaded.modelRuns[0];
    expect(run.apEvalResult, isNotNull);
    expect(run.apEvalResult!.ap, closeTo(0.458, 1e-9));
    expect(run.apEvalResult!.ap50, closeTo(0.621, 1e-9));
    expect(run.apEvalResult!.evaluatorName, 'pycocotools');
    expect(run.apEvalResult!.perClass, hasLength(1));
    expect(run.apEvalResult!.perClass[0].categoryName, 'person');
  });

  test('old project file without ap_eval_result loads without crash', () {
    final CvmlProject project = _sampleProject();
    expect(project.modelRuns[0].apEvalResult, isNull);

    final String json = serializer.toJsonString(project);
    expect(json, isNot(contains('ap_eval_result')));

    final CvmlProject loaded = serializer.fromJsonString(json);
    expect(loaded.modelRuns[0].apEvalResult, isNull);
  });

  test('AP metrics serialized under ap_eval_result key in model run JSON', () {
    final ApEvalResult apResult = _sampleApResult();
    final CvmlProject project = _sampleProject(apEvalResult: apResult);

    final String json = serializer.toJsonString(project);
    expect(json, contains('"ap_eval_result"'));
    expect(json, contains('"evaluator_name"'));
    expect(json, contains('"ap"'));
    expect(json, contains('"per_class"'));
  });

  test('AP metrics absent in JSON when result is null', () {
    final CvmlProject project = _sampleProject();
    final String json = serializer.toJsonString(project);
    expect(json, isNot(contains('"ap_eval_result"')));
  });

  test('AP diff arithmetic is correct', () {
    const double baseAp = 0.45;
    const double candidateAp = 0.48;
    const double delta = candidateAp - baseAp;
    expect(delta, closeTo(0.03, 1e-9));
    expect(delta > 0, isTrue);
  });

  test('ClassApMetric fields are preserved correctly through round-trip', () {
    final ApEvalResult apResult = _sampleApResult();
    final CvmlProject project = _sampleProject(apEvalResult: apResult);

    final CvmlProject loaded =
        serializer.fromJsonString(serializer.toJsonString(project));
    final ClassApMetric cls = loaded.modelRuns[0].apEvalResult!.perClass[0];
    expect(cls.categoryId, 1);
    expect(cls.categoryName, 'person');
    expect(cls.ap, closeTo(0.412, 1e-9));
    expect(cls.ar, closeTo(0.478, 1e-9));
  });
}
