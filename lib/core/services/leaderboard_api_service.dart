import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardApiService');
const _backendWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

class _EventPointsPaginationDrift implements Exception {
  const _EventPointsPaginationDrift(this.reason);

  final String reason;
}

class LeaderboardApiService {
  LeaderboardApiService({
    String? baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
    int? maxGetRetries,
    Duration? retryBaseDelay,
    Future<String?> Function()? tokenProvider,
    Future<void> Function(AuthCredentialLease credential)? onUnauthorized,
    Future<void> Function(int epoch)? onCredentialMissing,
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiBaseUrl,
        _http = httpClient ?? createAppHttpClient(),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly,
        _maxGetRetries = maxGetRetries ?? 2,
        _retryBaseDelay = retryBaseDelay ?? const Duration(milliseconds: 300),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized,
        _onCredentialMissing = onCredentialMissing;

  final String _baseUrl;
  final http.Client _http;
  final bool _writesEnabled;

  /// Resolves the current session token for the `Authorization` header, and the
  /// callback to run on a 401 (clear token, bounce to auth). Both optional so
  /// tests can construct the service without auth wiring. The callback
  /// receives the exact credential the failing request carried.
  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function(AuthCredentialLease credential)? _onUnauthorized;
  final Future<void> Function(int epoch)? _onCredentialMissing;

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

  /// Event scope is sent as both `season_event_id` (SV v4's name) and the
  /// legacy `event_id` (topochain v3's name); each backend reads its own key
  /// and ignores the other, so one binary works against either base URL.
  static void _addEventScope(Map<String, String> params, int eventId) {
    params['season_event_id'] = eventId.toString();
    params['event_id'] = eventId.toString();
  }

  Future<RankingResult> getRanking({
    int? seasonId,
    int? eventId,
    IdentityLease? authority,
  }) async {
    final params = <String, String>{};
    if (eventId != null) {
      _addEventScope(params, eventId);
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }

    final data = await _get(
      '/me/ranking',
      queryParams: params,
      authority: authority,
    );
    return RankingResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    bool? activeOnly,
    bool? onlyScheduled,
    IdentityLease? authority,
  }) async {
    final params = <String, String>{};
    if (eventId != null) {
      _addEventScope(params, eventId);
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

    final data = await _get(
      '/challenges',
      queryParams: params,
      authority: authority,
    );
    return (data as List)
        .map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LeaderboardResult> getLeaderboard({
    required int seasonId,
    int? eventId,
    int page = 1,
    int perPage = 50,
    IdentityLease? authority,
  }) async {
    final params = <String, String>{
      'season_id': seasonId.toString(),
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (eventId != null) _addEventScope(params, eventId);

    final data = await _get(
      '/leaderboard',
      queryParams: params,
      authority: authority,
    );
    return LeaderboardResult.fromJson(data as Map<String, dynamic>);
  }

  Future<BreakdownResult> getBreakdown({
    int? seasonId,
    int? eventId,
    IdentityLease? authority,
  }) async {
    final params = <String, String>{'include_activity': '1'};
    if (eventId != null) {
      _addEventScope(params, eventId);
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }

    final data = await _get(
      '/me/breakdown',
      queryParams: params,
      authority: authority,
    );
    return BreakdownResult.fromJson(data as Map<String, dynamic>);
  }

  Future<EventPointsResult> getEventPoints({
    required int eventId,
    AuthenticatedUserLease? authority,
  }) async {
    final owner =
        authority ?? AuthenticatedUserLease.capture(IdentitySnapshots.current);
    if (owner == null) throw const StaleAuthCredentialException();

    // Capture one exact token for the whole logical read. Every page and retry
    // revalidates this same credential immediately before transport, so page 2
    // can neither switch users nor silently adopt a replacement token.
    final auth = await _authHeaders(
      _acceptJson,
      authority: owner.identityLease,
    );
    if (auth.credential == null) {
      throw const StaleAuthCredentialException();
    }

    // FIXME(event-points-snapshot): metadata validation can detect common
    // pagination drift, but only a backend snapshot token or keyset cursor can
    // guarantee that all pages represent one ranking state.
    const maxSnapshotAttempts = 2;
    for (var attempt = 1; attempt <= maxSnapshotAttempts; attempt++) {
      try {
        return await _getEventPointsSnapshot(
          eventId: eventId,
          owner: owner,
          auth: auth,
        );
      } on _EventPointsPaginationDrift catch (drift) {
        if (attempt == maxSnapshotAttempts) {
          throw LeaderboardApiException(
            0,
            'Event points changed while pages were being read. '
            'Please retry.',
          );
        }
        _log.debug(
          'Event points pagination drifted; restarting the whole read',
          context: {'reason': drift.reason},
        );
      }
    }
    throw StateError('unreachable');
  }

  Future<EventPointsResult> _getEventPointsSnapshot({
    required int eventId,
    required AuthenticatedUserLease owner,
    required ({
      Map<String, String> headers,
      AuthCredentialLease? credential,
    }) auth,
  }) async {
    const perPage = 100;
    EventPointsResult? firstPage;
    final pointsByParticipant = <int, ParticipantPoints>{};
    var page = 1;
    var totalPages = 1;
    int? declaredTotalPages;
    int? declaredTotalParticipants;

    do {
      final params = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      _addEventScope(params, eventId);
      final envelope = await _getEnvelopeWithAuth(
        '/event/points',
        queryParams: params,
        auth: auth,
        authority: owner.identityLease,
      );
      if (!owner.isCurrent) throw const StaleAuthCredentialException();

      final data = envelope['data'];
      if (data is! Map<String, dynamic>) {
        throw LeaderboardApiException(0, 'Unexpected response format.');
      }
      final parsed = EventPointsResult.fromJson(data);
      final first = firstPage;
      if (first == null) {
        firstPage = parsed;
      } else if (parsed.eventId != first.eventId ||
          parsed.eventName != first.eventName ||
          parsed.eventTotalPoints != first.eventTotalPoints ||
          parsed.participantTotalPoints != first.participantTotalPoints) {
        throw const _EventPointsPaginationDrift(
          'event aggregate changed between pages',
        );
      }
      for (final points in parsed.totalPointsPerUser) {
        pointsByParticipant[points.participantId] = points;
      }
      final pagination = _eventPointsPagination(
        envelope: envelope,
        data: data,
        requestedPage: page,
        requestedPerPage: perPage,
      );
      if (declaredTotalPages != null &&
          pagination.totalPages != declaredTotalPages) {
        throw const _EventPointsPaginationDrift(
          'total page count changed between pages',
        );
      }
      if (declaredTotalParticipants != null &&
          pagination.totalParticipants != declaredTotalParticipants) {
        throw const _EventPointsPaginationDrift(
          'participant count changed between pages',
        );
      }
      declaredTotalPages ??= pagination.totalPages;
      declaredTotalParticipants ??= pagination.totalParticipants;
      totalPages = pagination.totalPages;
      page++;
    } while (page <= totalPages);

    final first = firstPage!;
    final expectedParticipants = declaredTotalParticipants;
    if (pointsByParticipant.length != expectedParticipants) {
      throw _EventPointsPaginationDrift(
        'read ${pointsByParticipant.length} unique participants, expected '
        '$expectedParticipants',
      );
    }
    return EventPointsResult(
      eventId: first.eventId,
      eventName: first.eventName,
      eventTotalPoints: first.eventTotalPoints,
      participantTotalPoints: first.participantTotalPoints,
      totalPointsPerUser: pointsByParticipant.values.toList(growable: false),
      totalParticipants: expectedParticipants,
    );
  }

  Future<List<SeasonDto>> getSeasons({
    int? seasonId,
    bool? onlyActiveSeasons,
    bool? onlyCurrentSeason,
    bool? onlyActiveEvents,
    bool? onlyCurrentEvents,
    IdentityLease? authority,
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

    final data = await _get(
      '/seasons',
      queryParams: params,
      authority: authority,
    );
    return (data as List)
        .map((e) => SeasonDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Notifies the backend that a ZK Passport verification completed.
  ///
  /// Returns `true` on success. A v4 409 is a REAL rejection (challenge no
  /// longer accepting completions, session already used by another claim,
  /// or proof already claimed) — true idempotency (same user re-posting the
  /// same completion) returns 200, so 409 must propagate as a failure. The
  /// old backend's "409 = duplicate = success" mapping would clear the
  /// pending completion and permanently discard a rejected claim.
  Future<bool> completeZkPassport({
    required AuthenticatedUserLease authority,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    _ensureWritesEnabled();
    final accountScope = authority.identityLease.accountScope;
    if (accountScope == null || accountScope.address != walletAddress) {
      throw ArgumentError.value(
        walletAddress,
        'walletAddress',
        'must match the account authorized for this completion',
      );
    }
    await _post(
      '/zkpassport/complete',
      body: {
        'challenge_id': challengeId,
        'wallet_address': walletAddress,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
        if (completedAt != null) 'completed_at': completedAt,
      },
      authority: authority.identityLease,
      deferErrorReporting: true,
    );
    return true;
  }

  /// Fetches (or allocates) this user's platform-assigned on-chain account
  /// for the current season.
  ///
  /// Idempotent server-side: migrated users and reinstalls on a new device
  /// get the SAME account back. 409 means the season's account pool is
  /// exhausted; 422 means no active season exists.
  Future<WalletProvisionResult> provisionWallet({
    required IdentityLease authority,
  }) async {
    _ensureWritesEnabled();
    final data = await _post(
      '/wallet/provision',
      body: const {},
      authority: authority,
    );
    return WalletProvisionResult.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches the currently published terms, including this participant's
  /// consent for that version.
  ///
  /// Returns null when the backend has nothing published (HTTP 404), which is a
  /// normal state and not an error — callers skip the terms flow entirely.
  /// Note a 404 also covers "participant not found"; both collapse to "no terms
  /// to show", which is the safe reading either way.
  Future<CurrentTerms?> getCurrentTerms({
    required AuthenticatedUserLease authority,
  }) async {
    try {
      final data = await _get(
        '/terms/current',
        expectedStatuses: const {404},
        authority: authority.identityLease,
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
    required AuthenticatedUserLease authority,
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
      authority: authority.identityLease,
    );
  }

  void dispose() => _http.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Adds the `Authorization: Bearer <token>` header when a session token is
  /// available, leaving [base] untouched otherwise (e.g. in tests without auth).
  Future<
      ({
        Map<String, String> headers,
        AuthCredentialLease? credential,
      })> _authHeaders(
    Map<String, String> base, {
    IdentityLease? authority,
  }) async {
    final identity = IdentitySnapshots.current;
    if (authority != null && !authority.isCurrent) {
      throw const StaleAuthCredentialException();
    }
    final token = await _tokenProvider?.call();
    if (!identity.sameScopeAs(IdentitySnapshots.current) ||
        (authority != null && !authority.isCurrent)) {
      throw const StaleAuthCredentialException();
    }
    if (token == null || token.isEmpty) {
      if (identity.isAuthenticated) {
        await _onCredentialMissing?.call(identity.epoch);
        throw const StaleAuthCredentialException();
      }
      return (headers: base, credential: null);
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
    AuthCredentialLease? credential,
    Future<T> Function() send, {
    IdentityLease? authority,
  }) async {
    if (authority != null && !authority.isCurrent) {
      throw const StaleAuthCredentialException();
    }
    if (credential == null) return send();
    final current = IdentitySnapshots.current;
    if (current.epoch != credential.epoch || !current.isAuthenticated) {
      throw const StaleAuthCredentialException();
    }
    final token = await _tokenProvider?.call();
    final afterRead = IdentitySnapshots.current;
    if (afterRead.epoch != credential.epoch ||
        !afterRead.isAuthenticated ||
        token != credential.token ||
        (authority != null && !authority.isCurrent)) {
      throw const StaleAuthCredentialException();
    }
    // No await between the final authority check and starting the transport.
    return send();
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
    Set<int> expectedStatuses = const {},
    IdentityLease? authority,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final url = queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
    _log.trace('GET $url');

    final auth = await _authHeaders(_acceptJson, authority: authority);
    final resp = await _sendWithRetry(
      () => _sendWithCurrentCredential(
        auth.credential,
        () => _http.get(url, headers: auth.headers),
        authority: authority,
      ),
    );
    return _parseEnvelope(resp, url,
        expectedStatuses: expectedStatuses, credential: auth.credential);
  }

  Future<Map<String, dynamic>> _getEnvelopeWithAuth(
    String path, {
    required Map<String, String> queryParams,
    required ({
      Map<String, String> headers,
      AuthCredentialLease? credential,
    }) auth,
    required IdentityLease authority,
  }) async {
    final url = Uri.parse('$_baseUrl$path').replace(
      queryParameters: queryParams,
    );
    _log.trace('GET $url');
    final resp = await _sendWithRetry(
      () => _sendWithCurrentCredential(
        auth.credential,
        () => _http.get(url, headers: auth.headers),
        authority: authority,
      ),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      await _parseEnvelope(resp, url, credential: auth.credential);
      throw StateError('unreachable');
    }
    return _decodeSuccessEnvelope(resp);
  }

  ({int totalPages, int totalParticipants}) _eventPointsPagination({
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> data,
    required int requestedPage,
    required int requestedPerPage,
  }) {
    final rawMeta = envelope['meta'] ?? data['pagination'];
    if (rawMeta is! Map) {
      throw LeaderboardApiException(
        0,
        'Event points response is missing pagination metadata.',
      );
    }
    final currentPage = _positiveInt(
      rawMeta['current_page'] ?? rawMeta['page'],
      allowZero: false,
    );
    final totalPages = _positiveInt(
      rawMeta['total_pages'] ?? rawMeta['last_page'],
      allowZero: true,
    );
    final totalParticipants = _positiveInt(
      rawMeta['total'],
      allowZero: true,
    );
    final dataTotalParticipants = _positiveInt(
      data['total_participants'],
      allowZero: true,
    );
    final responsePerPage = _positiveInt(
      rawMeta['per_page'],
      allowZero: false,
    );
    if (currentPage != requestedPage ||
        totalPages == null ||
        totalParticipants == null ||
        dataTotalParticipants == null ||
        responsePerPage != requestedPerPage ||
        (totalPages > 0 && currentPage! > totalPages)) {
      throw LeaderboardApiException(
        0,
        'Event points response has invalid pagination metadata.',
      );
    }
    if (totalParticipants != dataTotalParticipants) {
      throw const _EventPointsPaginationDrift(
        'metadata and payload participant counts differ',
      );
    }
    return (
      totalPages: totalPages == 0 ? 1 : totalPages,
      totalParticipants: totalParticipants,
    );
  }

  int? _positiveInt(Object? value, {required bool allowZero}) {
    final parsed = switch (value) {
      int value => value,
      num value when value.isFinite && value == value.truncateToDouble() =>
        value.toInt(),
      String value => int.tryParse(value),
      _ => null,
    };
    if (parsed == null || parsed < (allowZero ? 0 : 1)) return null;
    return parsed;
  }

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
    IdentityLease? authority,
    bool deferErrorReporting = false,
  }) =>
      _postAbsolute('$_baseUrl$path',
          body: body,
          expectedStatuses: expectedStatuses,
          authority: authority,
          deferErrorReporting: deferErrorReporting);

  Future<dynamic> _postAbsolute(
    String absoluteUrl, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
    IdentityLease? authority,
    bool deferErrorReporting = false,
  }) async {
    final url = Uri.parse(absoluteUrl);
    _log.trace('POST $url');

    final auth = await _authHeaders(_jsonHeaders, authority: authority);
    final resp = await _send(
      () => _sendWithCurrentCredential(
        auth.credential,
        () => _http.post(
          url,
          headers: auth.headers,
          body: jsonEncode(body),
        ),
        authority: authority,
      ),
    );
    return _parseEnvelope(resp, url,
        expectedStatuses: expectedStatuses,
        credential: auth.credential,
        deferErrorReporting: deferErrorReporting);
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
    } on StaleAuthCredentialException {
      rethrow;
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
    AuthCredentialLease? credential,
    bool deferErrorReporting = false,
  }) async {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = _decodeSuccessEnvelope(resp);
      return decoded['data'];
    }

    final message = _friendlyErrorMessage(resp);
    _log.warn('API error: $message', context: {
      'statusCode': resp.statusCode,
      'url': url.toString(),
    });

    if (!expectedStatuses.contains(resp.statusCode)) {
      final reporting = SentryUtil.captureMessageWithData(
        'Leaderboard API error',
        {
          'status_code': resp.statusCode,
          'url': url.toString(),
          'error_message': message,
        },
        level: SentryLevel.error,
      );
      if (deferErrorReporting) {
        unawaited(reporting);
      } else {
        await reporting;
      }
    }

    // An expired/invalid session token: clear it and let the app bounce back
    // to the auth landing. Still throws so the caller's normal error path
    // runs. Only the exact credential attached to this request may be
    // invalidated; an anonymous request has no session to clear.
    if (resp.statusCode == 401 && credential != null) {
      await _onUnauthorized?.call(credential);
    }

    throw LeaderboardApiException(resp.statusCode, message, body: resp.body);
  }

  Map<String, dynamic> _decodeSuccessEnvelope(http.Response resp) {
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
    return decoded;
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
    onUnauthorized: (credential) => ref
        .read(identityProvider.notifier)
        .onUnauthorized(credential: credential),
    onCredentialMissing: (epoch) =>
        ref.read(identityProvider.notifier).onCredentialMissing(epoch: epoch),
  );
  ref.onDispose(service.dispose);
  return service;
});
