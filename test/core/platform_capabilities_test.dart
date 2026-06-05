import 'package:cv_model_lab/src/core/platform/platform_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop supports local and remote workflows', () {
    const c = PlatformCapabilities.desktop;
    expect(c.kind, CvmlPlatformKind.desktop);
    expect(c.supportsLocalStandaloneProjects, isTrue);
    expect(c.supportsRemoteProjects, isTrue);
    expect(c.supportsLocalDatasetPicker, isTrue);
    expect(c.supportsServerConnection, isTrue);
    expect(c.supportsLocalApEvaluator, isTrue);
  });

  test('web supports browser local projects and remote workflows', () {
    const c = PlatformCapabilities.web;
    expect(c.kind, CvmlPlatformKind.web);
    expect(c.supportsLocalStandaloneProjects, isTrue);
    expect(c.supportsRemoteProjects, isTrue);
    expect(c.supportsLocalDatasetPicker, isTrue);
    expect(c.supportsServerConnection, isTrue);
    expect(c.supportsLocalApEvaluator, isFalse);
  });

  test('native mobile supports remote-only workflows', () {
    const c = PlatformCapabilities.mobile;
    expect(c.kind, CvmlPlatformKind.mobile);
    expect(c.supportsLocalStandaloneProjects, isFalse);
    expect(c.supportsRemoteProjects, isTrue);
    expect(c.supportsLocalDatasetPicker, isFalse);
    expect(c.supportsServerConnection, isTrue);
    expect(c.supportsLocalApEvaluator, isFalse);
  });
}
