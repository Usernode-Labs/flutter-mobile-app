import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';

const socialDevRunTransitionContractId = 'social.dev_run.transition.v1';
const _maxSafeInteger = 9007199254740991;
final _socialIdPattern = RegExp(r'^[1-9][0-9]{0,18}$');

enum SocialDevRunStatus {
  needsInput('needs_input'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled');

  const SocialDevRunStatus(this.wireValue);
  final String wireValue;
}

enum SocialDevRunMode {
  scout('scout'),
  build('build'),
  headless('headless');

  const SocialDevRunMode(this.wireValue);
  final String wireValue;
}

enum SocialInputKind {
  clarification('clarification'),
  decision('decision'),
  approval('approval');

  const SocialInputKind(this.wireValue);
  final String wireValue;
}

enum SocialDevRunResult {
  spec('spec'),
  code('code'),
  specCode('spec_code'),
  noChanges('no_changes');

  const SocialDevRunResult(this.wireValue);
  final String wireValue;
}

enum SocialFailureStage {
  dispatch('dispatch'),
  execution('execution'),
  staging('staging'),
  preview('preview');

  const SocialFailureStage(this.wireValue);
  final String wireValue;
}

enum SocialCancellationReason {
  explicitStop('explicit_stop'),
  superseded('superseded');

  const SocialCancellationReason(this.wireValue);
  final String wireValue;
}

class SocialSessionRoute {
  const SocialSessionRoute({
    required this.appId,
    required this.sessionId,
  });

  final String appId;
  final String sessionId;
}

class SocialDevRunTransition {
  const SocialDevRunTransition._({
    required this.status,
    required this.runMode,
    required this.route,
    this.inputKind,
    this.result,
    this.failureStage,
    this.artifactsAvailable,
    this.cancellationReason,
  });

  final SocialDevRunStatus status;
  final SocialDevRunMode runMode;
  final SocialSessionRoute route;
  final SocialInputKind? inputKind;
  final SocialDevRunResult? result;
  final SocialFailureStage? failureStage;
  final bool? artifactsAvailable;
  final SocialCancellationReason? cancellationReason;

  factory SocialDevRunTransition.fromItem(ActivityItem item) {
    final event = item.activityEvent;
    final sourceEvent = event.sourceEvent;

    _require(event.contractId == socialDevRunTransitionContractId);
    _require(event.source.system == 'social');
    _require(event.source.producerId == 'social-dev');
    _require(event.source.trustClass == 'first_party_server');
    _require(event.recipientResolution.authority == 'source_binding');
    _require(event.privacy == 'private_preview');
    _require(event.retentionClass == 'account_activity');
    _require(sourceEvent.kind == 'social.dev_run.transition');
    _require(sourceEvent.schemaVersion == 1);
    _require(sourceEvent.canonicality == 'source_confirmed');
    _require(sourceEvent.recipient.relation == 'social.user');
    _require(sourceEvent.recipient.scope == 'account');
    _require(_isSocialId(sourceEvent.recipient.subject));
    _require(
      event.recipientResolution.subject == sourceEvent.recipient.subject,
    );
    _require(sourceEvent.resource.type == 'dev_session');
    _require(_isSocialId(sourceEvent.resource.id));
    _require(
      sourceEvent.resource.version >= 1 &&
          sourceEvent.resource.version <= _maxSafeInteger,
    );

    final route = sourceEvent.route;
    _require(route.kind == 'social.session');
    _require(route.schemaVersion == 1);
    expectActivityJsonKeys(
      route.parameters.cast<String, dynamic>(),
      const {'appId', 'sessionId'},
    );
    final appId = _parseSocialId(route.parameters['appId'], 'appId');
    final sessionId = _parseSocialId(
      route.parameters['sessionId'],
      'sessionId',
    );
    _require(sourceEvent.resource.id == sessionId);
    final aggregateKey = 'social.dev_run:$appId:$sessionId';
    _require(sourceEvent.aggregateKey == aggregateKey);
    _require(
      sourceEvent.sourceEventId ==
          '$aggregateKey:${sourceEvent.resource.version}',
    );

    final status = _parseEnum(
      SocialDevRunStatus.values,
      sourceEvent.status,
      (value) => value.wireValue,
      'status',
    );
    final facts = sourceEvent.facts;
    final mode = _parseEnum(
      SocialDevRunMode.values,
      facts['runMode'],
      (value) => value.wireValue,
      'runMode',
    );

    return switch (status) {
      SocialDevRunStatus.needsInput => _needsInput(
          item: item,
          event: event,
          facts: facts,
          mode: mode,
          route: SocialSessionRoute(appId: appId, sessionId: sessionId),
        ),
      SocialDevRunStatus.succeeded => _succeeded(
          item: item,
          event: event,
          facts: facts,
          mode: mode,
          route: SocialSessionRoute(appId: appId, sessionId: sessionId),
        ),
      SocialDevRunStatus.failed => _failed(
          item: item,
          event: event,
          facts: facts,
          mode: mode,
          route: SocialSessionRoute(appId: appId, sessionId: sessionId),
        ),
      SocialDevRunStatus.cancelled => _cancelled(
          item: item,
          event: event,
          facts: facts,
          mode: mode,
          route: SocialSessionRoute(appId: appId, sessionId: sessionId),
        ),
    };
  }

  static SocialDevRunTransition _needsInput({
    required ActivityItem item,
    required ActivityEvent event,
    required Map<String, Object?> facts,
    required SocialDevRunMode mode,
    required SocialSessionRoute route,
  }) {
    _requirePolicy(
      item,
      event,
      policyId: 'social.dev_run.needs_input.v1',
      attention: ActivityAttention.unread,
    );
    expectActivityJsonKeys(
      facts.cast<String, dynamic>(),
      const {'runMode', 'inputKind'},
    );
    return SocialDevRunTransition._(
      status: SocialDevRunStatus.needsInput,
      runMode: mode,
      inputKind: _parseEnum<SocialInputKind>(
        SocialInputKind.values,
        facts['inputKind'],
        (value) => value.wireValue,
        'inputKind',
      ),
      route: route,
    );
  }

  static SocialDevRunTransition _succeeded({
    required ActivityItem item,
    required ActivityEvent event,
    required Map<String, Object?> facts,
    required SocialDevRunMode mode,
    required SocialSessionRoute route,
  }) {
    _requirePolicy(
      item,
      event,
      policyId: 'social.dev_run.succeeded.v1',
      attention: ActivityAttention.unread,
    );
    expectActivityJsonKeys(
      facts.cast<String, dynamic>(),
      const {'runMode', 'result'},
    );
    return SocialDevRunTransition._(
      status: SocialDevRunStatus.succeeded,
      runMode: mode,
      result: _parseEnum<SocialDevRunResult>(
        SocialDevRunResult.values,
        facts['result'],
        (value) => value.wireValue,
        'result',
      ),
      route: route,
    );
  }

  static SocialDevRunTransition _failed({
    required ActivityItem item,
    required ActivityEvent event,
    required Map<String, Object?> facts,
    required SocialDevRunMode mode,
    required SocialSessionRoute route,
  }) {
    _requirePolicy(
      item,
      event,
      policyId: 'social.dev_run.failed.v1',
      attention: ActivityAttention.unread,
    );
    final rawArtifactsAvailable = facts['artifactsAvailable'];
    if (rawArtifactsAvailable is! bool) {
      throw const FormatException('Invalid artifactsAvailable');
    }
    final artifactsAvailable = rawArtifactsAvailable;
    final expectedKeys = artifactsAvailable
        ? const {'runMode', 'failureStage', 'artifactsAvailable', 'result'}
        : const {'runMode', 'failureStage', 'artifactsAvailable'};
    expectActivityJsonKeys(facts.cast<String, dynamic>(), expectedKeys);
    final stage = _parseEnum(
      SocialFailureStage.values,
      facts['failureStage'],
      (value) => value.wireValue,
      'failureStage',
    );
    final result = artifactsAvailable
        ? _parseEnum<SocialDevRunResult>(
            SocialDevRunResult.values.where(
              (value) => value != SocialDevRunResult.noChanges,
            ),
            facts['result'],
            (value) => value.wireValue,
            'result',
          )
        : null;
    if (artifactsAvailable) {
      _require(stage != SocialFailureStage.dispatch);
    } else {
      _require(
        stage == SocialFailureStage.dispatch ||
            stage == SocialFailureStage.execution,
      );
    }
    return SocialDevRunTransition._(
      status: SocialDevRunStatus.failed,
      runMode: mode,
      failureStage: stage,
      artifactsAvailable: artifactsAvailable,
      result: result,
      route: route,
    );
  }

  static SocialDevRunTransition _cancelled({
    required ActivityItem item,
    required ActivityEvent event,
    required Map<String, Object?> facts,
    required SocialDevRunMode mode,
    required SocialSessionRoute route,
  }) {
    _requirePolicy(
      item,
      event,
      policyId: 'social.dev_run.cancelled.v1',
      attention: ActivityAttention.receipt,
    );
    expectActivityJsonKeys(
      facts.cast<String, dynamic>(),
      const {'runMode', 'cancellationReason'},
    );
    final reason = _parseEnum(
      SocialCancellationReason.values,
      facts['cancellationReason'],
      (value) => value.wireValue,
      'cancellationReason',
    );
    if (reason == SocialCancellationReason.superseded) {
      _require(mode == SocialDevRunMode.headless);
    }
    return SocialDevRunTransition._(
      status: SocialDevRunStatus.cancelled,
      runMode: mode,
      cancellationReason: reason,
      route: route,
    );
  }

  static void _requirePolicy(
    ActivityItem item,
    ActivityEvent event, {
    required String policyId,
    required ActivityAttention attention,
  }) {
    _require(event.appliedPolicyId == policyId);
    _require(item.defaultAttention == attention);
  }
}

T _parseEnum<T>(
  Iterable<T> values,
  Object? raw,
  String Function(T value) wireValue,
  String field,
) {
  for (final value in values) {
    if (wireValue(value) == raw) return value;
  }
  throw FormatException('Invalid $field');
}

bool _isSocialId(String value) => _socialIdPattern.hasMatch(value);

String _parseSocialId(Object? value, String field) {
  if (value is String && _isSocialId(value)) return value;
  throw FormatException('Invalid $field');
}

void _require(bool condition) {
  if (!condition) throw const FormatException('Invalid Social Activity event');
}
