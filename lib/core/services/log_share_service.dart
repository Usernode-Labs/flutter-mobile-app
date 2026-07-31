import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag('usernode/LogShareService');

/// Result of a single batch POST to the team-logs endpoint.
enum LogShareOutcome {
  /// Stored — advance the cursor and keep sending (`{"continue": true}`).
  keepGoing,

  /// Stop sending for this session: either `{"continue": false}` (stored or
  /// not, the server asked us to stop) or 404 (bad participant id). Not retried.
  stop,

  /// Transient failure (network error or 5xx after retries). The cursor is kept
  /// so the same batch is re-sent on the next flush.
  failed,

  /// The sharing session's exact identity/token pair was replaced.
  stale,
}

typedef LogShareCredentialSender = Future<http.Response?> Function(
  AuthCredentialLease credential,
  Future<http.Response> Function() send,
);

/// Fire-and-forget client for `POST /api/v3/mobile/logs`.
///
/// Session-authenticated endpoint (the participant is resolved from the token)
/// that returns 200 with `{"continue": bool}`. Per the spec: retry only
/// network/5xx (exp backoff, ~3 tries); never retry a 200 or 4xx. This client
/// never throws — every path resolves to a [LogShareOutcome] so logging can
/// never crash the caller.
class LogShareService {
  /// Defaults to a plain [http.Client] — deliberately NOT the app's logging
  /// client, so these share POSTs aren't captured into the debug buffer (which
  /// would feed them back into the next flush, an endless self-referential loop).
  LogShareService({
    String? baseUrl,
    http.Client? httpClient,
    Duration retryBackoff = const Duration(seconds: 1),
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiBaseUrl,
        _http = httpClient ?? http.Client(),
        _retryBackoff = retryBackoff;

  final String _baseUrl;
  final http.Client _http;
  final Duration _retryBackoff;

  static const _maxAttempts = 3;
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// POST [body] as the authed participant. See [LogShareOutcome] for semantics.
  /// The captured [credential] is revalidated at every send effect so retries
  /// cannot silently move to a replacement session.
  Future<LogShareOutcome> postLogs({
    required Map<String, dynamic> body,
    required AuthCredentialLease credential,
    required LogShareCredentialSender sendIfCredentialCurrent,
  }) async {
    final url = Uri.parse('$_baseUrl/logs');
    final headers = {
      ..._headers,
      'Authorization': 'Bearer ${credential.token}',
    };
    final payload = jsonEncode(body);
    var backoff = _retryBackoff;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final resp = await sendIfCredentialCurrent(
          credential,
          () => _http
              .post(url, headers: headers, body: payload)
              .timeout(AppConfig.leaderboardApiTimeout),
        );
        if (resp == null) {
          return LogShareOutcome.stale;
        }
        if (resp.statusCode == 401 || resp.statusCode == 404) {
          _log.warn('Log share rejected (${resp.statusCode}); stopping');
          return LogShareOutcome.stop;
        }
        if (resp.statusCode >= 500) {
          if (attempt < _maxAttempts) {
            await Future<void>.delayed(backoff);
            backoff *= 2;
            continue;
          }
          _log.warn('Server error ${resp.statusCode} after $attempt attempts');
          return LogShareOutcome.failed;
        }
        if (resp.statusCode == 200) {
          return _shouldContinue(resp.body)
              ? LogShareOutcome.keepGoing
              : LogShareOutcome.stop;
        }
        // Any other 4xx: spec says don't retry. Treat as a transient failure
        // (cursor kept) so a misconfiguration doesn't silently drop logs.
        _log.warn('Unexpected status ${resp.statusCode}');
        return LogShareOutcome.failed;
      } catch (e) {
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(backoff);
          backoff *= 2;
          continue;
        }
        _log.warn('Log share request failed after $attempt attempts: $e');
        return LogShareOutcome.failed;
      }
    }
    return LogShareOutcome.failed;
  }

  /// Defaults to stop on any unparseable/unexpected body — safer than looping.
  bool _shouldContinue(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      return decoded is Map && decoded['continue'] == true;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _http.close();
}
