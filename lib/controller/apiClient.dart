import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:ride_sharing/widgets/consonants/apiException.dart';
import 'package:ride_sharing/widgets/consonants/tokenStorage.dart';

export 'package:ride_sharing/widgets/consonants/apiException.dart';

class Apiclient {
  final http.Client _client;
  final Duration _timeout;

  Apiclient({http.Client? client, Duration? timeout})
    : _client = client ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 30);

  Future<Map<String, String>> _buildHeaders({
    bool requireAuth = true,
    String? overrideToken,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Skip ngrok's free-tier browser interstitial so API calls go straight
      // through (harmless when not tunnelling via ngrok).
      'ngrok-skip-browser-warning': 'true',
    };
    final token = overrideToken ?? await Tokenstorage.getToken();
    if (requireAuth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }
    throw ApiException(
      statusCode: code,
      message: _extractErrorMessage(response),
    );
  }

  String _extractErrorMessage(http.Response response) {
    final fallback = _defaultMessageFor(response.statusCode);
    if (response.body.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        for (final key in const ['message', 'error', 'detail']) {
          final v = decoded[key];
          if (v is String && v.isNotEmpty) return v;
        }
      }
      if (decoded is String && decoded.isNotEmpty) return decoded;
    } catch (_) {
      // Body wasn't JSON — fall through.
    }
    return fallback;
  }

  String _defaultMessageFor(int code) {
    switch (code) {
      case 400:
        return 'Bad request. Please check your input and try again.';
      case 401:
        return 'Unauthorized. Please log in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict. This resource already exists.';
      case 500:
      case 502:
      case 503:
        return 'Server error. Please try again later.';
      default:
        return 'Something went wrong (code: $code).';
    }
  }

  Future<T> _safeCall<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on SocketException {
      throw ApiException(
        statusCode: 0,
        message: 'No internet connection. Please check your network.',
      );
    } on TimeoutException {
      throw ApiException(
        statusCode: 0,
        message: 'Request timed out. Please try again.',
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        statusCode: 0,
        message: 'Network error: ${e.message}',
      );
    } on FormatException {
      throw ApiException(
        statusCode: 0,
        message: 'Invalid response from server.',
      );
    }
  }

  Future<dynamic> get(String url, {String? token}) {
    return _safeCall(() async {
      final headers = await _buildHeaders(overrideToken: token);
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    });
  }

  Future<dynamic> post(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _safeCall(() async {
      final headers = await _buildHeaders(overrideToken: token);
      final response = await _client
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _handleResponse(response);
    });
  }

  Future<dynamic> put(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _safeCall(() async {
      final headers = await _buildHeaders(overrideToken: token);
      final response = await _client
          .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _handleResponse(response);
    });
  }

  Future<dynamic> delete(String url, {String? token}) {
    return _safeCall(() async {
      final headers = await _buildHeaders(overrideToken: token);
      final response = await _client
          .delete(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return _handleResponse(response);
    });
  }

  void dispose() => _client.close();
}
