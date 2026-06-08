import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
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
}

/// Fire-and-forget client for `POST /api/v2/mobile/logs/{participant}`.
///
/// Public, unauthenticated endpoint that always returns 200 with
/// `{"continue": bool}`. Per the spec: retry only network/5xx (exp backoff,
/// ~3 tries); never retry a 200 or 404. This client never throws — every path
/// resolves to a [LogShareOutcome] so logging can never crash the caller.
class LogShareService {
  /// Defaults to a plain [http.Client] — deliberately NOT the app's logging
  /// client, so these share POSTs aren't captured into the debug buffer (which
  /// would feed them back into the next flush, an endless self-referential loop).
  LogShareService({String? baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl ?? AppConfig.leaderboardApiBaseUrl,
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  static const _maxAttempts = 3;
  static const _baseBackoff = Duration(seconds: 1);
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// POST [body] for [participantId]. See [LogShareOutcome] for semantics.
  Future<LogShareOutcome> postLogs({
    required int participantId,
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('$_baseUrl/logs/$participantId');
    final payload = jsonEncode(body);
    var backoff = _baseBackoff;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final resp = await _http
            .post(url, headers: _headers, body: payload)
            .timeout(AppConfig.leaderboardApiTimeout);

        if (resp.statusCode == 404) {
          _log.warn('Bad participant id ($participantId); stopping log share');
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
