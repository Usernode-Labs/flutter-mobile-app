import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/debug_mode.dart';
import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/services/http_debug_log_store.dart';

/// An [http.Client] that records each exchange into [HttpDebugLogStore] when
/// Debug Mode is on, and is otherwise a transparent pass-through.
///
/// The Debug Mode check ([DebugModeStorage.isEnabled]) is a synchronous field
/// read, so the disabled path adds no measurable overhead — it forwards to the
/// inner client untouched. When enabled, the streamed response is buffered so
/// it can be logged and then re-emitted to the caller unchanged.
///
/// Captured headers/bodies are redacted/truncated by [HttpLogEntry] before
/// storage; see `http_debug_log_store.dart`.
class LoggingHttpClient extends http.BaseClient {
  LoggingHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!DebugModeStorage.isEnabled) {
      return _inner.send(request);
    }

    // Capture ownership before the transport begins. The response may finish
    // after logout or another participant signs in; resolving ownership at
    // completion would then attribute the old exchange to the new session.
    final owner = _captureAuthenticatedOwner();

    // Only plain (non-streamed/non-multipart) requests expose a readable body.
    final requestBody = request is http.Request ? request.body : null;
    final sw = Stopwatch()..start();

    try {
      final response = await _inner.send(request);
      // Buffer the body so we can both log it and hand it back to the caller.
      final bytes = await response.stream.toBytes();
      sw.stop();

      HttpDebugLogStore.instance.add(
        HttpLogEntry(
          timestamp: DateTime.now(),
          method: request.method,
          url: request.url.toString(),
          owner: owner,
          statusCode: response.statusCode,
          durationMs: sw.elapsedMilliseconds,
          requestHeaders: request.headers,
          // Redact BEFORE truncating so a sensitive value can't survive by
          // straddling the truncation boundary. HttpLogEntry redacts again
          // (idempotently) as a chokepoint.
          requestBody: truncateBody(redactSensitiveBodyFields(requestBody)),
          responseHeaders: response.headers,
          responseBody:
              truncateBody(redactSensitiveBodyFields(_decodeBody(bytes))),
        ),
      );

      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      sw.stop();
      HttpDebugLogStore.instance.add(
        HttpLogEntry(
          timestamp: DateTime.now(),
          method: request.method,
          url: request.url.toString(),
          owner: owner,
          durationMs: sw.elapsedMilliseconds,
          requestHeaders: request.headers,
          requestBody: truncateBody(redactSensitiveBodyFields(requestBody)),
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Best-effort decode for display. Binary payloads are tolerated via
  /// [utf8.decode]'s `allowMalformed`; [truncateBody] caps the result later.
  String _decodeBody(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '<${bytes.length} bytes>';
    }
  }

  @override
  void close() => _inner.close();
}

AuthenticatedUserScope? _captureAuthenticatedOwner() {
  final identity = IdentitySnapshots.current;
  final participantId = identity.participantId;
  if (!identity.isAuthenticated || participantId == null) return null;
  return AuthenticatedUserScope(participantId: participantId);
}

/// Build the app's standard HTTP client.
///
/// Always returns a [LoggingHttpClient]; capture is gated at request time by
/// [DebugModeStorage.isEnabled], so this is safe (and cheap) to use everywhere
/// a plain `http.Client()` was previously constructed.
http.Client createAppHttpClient() => LoggingHttpClient(http.Client());
