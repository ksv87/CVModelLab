import 'package:cv_model_lab/src/platform_io/remote/served_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('serverServesPwa', () {
    test('served when /api/config returns a valid config', () {
      expect(serverServesPwa(configOk: true, unauthorized: false), isTrue);
    });

    test('served when /api/config returns 401 (backend requires a key)', () {
      expect(serverServesPwa(configOk: false, unauthorized: true), isTrue);
    });

    test('not served when probe fails (404 / network / dev server / host)', () {
      expect(serverServesPwa(configOk: false, unauthorized: false), isFalse);
    });
  });

  group('serverUrlEditable', () {
    test('standalone web keeps the URL editable when /api/config is absent', () {
      // Probe finished, origin is not a backend → editable.
      expect(
        serverUrlEditable(
          servedFromBackend: false,
          probing: false,
          reopening: false,
        ),
        isTrue,
      );
    });

    test('server-served PWA locks the URL to the same origin', () {
      expect(
        serverUrlEditable(
          servedFromBackend: true,
          probing: false,
          reopening: false,
        ),
        isFalse,
      );
    });

    test('URL stays locked while the startup probe is still running', () {
      expect(
        serverUrlEditable(
          servedFromBackend: false,
          probing: true,
          reopening: false,
        ),
        isFalse,
      );
    });

    test('URL is locked while reopening a saved remote project', () {
      expect(
        serverUrlEditable(
          servedFromBackend: false,
          probing: false,
          reopening: true,
        ),
        isFalse,
      );
    });
  });
}
