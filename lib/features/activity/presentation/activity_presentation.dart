import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/models/social_dev_run_transition.dart';

enum ActivityTitleCopy {
  scoutNeedsInput,
  buildNeedsInput,
  headlessNeedsInput,
  scoutSucceeded,
  buildSucceeded,
  headlessSucceeded,
  scoutFailed,
  buildFailed,
  headlessFailed,
  scoutCancelled,
  buildCancelled,
  headlessCancelled,
}

enum ActivityBodyCopy {
  needsClarification,
  needsDecision,
  needsApproval,
  succeededSpec,
  succeededCode,
  succeededSpecCode,
  succeededNoChanges,
  failedDispatchNoArtifacts,
  failedExecutionNoArtifacts,
  failedExecutionSpec,
  failedExecutionCode,
  failedExecutionSpecCode,
  failedStagingSpec,
  failedStagingCode,
  failedStagingSpecCode,
  failedPreviewSpec,
  failedPreviewCode,
  failedPreviewSpecCode,
  cancelledExplicitStop,
  cancelledSuperseded,
}

class ActivityFeedEntry {
  const ActivityFeedEntry._({
    required this.item,
    required this.transition,
    required this.titleCopy,
    required this.bodyCopy,
    required this.isUnread,
  });

  final ActivityItem item;
  final SocialDevRunTransition transition;
  final ActivityTitleCopy titleCopy;
  final ActivityBodyCopy bodyCopy;
  final bool isUnread;

  String get inboxSequence => item.inboxSequence;
  DateTime get occurredAt => item.activityEvent.sourceEvent.occurredAt;

  /// Applies the service's successful mark-read acknowledgement without
  /// inventing a server-owned `readAt` timestamp.
  ActivityFeedEntry markedRead() {
    if (!isUnread) return this;
    return ActivityFeedEntry._(
      item: item,
      transition: transition,
      titleCopy: titleCopy,
      bodyCopy: bodyCopy,
      isUnread: false,
    );
  }

  factory ActivityFeedEntry.fromItem(ActivityItem item) {
    final transition = SocialDevRunTransition.fromItem(item);
    return ActivityFeedEntry._(
      item: item,
      transition: transition,
      titleCopy: _titleCopy(transition),
      bodyCopy: _bodyCopy(transition),
      isUnread: item.isUnread,
    );
  }
}

ActivityTitleCopy _titleCopy(SocialDevRunTransition transition) {
  return switch ((transition.runMode, transition.status)) {
    (SocialDevRunMode.scout, SocialDevRunStatus.needsInput) =>
      ActivityTitleCopy.scoutNeedsInput,
    (SocialDevRunMode.build, SocialDevRunStatus.needsInput) =>
      ActivityTitleCopy.buildNeedsInput,
    (SocialDevRunMode.headless, SocialDevRunStatus.needsInput) =>
      ActivityTitleCopy.headlessNeedsInput,
    (SocialDevRunMode.scout, SocialDevRunStatus.succeeded) =>
      ActivityTitleCopy.scoutSucceeded,
    (SocialDevRunMode.build, SocialDevRunStatus.succeeded) =>
      ActivityTitleCopy.buildSucceeded,
    (SocialDevRunMode.headless, SocialDevRunStatus.succeeded) =>
      ActivityTitleCopy.headlessSucceeded,
    (SocialDevRunMode.scout, SocialDevRunStatus.failed) =>
      ActivityTitleCopy.scoutFailed,
    (SocialDevRunMode.build, SocialDevRunStatus.failed) =>
      ActivityTitleCopy.buildFailed,
    (SocialDevRunMode.headless, SocialDevRunStatus.failed) =>
      ActivityTitleCopy.headlessFailed,
    (SocialDevRunMode.scout, SocialDevRunStatus.cancelled) =>
      ActivityTitleCopy.scoutCancelled,
    (SocialDevRunMode.build, SocialDevRunStatus.cancelled) =>
      ActivityTitleCopy.buildCancelled,
    (SocialDevRunMode.headless, SocialDevRunStatus.cancelled) =>
      ActivityTitleCopy.headlessCancelled,
  };
}

ActivityBodyCopy _bodyCopy(SocialDevRunTransition transition) {
  return switch (transition.status) {
    SocialDevRunStatus.needsInput => switch (transition.inputKind!) {
        SocialInputKind.clarification => ActivityBodyCopy.needsClarification,
        SocialInputKind.decision => ActivityBodyCopy.needsDecision,
        SocialInputKind.approval => ActivityBodyCopy.needsApproval,
      },
    SocialDevRunStatus.succeeded => switch (transition.result!) {
        SocialDevRunResult.spec => ActivityBodyCopy.succeededSpec,
        SocialDevRunResult.code => ActivityBodyCopy.succeededCode,
        SocialDevRunResult.specCode => ActivityBodyCopy.succeededSpecCode,
        SocialDevRunResult.noChanges => ActivityBodyCopy.succeededNoChanges,
      },
    SocialDevRunStatus.failed => _failedBodyCopy(transition),
    SocialDevRunStatus.cancelled => switch (transition.cancellationReason!) {
        SocialCancellationReason.explicitStop =>
          ActivityBodyCopy.cancelledExplicitStop,
        SocialCancellationReason.superseded =>
          ActivityBodyCopy.cancelledSuperseded,
      },
  };
}

ActivityBodyCopy _failedBodyCopy(SocialDevRunTransition transition) {
  if (!transition.artifactsAvailable!) {
    return switch (transition.failureStage!) {
      SocialFailureStage.dispatch => ActivityBodyCopy.failedDispatchNoArtifacts,
      SocialFailureStage.execution =>
        ActivityBodyCopy.failedExecutionNoArtifacts,
      SocialFailureStage.staging ||
      SocialFailureStage.preview =>
        throw StateError('Invalid artifact-free failure stage'),
    };
  }

  return switch ((transition.failureStage!, transition.result!)) {
    (SocialFailureStage.execution, SocialDevRunResult.spec) =>
      ActivityBodyCopy.failedExecutionSpec,
    (SocialFailureStage.execution, SocialDevRunResult.code) =>
      ActivityBodyCopy.failedExecutionCode,
    (SocialFailureStage.execution, SocialDevRunResult.specCode) =>
      ActivityBodyCopy.failedExecutionSpecCode,
    (SocialFailureStage.staging, SocialDevRunResult.spec) =>
      ActivityBodyCopy.failedStagingSpec,
    (SocialFailureStage.staging, SocialDevRunResult.code) =>
      ActivityBodyCopy.failedStagingCode,
    (SocialFailureStage.staging, SocialDevRunResult.specCode) =>
      ActivityBodyCopy.failedStagingSpecCode,
    (SocialFailureStage.preview, SocialDevRunResult.spec) =>
      ActivityBodyCopy.failedPreviewSpec,
    (SocialFailureStage.preview, SocialDevRunResult.code) =>
      ActivityBodyCopy.failedPreviewCode,
    (SocialFailureStage.preview, SocialDevRunResult.specCode) =>
      ActivityBodyCopy.failedPreviewSpecCode,
    (SocialFailureStage.dispatch, _) ||
    (_, SocialDevRunResult.noChanges) =>
      throw StateError('Invalid failure result'),
  };
}

enum ActivityRelativeTimeUnit { now, minutes, hours, days }

class ActivityRelativeTime {
  const ActivityRelativeTime(this.unit, [this.value = 0]);

  final ActivityRelativeTimeUnit unit;
  final int value;
}

ActivityRelativeTime activityRelativeTime(DateTime occurredAt, DateTime now) {
  final age = now.toUtc().difference(occurredAt.toUtc());
  if (age.isNegative || age < const Duration(minutes: 1)) {
    return const ActivityRelativeTime(ActivityRelativeTimeUnit.now);
  }
  if (age < const Duration(hours: 1)) {
    return ActivityRelativeTime(
        ActivityRelativeTimeUnit.minutes, age.inMinutes);
  }
  if (age < const Duration(days: 1)) {
    return ActivityRelativeTime(ActivityRelativeTimeUnit.hours, age.inHours);
  }
  return ActivityRelativeTime(ActivityRelativeTimeUnit.days, age.inDays);
}
