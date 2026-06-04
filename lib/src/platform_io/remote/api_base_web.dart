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
