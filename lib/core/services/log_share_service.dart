import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/session_authority_gateway.dart';
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

  /// The sharing session's exact credential is no longer admitted.
  stale,
}

/// Fire-and-forget client for `POST /api/v3/mobile/logs`.
///
/// Session-authenticated endpoint (the participant is resolved from the token)
/// that returns 200 with `{"continue": bool}`. Per the spec: retry only
/// network/5xx (exp backoff, ~3 tries); never retry a 200 or 4xx. This client
/// never throws — every path resolves to a [LogShareOutcome] so logging can
/// never crash the caller.
class LogShareService {
  /// Transport comes from the session authority rather than the app's logging
  /// client, so share POSTs cannot feed themselves back into the debug buffer.
  LogShareService({
    String? baseUrl,
    SessionAuthorityCredentialRequestSender? credentialRequestSender,
    Duration retryBackoff = const Duration(seconds: 1),
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiBaseUrl,
        _credentialRequestSender = credentialRequestSender,
        _retryBackoff = retryBackoff;

  final String _baseUrl;
  final SessionAuthorityCredentialRequestSender? _credentialRequestSender;
  final Duration _retryBackoff;

  static const _maxAttempts = 3;
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// POST [body] as the authed participant. See [LogShareOutcome] for semantics.
  /// Every retry uses the same immutable [credential], so it cannot silently
  /// move to a replacement session.
  Future<LogShareOutcome> postLogs({
    required Map<String, dynamic> body,
    required AuthCredentialLease credential,
  }) async {
    final sender = _credentialRequestSender;
    if (sender == null) return LogShareOutcome.stale;
    final url = Uri.parse('$_baseUrl/logs');
    final headers = {
      ..._headers,
      'Authorization': 'Bearer ${credential.token}',
    };
    final payload = jsonEncode(body);
    var backoff = _retryBackoff;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final request = http.Request('POST', url)
          ..headers.addAll(headers)
          ..body = payload;
        final streamed = await sender(
          credential: credential,
          request: request,
        ).timeout(AppConfig.leaderboardApiTimeout);
        final resp = await http.Response.fromStream(streamed)
            .timeout(AppConfig.leaderboardApiTimeout);
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
      } on StaleAuthCredentialException {
        return LogShareOutcome.stale;
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
}
