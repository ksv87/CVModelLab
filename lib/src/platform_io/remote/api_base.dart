/// Resolves the default API base URL for the current platform.
///
/// On the web (PWA served by the backend) this is the same origin the app was
/// loaded from, so the PWA only ever talks to its own server. On desktop there
/// is no implicit server — the user enters a URL via "Connect to Server".
export 'api_base_io.dart' if (dart.library.html) 'api_base_web.dart';
