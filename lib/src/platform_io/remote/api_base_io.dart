/// Desktop/non-web: there is no implicit server origin.
String? sameOriginServerUrl() => null;

/// Whether the app is being served by a CV Model Lab server (web/PWA only).
bool get isServedFromServer => false;
