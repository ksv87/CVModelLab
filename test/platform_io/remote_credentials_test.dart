import 'package:cv_model_lab/cv_model_lab.dart';
import 'package:cv_model_lab/src/platform_io/remote/remote_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved key is restored only after explicit save', () async {
    final credentials = RemoteCredentialStore(MemoryUserPreferencesStore());
    expect(await credentials.getApiKey('https://server'), isNull);

    await credentials.saveApiKey('https://server', 'secret');
    expect(await credentials.getApiKey('https://server'), 'secret');
  });

  test('forget saved key removes it', () async {
    final credentials = RemoteCredentialStore(MemoryUserPreferencesStore());
    await credentials.saveApiKey('https://server', 'secret');
    await credentials.clearApiKey('https://server');
    expect(await credentials.getApiKey('https://server'), isNull);
  });
}
