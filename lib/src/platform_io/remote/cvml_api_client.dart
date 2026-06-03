import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Header used to authenticate against a CV Model Lab server.
const String cvmlApiKeyHeader = 'X-CVML-API-Key';

class RemoteApiException implements Exception {
  RemoteApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'RemoteApiException($statusCode): $message';
}

/// Thin HTTP client over a CV Model Lab server. Abstracted so tests can inject
/// a fake implementation.
abstract interface class CvmlApiClient {
  String get baseUrl;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  });

  Future<Map<String, dynamic>> postJson(String path, {Object? body});

  Future<Uint8List> getBytes(String path, {Map<String, String>? query});

  /// Absolute URL for a resource (e.g. an image), including the API key as a
  /// header is not possible for <img> tags, so callers needing raw bytes should
  /// use [getBytes].
  Uri resolveUri(String path, {Map<String, String>? query});
}

class HttpCvmlApiClient implements CvmlApiClient {
  HttpCvmlApiClient({
    required String baseUrl,
    String? apiKey,
    http.Client? httpClient,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _apiKey = apiKey,
        _client = httpClient ?? http.Client();

  @override
  final String baseUrl;
  final String? _apiKey;
  final http.Client _client;

  static String _normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Map<String, String> get _headers {
    final String? key = _apiKey;
    return <String, String>{
      if (key != null && key.isNotEmpty) cvmlApiKeyHeader: key,
    };
  }

  @override
  Uri resolveUri(String path, {Map<String, String>? query}) {
    final String full =
        path.startsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
    final Uri uri = Uri.parse(full);
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        ...query,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final http.Response response = await _send(
        () => _client.get(resolveUri(path, query: query), headers: _headers),);
    return _decodeJson(response);
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final http.Response response = await _send(
      () => _client.post(
        resolveUri(path),
        headers: <String, String>{
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeJson(response);
  }

  @override
  Future<Uint8List> getBytes(String path, {Map<String, String>? query}) async {
    final http.Response response = await _send(
        () => _client.get(resolveUri(path, query: query), headers: _headers),);
    _ensureOk(response);
    return response.bodyBytes;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on Object catch (error) {
      throw RemoteApiException('Network error: $error');
    }
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    _ensureOk(response);
    final Object? decoded =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'data': decoded};
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String message = 'Request failed (${response.statusCode})';
    try {
      final Object? decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } on Object {
      // keep default message
    }
    throw RemoteApiException(message, statusCode: response.statusCode);
  }
}
