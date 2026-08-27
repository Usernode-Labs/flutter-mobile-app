import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

class SocialPushRegistrationReply {
  const SocialPushRegistrationReply({
    required this.registered,
    required this.deliveryActive,
  });

  final bool registered;
  final bool deliveryActive;
}

enum SocialPushUnregisterReason {
  notificationsDisabled('notifications_disabled'),
  permissionDenied('permission_denied'),
  signedOut('signed_out'),
  accountChanged('account_changed'),
  identityBoundary('identity_boundary'),
  terminalReset('terminal_reset'),
  configurationUnavailable('configuration_unavailable');

  const SocialPushUnregisterReason(this.wireName);

  final String wireName;
}

class SocialPushApiException implements Exception {
  const SocialPushApiException({
    required this.statusCode,
    this.code,
    this.latestMutationRevision,
  });

  final int statusCode;
  final String? code;
  final int? latestMutationRevision;
}

/// Closed push transport. The caller supplies an already-admitted exact
/// operation, never a bearer or a generic HTTP client.
abstract interface class SocialPushRegistrationApi {
  Future<SocialPushRegistrationReply> getStatus({
    required SessionOperation operation,
    required String installationId,
  });

  Future<SocialPushRegistrationReply> register({
    required SessionOperation operation,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  });

  Future<void> unregister({
    required SessionOperation operation,
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  });
}

final class NativeSessionSocialPushRegistrationApi
    implements SocialPushRegistrationApi {
  const NativeSessionSocialPushRegistrationApi();

  @override
  Future<SocialPushRegistrationReply> getStatus({
    required SessionOperation operation,
    required String installationId,
  }) async {
    final status = await operation.readSocialPushStatus(
      installationId: installationId,
    );
    return SocialPushRegistrationReply(
      registered: status.registered,
      deliveryActive: status.deliveryActive,
    );
  }

  @override
  Future<SocialPushRegistrationReply> register({
    required SessionOperation operation,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  }) async {
    final status = await operation.registerSocialPush(
      SessionSocialPushRegistration(
        installationId: installationId,
        providerToken: registrationToken,
        platform: platform,
        permissionStatus: permissionStatus,
        mutationRevision: mutationRevision,
      ),
    );
    return SocialPushRegistrationReply(
      registered: status.registered,
      deliveryActive: status.deliveryActive,
    );
  }

  @override
  Future<void> unregister({
    required SessionOperation operation,
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  }) async {
    await operation.unregisterSocialPush(
      SessionSocialPushUnregistration(
        installationId: installationId,
        mutationRevision: mutationRevision,
        reason: reason.wireName,
      ),
    );
  }
}
