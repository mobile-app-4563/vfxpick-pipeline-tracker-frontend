import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Central HTTP client for all VfxPick API calls.
/// Features:
/// - Complete logging of all requests/responses in debug console
/// - Automatic JWT token management
/// - Centralized error handling
/// - Pretty-printed response bodies
class ApiController {
  // ─── Singleton ───────────────────────────────────────────────────────────────
  static final ApiController _instance = ApiController._internal();
  factory ApiController() => _instance;
  ApiController._internal();

  static ApiController get instance => _instance;

  // ─── Auth token ──────────────────────────────────────────────────────────────
  String? _token;

  void setToken(String token) {
    _token = token;
    _log('Authentication', 'Token set: ${token.substring(0, 15)}...');
  }

  void clearToken() {
    _token = null;
    _log('Authentication', 'Token cleared');
  }

  String? getToken() => _token;

  bool get isAuthenticated => _token != null;

  // ─── Auth-bootstrap gate ────────────────────────────────────────────────────
  // Requests fired before session bootstrap finishes (e.g. a screen's
  // initState load right after a hot restart lands on the same URL) go out
  // WITHOUT a token → 401 "Authentication token is missing". Gate every
  // request on bootstrap completion so this race can never happen.
  bool _authBootstrapBegun = false;
  Completer<void>? _authBootstrapCompleter;

  /// Called by [AuthController] at startup, BEFORE any screen fires requests.
  void beginAuthBootstrap() {
    _authBootstrapBegun = true;
    _authBootstrapCompleter ??= Completer<void>();
  }

  /// Called by [AuthController] as soon as the stored token is restored (or
  /// confirmed absent). Releases any request that was waiting on bootstrap.
  void markAuthReady() {
    _authBootstrapBegun = false;
    _authBootstrapCompleter?.complete();
    _authBootstrapCompleter = null;
  }

  Future<void> get _authBootstrapDone {
    if (!_authBootstrapBegun || _authBootstrapCompleter == null) {
      return Future.value();
    }
    return _authBootstrapCompleter!.future;
  }

  // ─── Headers ─────────────────────────────────────────────────────────────────
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── Logging & debugging helpers ─────────────────────────────────────────────
  void _log(String category, String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[$timestamp] $message', name: 'VfxPick.$category');
  }

  String _prettyPrintJson(dynamic data) {
    try {
      if (data is String) {
        data = jsonDecode(data);
      }
      return JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  void _logRequest(String method, String url, {Object? body}) {
    final bodyStr = body != null
        ? '\n  📦 Body: ${_prettyPrintJson(body)}'
        : '';
    _log('API.Request', '[$method] $url$bodyStr');
  }

  void _logResponse(String method, String url, http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final icon = isSuccess ? '✅' : '❌';
    _log(
      'API.Response',
      '$icon [$method] $url\n  Status: ${response.statusCode}\n  Response: ${_prettyPrintJson(response.body)}',
    );
  }

  void _logError(String method, String url, Object error, StackTrace? stack) {
    _log(
      'API.Error',
      '❌ [$method] $url\n  Error: $error${stack != null ? '\n  Stack: $stack' : ''}',
    );
  }

  // ─── URL builder ─────────────────────────────────────────────────────────────
  Uri _uri(String path, {Map<String, String>? queryParams}) {
    final fullUrl = '${ApiConstants.baseUrl}$path';
    final uri = Uri.parse(fullUrl);
    return queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
  }

  // ─── GET Request ──────────────────────────────────────────────────────────────
  /// GET request with optional query parameters
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    await _authBootstrapDone;
    final url = _uri(path, queryParams: queryParams);
    _logRequest('GET', url.toString());
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException('Request timeout (30s)', 408),
          );
      _logResponse('GET', url.toString(), response);
      return _parse(response);
    } catch (e, stack) {
      _logError('GET', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── POST Request ─────────────────────────────────────────────────────────────
  /// POST request with request body
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    await _authBootstrapDone;
    final url = _uri(path);
    _logRequest('POST', url.toString(), body: body);
    try {
      final response = await http
          .post(url, headers: _headers, body: jsonEncode(body))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException('Request timeout (30s)', 408),
          );
      _logResponse('POST', url.toString(), response);
      return _parse(response);
    } catch (e, stack) {
      _logError('POST', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── PUT Request ──────────────────────────────────────────────────────────────
  /// PUT request with request body
  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    await _authBootstrapDone;
    final url = _uri(path);
    _logRequest('PUT', url.toString(), body: body);
    try {
      final response = await http
          .put(url, headers: _headers, body: jsonEncode(body))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException('Request timeout (30s)', 408),
          );
      _logResponse('PUT', url.toString(), response);
      return _parse(response);
    } catch (e, stack) {
      _logError('PUT', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── PATCH Request ────────────────────────────────────────────────────────────
  /// PATCH request with optional request body
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    await _authBootstrapDone;
    final url = _uri(path);
    _logRequest('PATCH', url.toString(), body: body);
    try {
      final response = await http
          .patch(
            url,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException('Request timeout (30s)', 408),
          );
      _logResponse('PATCH', url.toString(), response);
      return _parse(response);
    } catch (e, stack) {
      _logError('PATCH', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── DELETE Request ───────────────────────────────────────────────────────────
  /// DELETE request
  Future<Map<String, dynamic>> delete(String path) async {
    await _authBootstrapDone;
    final url = _uri(path);
    _logRequest('DELETE', url.toString());
    try {
      final response = await http
          .delete(url, headers: _headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw ApiException('Request timeout (30s)', 408),
          );
      _logResponse('DELETE', url.toString(), response);
      return _parse(response);
    } catch (e, stack) {
      _logError('DELETE', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── Binary download ────────────────────────────────────────────────────────
  Future<Uint8List> getBytes(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    await _authBootstrapDone;
    final url = _uri(path, queryParams: queryParams);
    _logRequest('GET(bytes)', url.toString());
    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw ApiException('Request timeout (60s)', 408),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log(
          'API.Response',
          '✅ [GET(bytes)] $url\n  Status: ${response.statusCode}\n  Bytes: ${response.bodyBytes.length}',
        );
        return response.bodyBytes;
      }

      _logResponse('GET(bytes)', url.toString(), response);
      final parsed = _parse(response);
      throw ApiException(
        (parsed['error'] ?? parsed['message'] ?? 'Download failed').toString(),
        response.statusCode,
      );
    } catch (e, stack) {
      _logError('GET(bytes)', url.toString(), e, stack);
      rethrow;
    }
  }

  // ─── Response parser ──────────────────────────────────────────────────────────
  /// Parse HTTP response and handle errors
  Map<String, dynamic> _parse(http.Response response) {
    try {
      final Map<String, dynamic> decoded =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log(
          'API.Parse',
          '✅ Successfully parsed response (${response.statusCode})',
        );
        return decoded;
      }

      // Handle error response
      final message =
          decoded['message'] ??
          decoded['error'] ??
          decoded['detail'] ??
          'Unknown error';
      _log('API.Parse', '❌ Server error: $message (${response.statusCode})');
      throw ApiException(message.toString(), response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      _log('API.Parse', '❌ Failed to parse response: $e');
      throw ApiException('Failed to parse response', 500);
    }
  }
}

// ─── Custom Exception ─────────────────────────────────────────────────────────
/// Exception thrown when an API request fails
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  /// Whether the error is a network/timeout error
  bool get isNetworkError => statusCode == 408 || statusCode == 0;

  /// Whether the error is unauthorized (401)
  bool get isUnauthorized => statusCode == 401;

  /// Whether the error is server error (5xx)
  bool get isServerError => statusCode >= 500;

  /// Whether the error is client error (4xx)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
