import 'dart:io';

import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CocoDataset dataset;
  late ModelRun run;
  late EvalResult evalResult;

  setUp(() {
    dataset = const CocoAnnotationParser()
        .parseString(
          File('test_data/mini_coco/annotations.json').readAsStringSync(),
        )
        .value!;
    run = const CocoPredictionParser()
        .parseString(
          File('test_data/mini_coco/predictions.json').readAsStringSync(),
          dataset: dataset,
          modelRunId: 'run-1',
          modelRunName: 'Run 1',
        )
        .value!;
    evalResult = const MetricsCalculator().evaluate(
      dataset: dataset,
      modelRun: run,
      config: const EvalConfig(),
    );
  });

  test('report bundle can include health, worst-case and confusion CSVs', () async {
    final ReportBundle bundle = await const ReportBundleBuilder().build(
      dataset: dataset,
      modelRun: run,
      evalConfig: const EvalConfig(),
      evalResult: evalResult,
      components: const ReportComponents(
        includeConfusionPairsCsv: true,
        includeDatasetHealthCsv: true,
        includeWorstCasesCsv: true,
        includeRecommendationsCsv: true,
      ),
      projectName: 'mini',
      modelRunName: 'Run 1',
    );

    expect(bundle.csvFiles.containsKey(ReportFileNames.confusionPairs), isTrue);
    expect(bundle.csvFiles.containsKey(ReportFileNames.datasetHealth), isTrue);
    expect(bundle.csvFiles.containsKey(ReportFileNames.worstCases), isTrue);
    expect(
      bundle.csvFiles.containsKey(ReportFileNames.recommendations),
      isTrue,
    );

    // HTML report carries the new sections.
    expect(bundle.htmlReport.contains('Dataset health check'), isTrue);
    expect(bundle.htmlReport.contains('Worst cases'), isTrue);
    expect(bundle.htmlReport.contains('Confusion matrix'), isTrue);
    expect(bundle.htmlReport.contains('Recommendations'), isTrue);

    // CSV headers are present.
    expect(
      bundle.csvFiles[ReportFileNames.confusionPairs]!.split('\n').first,
      'gt_class_id,gt_class_name,pred_class_id,pred_class_name,count,'
      'row_percent,example_image_ids',
    );
    expect(
      bundle.csvFiles[ReportFileNames.datasetHealth]!.startsWith('severity,'),
      isTrue,
    );
    expect(
      bundle.csvFiles[ReportFileNames.worstCases]!.startsWith('category,'),
      isTrue,
    );
    expect(
      bundle.csvFiles[ReportFileNames.recommendations]!.split('\n').first,
      'severity,category,title,message,action,related_image_ids,'
      'related_category_ids,evidence_json',
    );
  });
}
