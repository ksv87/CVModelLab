// ignore: deprecated_member_use
import 'dart:html' as html;

/// Web/PWA: the server origin is the origin the app was loaded from.
String? sameOriginServerUrl() {
  final String origin = html.window.location.origin;
  if (origin.isEmpty || origin == 'null') {
    return null;
  }
  return origin;
}

/// On the web the app is always served from some origin; in server mode that
/// origin is the CV Model Lab server.
bool get isServedFromServer => true;
