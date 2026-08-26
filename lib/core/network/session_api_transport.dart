part of 'legacy_session_capabilities.dart';

final _log = LoggingService.instance.withTag('usernode/SessionApiTransport');

/// Transport failure from the authenticated Social mobile API.
///
/// Product code does not receive this type directly. Narrow capability APIs
/// translate it to their own failure type at the boundary.
class _SessionApiException implements Exception {
  _SessionApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() => '_SessionApiException($statusCode, $message)';
}

/// Shared authenticated HTTP mechanics for narrow mobile capabilities.
///
/// This class deliberately has no provider. App features receive only typed
/// capability APIs, which privately own one transport instance.
class _SessionApiTransport {
  _SessionApiTransport({
    String? baseUrl,
    http.Client? httpClient,
    int maxGetRetries = 2,
    Duration retryBaseDelay = const Duration(milliseconds: 300),
    Future<String?> Function()? tokenProvider,
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiBaseUrl,
        _http = httpClient ?? createAppHttpClient(),
        _maxGetRetries = maxGetRetries,
        _retryBaseDelay = retryBaseDelay,
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized,
        _onCredentialMissing = onCredentialMissing;

  final String _baseUrl;
  final http.Client _http;
  final int _maxGetRetries;
  final Duration _retryBaseDelay;
  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function(AuthCredentialLease credential)? _onUnauthorized;
  final Future<void> Function(int epoch)? _onCredentialMissing;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  static const _acceptJson = {'Accept': 'application/json'};

  Future<Object?> getData(
    String path, {
    Map<String, String>? queryParameters,
    Set<int> expectedStatuses = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final url = queryParameters == null || queryParameters.isEmpty
        ? uri
        : uri.replace(queryParameters: queryParameters);
    _log.trace('GET $url');

    final auth = await _authHeaders(_acceptJson);
    final response = await _sendWithRetry(
      () => _sendWithCurrentCredential(
        auth.credential,
        () => _http.get(url, headers: auth.headers),
      ),
    );
    return _parseEnvelope(
      response,
      url,
      expectedStatuses: expectedStatuses,
      credential: auth.credential,
    );
  }

  Future<Object?> postData(
    String path, {
    required Map<String, Object?> body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _log.trace('POST $url');

    final auth = await _authHeaders(_jsonHeaders);
    final response = await _send(
      () => _sendWithCurrentCredential(
        auth.credential,
        () => _http.post(
          url,
          headers: auth.headers,
          body: jsonEncode(body),
        ),
      ),
    );
    return _parseEnvelope(
      response,
      url,
      credential: auth.credential,
    );
  }

  Future<
      ({
        Map<String, String> headers,
        AuthCredentialLease credential,
      })> _authHeaders(Map<String, String> base) async {
    final identity = IdentitySnapshots.current;
    final token = await _tokenProvider?.call();
    if (!identity.sameScopeAs(IdentitySnapshots.current)) {
      throw const StaleAuthCredentialException();
    }
    if (token == null || token.isEmpty) {
      if (identity.isAuthenticated) {
        _detachSessionInvalidation(
          _onCredentialMissing?.call(identity.epoch),
        );
      }
      throw const StaleAuthCredentialException();
    }
    if (!identity.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    final credential = AuthCredentialLease(
      epoch: identity.epoch,
      token: token,
    );
    return (
      headers: {...base, 'Authorization': 'Bearer $token'},
      credential: credential,
    );
  }

  Future<T> _sendWithCurrentCredential<T>(
    AuthCredentialLease credential,
    Future<T> Function() send,
  ) async {
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
    return send();
  }

  Future<http.Response> _send(
    Future<http.Response> Function() send, {
    bool reportErrors = true,
  }) async {
    try {
      return await send().timeout(AppConfig.mobileApiTimeout);
    } on StaleAuthCredentialException {
      rethrow;
    } catch (error, stackTrace) {
      _log.warn('Request failed: $error');
      if (reportErrors) {
        await SentryUtil.captureError(
          error,
          stackTrace,
          tag: 'session_api',
        );
      }
      rethrow;
    }
  }

  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    var attempt = 0;
    while (true) {
      final isLastAttempt = attempt >= _maxGetRetries;
      try {
        final response = await _send(send, reportErrors: isLastAttempt);
        if (!isLastAttempt && _isRetryableStatus(response.statusCode)) {
          attempt++;
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        return response;
      } catch (error) {
        if (!isLastAttempt && _isRetryableError(error)) {
          attempt++;
          await Future<void>.delayed(_backoff(attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  Duration _backoff(int attempt) => _retryBaseDelay * (1 << (attempt - 1));

  static bool _isRetryableStatus(int statusCode) =>
      statusCode == 429 || statusCode >= 500;

  static bool _isRetryableError(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException;

  Future<Object?> _parseEnvelope(
    http.Response response,
    Uri url, {
    Set<int> expectedStatuses = const {},
    required AuthCredentialLease credential,
  }) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw _SessionApiException(
          response.statusCode,
          decoded is Map
              ? (decoded['error'] as String? ?? 'Unexpected response format')
              : 'Unexpected response format',
          body: response.body,
        );
      }
      return decoded['data'];
    }

    final message = _friendlyErrorMessage(response);
    _log.warn('API error: $message', context: {
      'statusCode': response.statusCode,
      'url': url.toString(),
    });

    if (!expectedStatuses.contains(response.statusCode)) {
      await SentryUtil.captureMessageWithData(
        'Session API error',
        {
          'status_code': response.statusCode,
          'url': url.toString(),
          'error_message': message,
        },
        level: SentryLevel.error,
      );
    }

    if (response.statusCode == 401) {
      _detachSessionInvalidation(_onUnauthorized?.call(credential));
    }

    throw _SessionApiException(
      response.statusCode,
      message,
      body: response.body,
    );
  }

  void _detachSessionInvalidation(Future<void>? invalidation) {
    if (invalidation == null) return;
    unawaited(invalidation.catchError((Object error, StackTrace stackTrace) {
      _log.warn('Session invalidation failed: $error');
    }));
  }

  String _friendlyErrorMessage(http.Response response) {
    String? detail;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        detail = decoded['error'] as String? ??
            decoded['detail'] as String? ??
            decoded['message'] as String?;
      }
    } catch (_) {
      _log.debug('Could not parse error response JSON');
    }

    return switch (response.statusCode) {
      400 => detail ?? 'Invalid request. Please check your input.',
      401 => detail ?? 'Authentication required.',
      403 => detail ?? 'Access denied.',
      404 => detail ?? 'Resource not found.',
      409 => detail ?? 'Conflict — resource already exists.',
      422 => detail ?? 'The submitted data was rejected. Please try again.',
      429 => detail ?? 'Too many requests. Please try again later.',
      _ => detail ?? 'Request failed (HTTP ${response.statusCode}).',
    };
  }

  void dispose() => _http.close();
}
