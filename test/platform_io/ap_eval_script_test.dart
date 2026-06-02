import 'dart:io';

import 'package:cv_model_lab/src/platform_io/ap_eval_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('embedded ap_eval script matches canonical tools/ap_evaluator/ap_eval.py',
      () {
    final File canonical = File('tools/ap_evaluator/ap_eval.py');
    expect(
      canonical.existsSync(),
      isTrue,
      reason: 'canonical sidecar script must exist',
    );

    final String onDisk = canonical.readAsStringSync();
    expect(
      apEvalScriptSource,
      onDisk,
      reason: 'Embedded apEvalScriptSource is out of sync with '
          'tools/ap_evaluator/ap_eval.py. Regenerate the embedded copy.',
    );
  });

  test('embedded script carries PEP 723 metadata for uv', () {
    expect(apEvalScriptSource, contains('# /// script'));
    expect(apEvalScriptSource, contains('pycocotools'));
  });
}
