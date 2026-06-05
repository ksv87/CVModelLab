/// Pure decision helpers for the same-origin PWA / standalone web behaviour.
///
/// These are kept free of Flutter and `dart:html` so the rules can be unit
/// tested directly.

/// Decides whether a same-origin web build is served by a CV Model Lab backend,
/// based on the outcome of probing `/api/config` at the current origin.
///
/// * [configOk] — the probe returned a valid `ServerClientConfig` (HTTP 200).
/// * [unauthorized] — the probe returned HTTP 401 (a backend is present but it
///   requires an API key).
///
/// Either case means the backend serves this app, so the server URL is fixed to
/// the same origin. Any other outcome (404, network error, an HTML page from
/// the `flutter run` dev server or a separate host) means standalone web.
bool serverServesPwa({required bool configOk, required bool unauthorized}) {
  return configOk || unauthorized;
}

/// Decides whether the server URL field is editable.
///
/// The field is locked when the PWA is served by a backend (same-origin) or
/// while reopening a saved remote project. In standalone web (and on desktop),
/// or once a probe determines the origin is not a backend, the field stays
/// editable so the user can type the server address manually.
bool serverUrlEditable({
  required bool servedFromBackend,
  required bool probing,
  required bool reopening,
}) {
  return !servedFromBackend && !probing && !reopening;
}
