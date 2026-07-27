const validActivityToken = 'act1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

Map<String, dynamic> validActivitySessionJson() => {
      'accessToken': validActivityToken,
      'tokenType': 'Bearer',
      'expiresAt': '2030-07-27T12:00:00Z',
    };

Map<String, dynamic> validActivityItemJson({
  String status = 'succeeded',
  String runMode = 'build',
  Map<String, dynamic>? facts,
  String? policyId,
  String? attention,
  Object? readAt,
  String inboxSequence = '1',
  String syncSequence = '6',
  int version = 2,
}) {
  final resolvedFacts = facts ??
      switch (status) {
        'needs_input' => {'runMode': runMode, 'inputKind': 'clarification'},
        'succeeded' => {'runMode': runMode, 'result': 'code'},
        'failed' => {
            'runMode': runMode,
            'failureStage': 'execution',
            'artifactsAvailable': false,
          },
        'cancelled' => {
            'runMode': runMode,
            'cancellationReason': 'explicit_stop',
          },
        _ => {'runMode': runMode},
      };
  final resolvedPolicy = policyId ??
      switch (status) {
        'needs_input' => 'social.dev_run.needs_input.v1',
        'succeeded' => 'social.dev_run.succeeded.v1',
        'failed' => 'social.dev_run.failed.v1',
        'cancelled' => 'social.dev_run.cancelled.v1',
        _ => 'social.dev_run.unknown.v1',
      };
  final resolvedAttention =
      attention ?? (status == 'cancelled' ? 'receipt' : 'unread');

  return {
    'inboxSequence': inboxSequence,
    'syncSequence': syncSequence,
    'defaultAttention': resolvedAttention,
    'readAt': readAt,
    'activityEvent': {
      'envelopeVersion': 1,
      'ledgerId': 'activity-test',
      'activityEventId': '0190f58e-6570-7b91-b633-1a695d00a001',
      'source': {
        'system': 'social',
        'producerId': 'social-dev',
        'trustClass': 'first_party_server',
      },
      'recipientResolution': {
        'authority': 'source_binding',
        'reference': 'social-binding-42',
        'subject': '42',
      },
      'contractId': 'social.dev_run.transition.v1',
      'appliedPolicyId': resolvedPolicy,
      'ingestedAt': '2026-07-17T12:05:01Z',
      'privacy': 'private_preview',
      'retentionClass': 'account_activity',
      'sourceEvent': {
        'envelopeVersion': 1,
        'sourceEventId': 'social.dev_run:7:314:$version',
        'kind': 'social.dev_run.transition',
        'schemaVersion': 1,
        'recipient': {
          'relation': 'social.user',
          'subject': '42',
          'scope': 'account',
        },
        'resource': {
          'type': 'dev_session',
          'id': '314',
          'version': version,
        },
        'occurredAt': '2026-07-17T12:05:00Z',
        'status': status,
        'canonicality': 'source_confirmed',
        'facts': resolvedFacts,
        'aggregateKey': 'social.dev_run:7:314',
        'route': {
          'kind': 'social.session',
          'schemaVersion': 1,
          'parameters': {'appId': '7', 'sessionId': '314'},
        },
      },
    },
  };
}

Map<String, dynamic> validFeedPageJson({
  List<Map<String, dynamic>>? items,
  String? nextCursor,
  bool hasMore = false,
}) =>
    {
      'items': items ?? [validActivityItemJson()],
      'nextCursor': nextCursor,
      'hasMore': hasMore,
    };

Map<String, dynamic> validGenericActivityItemJson({
  String inboxSequence = '2',
  String syncSequence = '7',
  String attention = 'unread',
  Object? readAt,
}) {
  final item = validActivityItemJson(
    inboxSequence: inboxSequence,
    syncSequence: syncSequence,
    attention: attention,
    readAt: readAt,
  );
  final event = item['activityEvent']! as Map<String, dynamic>;
  event['contractId'] = 'social.notification.created.v1';
  event['appliedPolicyId'] = 'social.notification.created.v1';
  event['privacy'] = 'hidden_preview';

  final sourceEvent = event['sourceEvent']! as Map<String, dynamic>;
  sourceEvent['kind'] = 'social.notification.created';
  sourceEvent['status'] = 'created';
  sourceEvent['facts'] = {
    'privatePreview': 'must never be rendered',
    'nested': {'privateDetail': 'also must never be rendered'},
  };
  sourceEvent['route'] = {
    'kind': 'social.notification',
    'schemaVersion': 1,
    'parameters': {'privateTarget': 'must never be rendered'},
  };
  return item;
}

Map<String, dynamic> validSyncPageJson({
  List<Map<String, dynamic>>? items,
  String nextCursor = 'sync-cursor',
  bool hasMore = false,
}) =>
    {
      'items': items ?? [validActivityItemJson()],
      'nextCursor': nextCursor,
      'hasMore': hasMore,
    };
