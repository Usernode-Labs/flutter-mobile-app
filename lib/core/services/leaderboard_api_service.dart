import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardApiService');
const _backendWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

class LeaderboardApiService {
  LeaderboardApiService({
    String? baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
    int? maxGetRetries,
    Duration? retryBaseDelay,
    Future<String?> Function()? tokenProvider,
    Future<void> Function()? onUnauthorized,
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiV3BaseUrl,
        _http = httpClient ?? createAppHttpClient(),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly,
        _maxGetRetries = maxGetRetries ?? 2,
        _retryBaseDelay = retryBaseDelay ?? const Duration(milliseconds: 300),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized;

  final String _baseUrl;
  final http.Client _http;
  final bool _writesEnabled;

  /// Resolves the current session token for the `Authorization` header, and the
  /// callback to run on a 401 (clear token, bounce to auth). Both optional so
  /// tests can construct the service without auth wiring.
  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function()? _onUnauthorized;

  /// Number of additional attempts for idempotent GETs after the first one.
  /// Writes (POST) are never retried to avoid duplicate side effects.
  final int _maxGetRetries;

  /// Base delay for exponential backoff between GET retries.
  final Duration _retryBaseDelay;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static const _acceptJson = {
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<RegistrationV2Result> register({
    required String registrationCode,
    required String identifier,
  }) async {
    _ensureWritesEnabled();
    // Registration has no v3 equivalent; it stays on the v2 mobile API.
    final data = await _postAbsolute(
      '${AppConfig.leaderboardApiBaseUrl}/register',
      body: {
        'registration_code': registrationCode,
        'identifier': identifier,
      },
    );
    return RegistrationV2Result.fromJson(data as Map<String, dynamic>);
  }

  Future<RankingResult> getRanking({int? seasonId, int? eventId}) async {
    final params = <String, String>{};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }

    final data = await _get('/me/ranking', queryParams: params);
    return RankingResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    bool? activeOnly,
    bool? onlyScheduled,
  }) async {
    final params = <String, String>{};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }
    // The authed participant's per-challenge `activities` + `activities_total`
    // are embedded server-side, resolved from the session token.
    if (activeOnly != null) {
      params['active_only'] = activeOnly ? '1' : '0';
    }
    if (onlyScheduled == true) {
      params['only_scheduled'] = '1'; // backend expects '1', not 'true'
    }

    final data = await _get('/challenges', queryParams: params);
    return (data as List)
        .map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LeaderboardResult> getLeaderboard({
    required int seasonId,
    int? eventId,
    int page = 1,
    int perPage = 50,
  }) async {
    final params = <String, String>{
      'season_id': seasonId.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (eventId != null) params['event_id'] = eventId.toString();

    final data = await _get('/leaderboard', queryParams: params);
    return LeaderboardResult.fromJson(data as Map<String, dynamic>);
  }

  Future<BreakdownResult> getBreakdown({int? seasonId, int? eventId}) async {
    final params = <String, String>{'include_activity': '1'};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }

    final data = await _get('/me/breakdown', queryParams: params);
    return BreakdownResult.fromJson(data as Map<String, dynamic>);
  }

  Future<EventPointsResult> getEventPoints({required int eventId}) async {
    final data = await _get('/event/points',
        queryParams: {'event_id': eventId.toString()});
    return EventPointsResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SeasonDto>> getSeasons({
    int? seasonId,
    bool? onlyActiveSeasons,
    bool? onlyCurrentSeason,
    bool? onlyActiveEvents,
    bool? onlyCurrentEvents,
  }) async {
    final params = <String, String>{
      'include_challenges': '0', // workaround: backend toISOString bug
    };
    if (seasonId != null) params['season_id'] = seasonId.toString();
    if (onlyActiveSeasons != null) {
      params['only_active_seasons'] = onlyActiveSeasons.toString();
    }
    if (onlyCurrentSeason != null) {
      params['only_current_season'] = onlyCurrentSeason.toString();
    }
    if (onlyActiveEvents != null) {
      params['only_active_events'] = onlyActiveEvents.toString();
    }
    if (onlyCurrentEvents != null) {
      params['only_current_events'] = onlyCurrentEvents.toString();
    }

    final data = await _get('/seasons', queryParams: params);
    return (data as List)
        .map((e) => SeasonDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Notifies the backend that a ZK Passport verification completed.
  ///
  /// Returns `true` on success. Treats HTTP 409 (duplicate) as success since
  /// the backend prevents duplicate claims.
  Future<bool> completeZkPassport({
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    _ensureWritesEnabled();
    try {
      await _post('/zkpassport/complete', body: {
        'challenge_id': challengeId,
        'wallet_address': walletAddress,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
        if (completedAt != null) 'completed_at': completedAt,
      });
      return true;
    } on LeaderboardApiException catch (e) {
      if (e.statusCode == 409) return true; // duplicate — already claimed
      rethrow;
    }
  }

  /// Fetches the currently published terms, including this participant's
  /// consent for that version.
  ///
  /// Returns null when the backend has nothing published (HTTP 404), which is a
  /// normal state and not an error — callers skip the terms flow entirely.
  /// Note a 404 also covers "participant not found"; both collapse to "no terms
  /// to show", which is the safe reading either way.
  Future<CurrentTerms?> getCurrentTerms() async {
    try {
      final data = await _get(
        '/terms/current',
        expectedStatuses: const {404},
      );
      return CurrentTerms.fromJson(data as Map<String, dynamic>);
    } on LeaderboardApiException catch (e) {
      if (e.statusCode == 404) return null; // nothing published
      rethrow;
    }
  }

  /// Records acceptance of a terms version.
  ///
  /// [termsVersionId] must be the `id` from [getCurrentTerms] — the backend
  /// rejects a stale or unpublished version with HTTP 422.
  Future<void> postTermsConsent({
    required int termsVersionId,
    required String appVersion,
  }) async {
    _ensureWritesEnabled();
    await _post(
      '/terms/consent',
      body: {
        'terms_version_id': termsVersionId,
        'status': TermsConsentStatus.accepted,
        'app_version': appVersion,
      },
      expectedStatuses: const {422},
    );
  }

  void dispose() => _http.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Adds the `Authorization: Bearer <token>` header when a session token is
  /// available, leaving [base] untouched otherwise (e.g. in tests without auth).
  Future<Map<String, String>> _authHeaders(Map<String, String> base) async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return base;
    return {...base, 'Authorization': 'Bearer $token'};
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
    Set<int> expectedStatuses = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final url = queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
    _log.trace('GET $url');

    final headers = await _authHeaders(_acceptJson);
    final resp = await _sendWithRetry(() => _http.get(url, headers: headers));
    return _parseEnvelope(resp, url, expectedStatuses: expectedStatuses);
  }

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
  }) =>
      _postAbsolute('$_baseUrl$path',
          body: body, expectedStatuses: expectedStatuses);

  Future<dynamic> _postAbsolute(
    String absoluteUrl, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
  }) async {
    final url = Uri.parse(absoluteUrl);
    _log.trace('POST $url');

    final headers = await _authHeaders(_jsonHeaders);
    final resp = await _send(
      () => _http.post(url, headers: headers, body: jsonEncode(body)),
    );
    return _parseEnvelope(resp, url, expectedStatuses: expectedStatuses);
  }

  void _ensureWritesEnabled() {
    if (_writesEnabled) {
      return;
    }

    throw LeaderboardApiException(
      503,
      _backendWritesDisabledMessage,
    );
  }

  Future<http.Response> _send(
    Future<http.Response> Function() fn, {
    bool reportErrors = true,
  }) async {
    try {
      return await fn().timeout(AppConfig.leaderboardApiTimeout);
    } catch (e, stackTrace) {
      _log.warn('Request failed: $e');
      // Only report to Sentry when the failure is terminal — transient errors
      // that a retry recovers from would otherwise be noise.
      if (reportErrors) {
        await SentryUtil.captureError(
          e,
          stackTrace,
          tag: 'leaderboard_api',
        );
      }
      rethrow;
    }
  }

  /// Sends an idempotent request, retrying transient failures with exponential
  /// backoff. Retries on connection errors/timeouts and on 429/5xx responses.
  ///
  /// Non-transient responses (e.g. 4xx other than 429, or any 2xx) are returned
  /// to the caller for normal parsing. Sentry only sees a transport error once
  /// the retries are exhausted; intermediate retryable HTTP statuses are not
  /// captured here (the final one is captured by [_parseEnvelope]).
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() fn,
  ) async {
    var attempt = 0;
    while (true) {
      final isLastAttempt = attempt >= _maxGetRetries;
      try {
        final resp = await _send(fn, reportErrors: isLastAttempt);
        if (!isLastAttempt && _isRetryableStatus(resp.statusCode)) {
          attempt++;
          _log.debug('Retrying GET after HTTP ${resp.statusCode} '
              '(attempt $attempt/$_maxGetRetries)');
          await Future.delayed(_backoff(attempt));
          continue;
        }
        return resp;
      } catch (e) {
        if (!isLastAttempt && _isRetryableError(e)) {
          attempt++;
          _log.debug('Retrying GET after error "$e" '
              '(attempt $attempt/$_maxGetRetries)');
          await Future.delayed(_backoff(attempt));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Exponential backoff for retry [attempt] (1-based): base, 2×base, 4×base…
  Duration _backoff(int attempt) => _retryBaseDelay * (1 << (attempt - 1));

  static bool _isRetryableStatus(int statusCode) =>
      statusCode == 429 || statusCode >= 500;

  static bool _isRetryableError(Object error) =>
      error is TimeoutException ||
      error is SocketException ||
      error is http.ClientException;

  /// Parses the `{success, data}` envelope.
  ///
  /// [expectedStatuses] lists non-2xx codes that carry meaning for the caller
  /// rather than signalling a fault (e.g. 404 = no terms published). Those still
  /// throw so the caller can branch, but they skip Sentry — reporting them would
  /// bury real errors under routine noise.
  Future<dynamic> _parseEnvelope(
    http.Response resp,
    Uri url, {
    Set<int> expectedStatuses = const {},
  }) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw LeaderboardApiException(
          resp.statusCode,
          decoded is Map
              ? (decoded['error'] as String? ?? 'Unexpected response format')
              : 'Unexpected response format',
          body: resp.body,
        );
      }
      return decoded['data'];
    }

    final message = _friendlyErrorMessage(resp);
    _log.warn('API error: $message', context: {
      'statusCode': resp.statusCode,
      'url': url.toString(),
    });

    if (!expectedStatuses.contains(resp.statusCode)) {
      await SentryUtil.captureMessageWithData(
        'Leaderboard API error',
        {
          'status_code': resp.statusCode,
          'url': url.toString(),
          'error_message': message,
        },
        level: SentryLevel.error,
      );
    }

    // An expired/invalid session token: clear it and let the app bounce back to
    // the auth landing. Still throws so the caller's normal error path runs.
    if (resp.statusCode == 401) {
      await _onUnauthorized?.call();
    }

    throw LeaderboardApiException(resp.statusCode, message, body: resp.body);
  }

  String _friendlyErrorMessage(http.Response resp) {
    String? detail;
    try {
      final parsed = jsonDecode(resp.body);
      if (parsed is Map) {
        detail = parsed['error'] as String? ??
            parsed['detail'] as String? ??
            parsed['message'] as String?;
      }
    } catch (_) {
      _log.debug('Could not parse error response JSON');
    }

    switch (resp.statusCode) {
      case 400:
        return detail ?? 'Invalid request. Please check your input.';
      case 401:
        return detail ?? 'Authentication required.';
      case 403:
        return detail ?? 'Access denied.';
      case 404:
        return detail ?? 'Resource not found.';
      case 409:
        return detail ?? 'Conflict — resource already exists.';
      case 422:
        return detail ?? 'The submitted data was rejected. Please try again.';
      case 429:
        return detail ?? 'Too many requests. Please try again later.';
      default:
        return detail ?? 'Request failed (HTTP ${resp.statusCode}).';
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final leaderboardApiServiceProvider = Provider<LeaderboardApiService>((ref) {
  final service = LeaderboardApiService(
    tokenProvider: () => ref.read(authTokenStoreProvider).read(),
    onUnauthorized: () =>
        ref.read(authStatusProvider.notifier).onUnauthorized(),
  );
  ref.onDispose(service.dispose);
  return service;
});
