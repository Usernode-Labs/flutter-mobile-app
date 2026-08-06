import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'social_push_store.dart';

class SocialPushPayload {
  const SocialPushPayload({
    required this.notificationId,
    required this.recipientBinding,
  });

  final int notificationId;
  final String recipientBinding;
}

SocialPushPayload? parseSocialPushPayload(
  Map<String, Object?> data, {
  required String environment,
}) {
  if (environment.isEmpty ||
      data['source'] != socialPushPayloadSource ||
      data['schema'] != socialPushPayloadSchema ||
      data['environment'] != environment) {
    return null;
  }

  final rawId = data['notification_id'];
  final binding = data['recipient_binding'];
  if (rawId is! String ||
      !RegExp(r'^[1-9][0-9]*$').hasMatch(rawId) ||
      binding is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(binding)) {
    return null;
  }
  final notificationId = int.tryParse(rawId);
  if (notificationId == null ||
      notificationId <= 0 ||
      notificationId > 2147483647) {
    return null;
  }
  return SocialPushPayload(
    notificationId: notificationId,
    recipientBinding: binding,
  );
}

String socialPushRecipientBinding({
  required String installationId,
  required int userId,
  required String environment,
}) {
  final material = <String>[
    socialPushRecipientBindingContext,
    installationId.toLowerCase(),
    '$userId',
    environment,
  ].join('\n');
  return sha256.convert(utf8.encode(material)).toString();
}
