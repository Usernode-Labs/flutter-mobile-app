import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';

final _log = LoggingService.instance.withTag('usernode/LeaderboardApiService');

class LeaderboardApiService {
  LeaderboardApiService({String? baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl ?? AppConfig.leaderboardApiBaseUrl,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

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
    final data = await _post('/register', body: {
      'registration_code': registrationCode,
      'identifier': identifier,
    });
    return RegistrationV2Result.fromJson(data as Map<String, dynamic>);
  }

  Future<RankingResult> getRanking({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    final params = <String, String>{
      'participant_id': participantId.toString(),
    };
    if (seasonId != null) params['season_id'] = seasonId.toString();
    if (eventId != null) params['event_id'] = eventId.toString();

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
    if (seasonId != null) params['season_id'] = seasonId.toString();
    if (eventId != null) params['event_id'] = eventId.toString();
    if (activeOnly != null) params['active_only'] = activeOnly.toString();
    if (onlyScheduled == true) params['only_scheduled'] = '1';

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

  Future<BreakdownResult> getBreakdown({
    required int participantId,
    int? seasonId,
    int? eventId,
  }) async {
    final params = <String, String>{
      'participant_id': participantId.toString(),
      'include_activity': '1',
    };
    if (seasonId != null) params['season_id'] = seasonId.toString();
    if (eventId != null) params['event_id'] = eventId.toString();

    final data = await _get('/me/breakdown', queryParams: params);
    return BreakdownResult.fromJson(data as Map<String, dynamic>);
  }

  Future<EventPointsResult> getEventPoints({
    required int eventId,
    required int participantId,
  }) async {
    final params = <String, String>{
      'event_id': eventId.toString(),
      'participant_id': participantId.toString(),
    };

    final data = await _get('/event/points', queryParams: params);
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
    required int participantId,
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
  }) async {
    try {
      await _post('/zkpassport/complete', body: {
        'participant_id': participantId,
        'challenge_id': challengeId,
        'wallet_address': walletAddress,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
      });
      return true;
    } on LeaderboardApiException catch (e) {
      if (e.statusCode == 409) return true; // duplicate — already claimed
      rethrow;
    }
  }

  void dispose() => _http.close();

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final url = queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
    _log.trace('GET $url');

    final resp = await _send(() => _http.get(url, headers: _acceptJson));
    return _parseEnvelope(resp, url);
  }

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _log.trace('POST $url');

    final resp = await _send(
      () => _http.post(url, headers: _jsonHeaders, body: jsonEncode(body)),
    );
    return _parseEnvelope(resp, url);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() fn,
  ) async {
    try {
      return await fn().timeout(AppConfig.leaderboardApiTimeout);
    } catch (e, stackTrace) {
      _log.warn('Request failed: $e');
      await SentryUtil.captureError(
        e,
        stackTrace,
        tag: 'leaderboard_api',
      );
      rethrow;
    }
  }

  Future<dynamic> _parseEnvelope(http.Response resp, Uri url) async {
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

    await SentryUtil.captureMessageWithData(
      'Leaderboard API error',
      {
        'status_code': resp.statusCode,
        'url': url.toString(),
        'error_message': message,
      },
      level: SentryLevel.error,
    );

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
  final service = LeaderboardApiService();
  ref.onDispose(service.dispose);
  return service;
});
