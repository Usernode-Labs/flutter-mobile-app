import 'package:flutter/foundation.dart';

import 'package:crypto_mobile_app/core/identity/identity_scope.dart';

/// Header names whose values are masked before an entry is stored or shared.
/// Lower-cased; matching is case-insensitive.
const _sensitiveHeaders = <String>{
  'authorization',
  'proxy-authorization',
  'cookie',
  'set-cookie',
  'x-api-key',
  'x-auth-token',
  'api-key',
};

/// JSON field names whose values are masked in captured request/response
/// bodies. Credentials and key material must never reach the log store: the
/// buffer is user-visible in Debug Mode and uploadable via log sharing.
/// Matching is case-insensitive and matches exact key names only
/// (`"token"` masks `"token": "…"`, not `"token_type": "…"`).
const _sensitiveBodyFields = <String>{
  'secret_key',
  'private_key',
  'secret',
  'token',
  'session_token',
  'set_password_token',
  'password',
  // Common aliases carrying the same plaintext credential — setPassword
  // sends `password_confirmation` alongside `password`.
  'password_confirmation',
  'new_password',
  'current_password',
  'old_password',
  'passphrase',
  'code',
  'otp',
  'api_key',
};

/// Matches `"<sensitive-key>" : <string|number|bool|null>` in a JSON body,
/// tolerating escaped quotes inside string values. Applied textually (no
/// jsonDecode) so it also works on truncated or malformed payloads.
final _sensitiveBodyFieldRe = RegExp(
  '"(${_sensitiveBodyFields.join('|')})"'
  r'\s*:\s*(?:"(?:\\.|[^"\\])*"?|-?\d[\d.eE+-]*|true|false|null)',
  caseSensitive: false,
);

/// Per-body capture cap. Bodies longer than this are truncated so a single
/// large response can't dominate (or blow past) the buffer's byte budget.
const int _maxBodyChars = 8 * 1024;

const String _redactedMarker = '***';
const String _truncatedSuffix = '…[truncated]';

/// Redact sensitive header values in [headers], returning a new map.
Map<String, String> redactHeaders(Map<String, String> headers) {
  return headers.map(
    (k, v) => MapEntry(
        k, _sensitiveHeaders.contains(k.toLowerCase()) ? _redactedMarker : v),
  );
}

/// Mask the values of [_sensitiveBodyFields] in a JSON(-ish) [body].
/// Idempotent; non-JSON bodies without matching patterns pass through
/// unchanged. Run BEFORE [truncateBody] so a secret can't survive by
/// straddling the truncation boundary.
String? redactSensitiveBodyFields(String? body) {
  if (body == null || body.isEmpty) return body;
  return body.replaceAllMapped(
    _sensitiveBodyFieldRe,
    (m) => '"${m[1]}":"$_redactedMarker"',
  );
}

/// Truncate [body] to [_maxBodyChars], appending a marker when shortened.
/// `null` (e.g. a streamed/unknown body) is passed through unchanged.
String? truncateBody(String? body) {
  if (body == null) return null;
  if (body.length <= _maxBodyChars) return body;
  return body.substring(0, _maxBodyChars) + _truncatedSuffix;
}

/// One captured HTTP exchange. All fields are already redacted/truncated; this
/// type holds presentation-ready data only.
@immutable
class HttpLogEntry {
  HttpLogEntry({
    required this.timestamp,
    required this.method,
    required this.url,
    this.owner,
    this.statusCode,
    this.durationMs,
    Map<String, String> requestHeaders = const {},
    String? requestBody,
    Map<String, String> responseHeaders = const {},
    String? responseBody,
    this.error,
  })  : requestHeaders = redactHeaders(requestHeaders),
        responseHeaders = redactHeaders(responseHeaders),
        // Chokepoint: no producer can get an unredacted body into the store.
        // Producers should still redact before truncating (see
        // LoggingHttpClient) — this pass is idempotent defense in depth.
        requestBody = redactSensitiveBodyFields(requestBody),
        responseBody = redactSensitiveBodyFields(responseBody);

  final DateTime timestamp;
  final String method;
  final String url;

  /// Authenticated participant that owned the request when it began.
  ///
  /// Null means the exchange began outside an authenticated identity. The
  /// owner is kept out of [toJsonEvent]: the log-share endpoint resolves the
  /// participant from its Bearer token, and callers must filter entries to
  /// that credential's owner before serialization.
  final AuthenticatedUserScope? owner;

  /// Null while the request is in flight or when it threw before a response.
  final int? statusCode;
  final int? durationMs;

  final Map<String, String> requestHeaders;
  final String? requestBody;
  final Map<String, String> responseHeaders;
  final String? responseBody;

  /// Set when the request threw (timeout, socket error, …) instead of returning.
  final String? error;

  bool get isError =>
      error != null || (statusCode != null && statusCode! >= 400);

  /// Approximate in-memory footprint, used by [HttpDebugLogStore] for its byte
  /// budget. UTF-16 code units (2 bytes each) overestimate slightly, which is
  /// the safe direction for a cap.
  late final int approxBytes = _computeBytes();

  int _computeBytes() {
    var chars = method.length + url.length + (error?.length ?? 0);
    chars += requestBody?.length ?? 0;
    chars += responseBody?.length ?? 0;
    for (final e in requestHeaders.entries) {
      chars += e.key.length + e.value.length;
    }
    for (final e in responseHeaders.entries) {
      chars += e.key.length + e.value.length;
    }
    return chars * 2;
  }

  /// JSON form for the `events` array when sharing logs with the backend.
  /// Mirrors the redacted/truncated fields exactly — no raw data leaks here.
  Map<String, dynamic> toJsonEvent() => {
        'timestamp': timestamp.toUtc().toIso8601String(),
        'method': method,
        'url': url,
        if (statusCode != null) 'status_code': statusCode,
        if (durationMs != null) 'duration_ms': durationMs,
        if (requestHeaders.isNotEmpty) 'request_headers': requestHeaders,
        if (requestBody != null) 'request_body': requestBody,
        if (responseHeaders.isNotEmpty) 'response_headers': responseHeaders,
        if (responseBody != null) 'response_body': responseBody,
        if (error != null) 'error': error,
      };

  /// Multi-line, human-readable form used for copy/share.
  String toLogText() {
    final b = StringBuffer()
      ..writeln('[${timestamp.toIso8601String()}] $method $url')
      ..writeln(
        'status: ${statusCode ?? '-'}'
        '${durationMs != null ? '  (${durationMs}ms)' : ''}',
      );
    if (error != null) b.writeln('error: $error');
    if (requestHeaders.isNotEmpty) {
      b.writeln('> request headers:');
      requestHeaders.forEach((k, v) => b.writeln('>   $k: $v'));
    }
    if (requestBody != null && requestBody!.isNotEmpty) {
      b
        ..writeln('> request body:')
        ..writeln(requestBody);
    }
    if (responseHeaders.isNotEmpty) {
      b.writeln('< response headers:');
      responseHeaders.forEach((k, v) => b.writeln('<   $k: $v'));
    }
    if (responseBody != null && responseBody!.isNotEmpty) {
      b
        ..writeln('< response body:')
        ..writeln(responseBody);
    }
    return b.toString();
  }
}

/// In-memory ring buffer of recent [HttpLogEntry]s, capped by total bytes.
///
/// **Ephemeral**: entries live in RAM only and are lost on app restart — this
/// is a debugging aid, not persisted telemetry. When [add]ing would push the
/// total over [maxBytes], the oldest entries are evicted (FIFO) until it fits;
/// a single oversized entry is still kept (it has already been body-truncated).
///
/// A [ChangeNotifier] so the viewer rebuilds live as requests arrive.
class HttpDebugLogStore extends ChangeNotifier {
  HttpDebugLogStore._();
  static final HttpDebugLogStore instance = HttpDebugLogStore._();

  /// 1 MB byte budget (matches the product requirement).
  static const int maxBytes = 1024 * 1024;

  final List<({int sequence, HttpLogEntry entry})> _entries = [];
  int _totalBytes = 0;

  /// Monotonic count of every entry ever [add]ed, unaffected by eviction.
  /// Used as a stable cursor for incremental log sharing: callers remember a
  /// value of [totalAdded] and later ask for [entriesAdded] since it.
  int _totalAdded = 0;

  /// Unscoped newest-first snapshot for store/client unit tests only.
  @visibleForTesting
  List<HttpLogEntry> get debugEntries =>
      _entries.reversed.map((stored) => stored.entry).toList(growable: false);

  /// Newest-first snapshot owned by exactly [owner].
  List<HttpLogEntry> entriesForOwner(AuthenticatedUserScope owner) =>
      _entries.reversed
          .map((stored) => stored.entry)
          .where((entry) => entry.owner == owner)
          .toList(growable: false);

  /// Entries this authenticated viewer may inspect. Anonymous viewers never
  /// inherit a shared pre-auth/guest bucket: those exchanges can contain a
  /// previous person's login identifiers even after credential redaction.
  List<HttpLogEntry> entriesVisibleTo(AuthenticatedUserScope? viewer) =>
      viewer == null ? const [] : entriesForOwner(viewer);

  int get totalBytes => _totalBytes;

  /// See [_totalAdded].
  int get totalAdded => _totalAdded;

  /// Entries added since [cursor] (a prior [totalAdded] value), oldest-first.
  ///
  /// Entries evicted from the buffer since [cursor] are silently skipped — the
  /// caller gets whatever is still retained, never duplicates. Returns an empty
  /// list when nothing new (or everything new) has been evicted.
  List<HttpLogEntry> _entriesAdded(int cursor) {
    return _entries
        .where((stored) => stored.sequence > cursor)
        .map((stored) => stored.entry)
        .toList(growable: false);
  }

  /// Entries added since [cursor] that belong to exactly [owner], oldest-first.
  ///
  /// The cursor remains the global [totalAdded] position. This lets a sharing
  /// session advance past foreign or anonymous entries without inventing a
  /// second cursor whose offsets would diverge as the ring buffer evicts data.
  List<HttpLogEntry> entriesAddedForOwner(
    int cursor,
    AuthenticatedUserScope owner,
  ) =>
      _entriesAdded(cursor)
          .where((entry) => entry.owner == owner)
          .toList(growable: false);

  void add(HttpLogEntry entry) {
    _totalAdded++;
    _entries.add((sequence: _totalAdded, entry: entry));
    _totalBytes += entry.approxBytes;
    // Evict oldest until within budget, but always keep the just-added entry.
    while (_totalBytes > maxBytes && _entries.length > 1) {
      final removed = _entries.removeAt(0);
      _totalBytes -= removed.entry.approxBytes;
    }
    notifyListeners();
  }

  @visibleForTesting
  void clearForTesting() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _totalBytes = 0;
    notifyListeners();
  }

  /// Clears only entries visible to [owner], preserving other participants'
  /// and anonymous diagnostics. Per-entry sequence numbers keep incremental
  /// sharing cursors correct even when this removes rows from the middle.
  void clearForOwner(AuthenticatedUserScope owner) {
    var removedBytes = 0;
    _entries.removeWhere((stored) {
      if (stored.entry.owner != owner) return false;
      removedBytes += stored.entry.approxBytes;
      return true;
    });
    if (removedBytes == 0) return;
    _totalBytes -= removedBytes;
    notifyListeners();
  }

  /// The authenticated [owner]'s buffer rendered as text, newest first.
  String toExportTextForOwner(AuthenticatedUserScope owner) =>
      entriesForOwner(owner).map((e) => e.toLogText()).join('\n');
}
