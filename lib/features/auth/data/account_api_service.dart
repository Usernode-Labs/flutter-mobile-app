import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
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
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? _deriveV3Base(),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized,
        _onCredentialMissing = onCredentialMissing;

  final http.Client _http;
  final String _baseUrl;
  final Future<String?> Function()? _tokenProvider;

  /// Invoked with the exact identity/token pair carried by a failed request.
  final Future<void> Function(AuthCredentialLease credential)? _onUnauthorized;

  final Future<void> Function(int epoch)? _onCredentialMissing;

  /// The v3 mobile base is the parent of the auth base (`…/api/v3/mobile/auth`).
  static String _deriveV3Base() {
    final auth = AppConfig.authApiBaseUrl;
    const suffix = '/auth';
    return auth.endsWith(suffix)
        ? auth.substring(0, auth.length - suffix.length)
        : auth;
  }

  Future<AuthCredentialLease?> _credential() async {
    final identity = IdentitySnapshots.current;
    final token = await _tokenProvider?.call();
    if (!identity.sameScopeAs(IdentitySnapshots.current)) {
      throw const StaleAuthCredentialException();
    }
    if (token == null || token.isEmpty) {
      if (identity.isAuthenticated) {
        await _onCredentialMissing?.call(identity.epoch);
        throw const StaleAuthCredentialException();
      }
      return null;
    }
    if (!identity.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    return AuthCredentialLease(epoch: identity.epoch, token: token);
  }

  Future<T> _sendWithCurrentCredential<T>(
    AuthCredentialLease? credential,
    Future<T> Function() send,
  ) async {
    if (credential == null) return send();
    final current = IdentitySnapshots.current;
    if (current.epoch != credential.epoch || !current.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    final token = await _tokenProvider?.call();
    final afterRead = IdentitySnapshots.current;
    if (afterRead.epoch != credential.epoch ||
        !afterRead.isAuthenticated ||
        token != credential.token) {
      throw const StaleAuthCredentialException();
    }
    // Start the transport in the same continuation as the final check.
    return send();
  }

  /// Fetches the authenticated participant profile (including `level`).
  Future<Me> getMe() async {
    final credential = await _credential();
    final url = Uri.parse('$_baseUrl/me');
    _log.trace('GET $url');
    http.Response resp;
    try {
      resp = await _sendWithCurrentCredential(
        credential,
        () => _http.get(url, headers: {
          'Accept': 'application/json',
          if (credential != null) 'Authorization': 'Bearer ${credential.token}',
        }),
      ).timeout(const Duration(seconds: 15));
    } on StaleAuthCredentialException {
      rethrow;
    } catch (e) {
      _log.warn('GET /me failed: $e');
      throw AccountApiException(0, 'Network error.');
    }

    if (resp.statusCode == 401 && credential != null) {
      await _onUnauthorized?.call(credential);
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
