enum ActivityApiErrorCode {
  activityNotFound('activity_not_found'),
  identityBindingRevoked('identity_binding_revoked'),
  internalError('internal_error'),
  invalidAssertion('invalid_assertion'),
  invalidExchangeRequest('invalid_exchange_request'),
  invalidFeedCursor('invalid_feed_cursor'),
  invalidFeedLimit('invalid_feed_limit'),
  invalidFeedQuery('invalid_feed_query'),
  invalidReadRequest('invalid_read_request'),
  invalidSyncCursor('invalid_sync_cursor'),
  invalidSyncLimit('invalid_sync_limit'),
  invalidSyncQuery('invalid_sync_query'),
  unauthorizedConsumer('unauthorized_consumer');

  const ActivityApiErrorCode(this.wireValue);

  final String wireValue;

  static ActivityApiErrorCode? tryParse(String value) {
    for (final code in values) {
      if (code.wireValue == value) return code;
    }
    return null;
  }
}

class ActivityApiException implements Exception {
  const ActivityApiException({
    required this.statusCode,
    required this.code,
  });

  final int statusCode;
  final ActivityApiErrorCode code;

  @override
  String toString() =>
      'ActivityApiException(statusCode: $statusCode, code: ${code.wireValue})';
}

class ActivityProtocolException implements Exception {
  const ActivityProtocolException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ActivityProtocolException($message)';
}

class ActivitySessionRequiredException implements Exception {
  const ActivitySessionRequiredException();

  @override
  String toString() => 'ActivitySessionRequiredException()';
}

class ActivitySessionChangedException implements Exception {
  const ActivitySessionChangedException();

  @override
  String toString() => 'ActivitySessionChangedException()';
}

class ActivityWriteDisabledException implements Exception {
  const ActivityWriteDisabledException();

  @override
  String toString() => 'ActivityWriteDisabledException()';
}
