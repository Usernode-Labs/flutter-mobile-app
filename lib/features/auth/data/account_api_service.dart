import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

final _log = LoggingService.instance.withTag('usernode/AccountApiService');

class AccountApiException implements Exception {
  AccountApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;
  @override
  String toString() => 'AccountApiException($statusCode, $message)';
}

/// Client for the session-scoped account endpoints under `/api/v3/mobile`.
class AccountApiService {
  AccountApiService({
    http.Client? httpClient,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
    Future<void> Function()? onUnauthorized,
  })  : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? _deriveV3Base(),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized;

  final http.Client _http;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function()? _onUnauthorized;

  /// The v3 mobile base is the parent of the auth base (`…/api/v3/mobile/auth`).
  static String _deriveV3Base() {
    final auth = AppConfig.authApiBaseUrl;
    const suffix = '/auth';
    return auth.endsWith(suffix)
        ? auth.substring(0, auth.length - suffix.length)
        : auth;
  }

  /// Fetches the authenticated participant profile (including `level`).
  Future<Me> getMe() async {
    final token = await _tokenProvider?.call();
    final url = Uri.parse('$_baseUrl/me');
    _log.trace('GET $url');
    http.Response resp;
    try {
      resp = await _http.get(url, headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      _log.warn('GET /me failed: $e');
      throw AccountApiException(0, 'Network error.');
    }

    if (resp.statusCode == 401) {
      await _onUnauthorized?.call();
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AccountApiException(resp.statusCode, 'Request failed.');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw AccountApiException(resp.statusCode, 'Unexpected response format.');
    }
    return Me.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  void dispose() => _http.close();
}
