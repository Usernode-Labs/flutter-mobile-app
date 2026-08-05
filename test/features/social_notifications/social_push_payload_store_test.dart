import 'dart:io';

import 'package:crypto_mobile_app/features/social_notifications/social_push_payload.dart';
import 'package:crypto_mobile_app/features/social_notifications/social_push_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const environment = 'production';
  const installationId = '123e4567-e89b-42d3-a456-426614174000';
  const binding =
      'b3d02767f53a4c189ab0147fda6744a4857a7613742bf675f257a5507c0916da';

  Map<String, Object?> payload({
    Object? source = socialPushPayloadSource,
    Object? schema = socialPushPayloadSchema,
    Object? notificationId = '123',
    Object? payloadEnvironment = environment,
    Object? recipientBinding = binding,
  }) =>
      {
        'source': source,
        'schema': schema,
        'notification_id': notificationId,
        'environment': payloadEnvironment,
        'recipient_binding': recipientBinding,
      };

  test('accepts only the canonical opaque Social payload', () {
    final parsed = parseSocialPushPayload(
      payload(),
      environment: environment,
    );

    expect(parsed?.notificationId, 123);
    expect(parsed?.recipientBinding, binding);
  });

  test('rejects another source, schema, environment, id, or binding', () {
    final invalid = <Map<String, Object?>>[
      payload(source: 'another_source'),
      payload(schema: '2'),
      payload(payloadEnvironment: 'staging'),
      payload(notificationId: '0'),
      payload(notificationId: '01'),
      payload(notificationId: '2147483648'),
      payload(notificationId: 123),
      payload(recipientBinding: 'not-a-binding'),
    ];

    for (final candidate in invalid) {
      expect(
        parseSocialPushPayload(candidate, environment: environment),
        isNull,
        reason: '$candidate',
      );
    }
  });

  test('recipient binding matches the backend SHA-256 vector', () {
    expect(
      socialPushRecipientBinding(
        installationId: installationId,
        userId: 42,
        environment: environment,
      ),
      binding,
    );
  });

  test('record round-trips one pending tap', () {
    final now = DateTime.utc(2026, 8, 3, 12);
    final record = SocialPushRecord(
      installationId: installationId,
      optedIn: true,
      mutationRevision: 7,
      pending: PendingSocialNotification(
        notificationId: 123,
        recipientBinding: binding,
        receivedAt: now,
      ),
    );

    final decoded = SocialPushRecord.fromJson(record.toJson(), now);

    expect(decoded?.installationId, installationId);
    expect(decoded?.optedIn, isTrue);
    expect(decoded?.mutationRevision, 7);
    expect(decoded?.pending?.notificationId, 123);
    expect(decoded?.pending?.recipientBinding, binding);
  });

  test('expired pending tap is dropped without losing opt-in state', () {
    final receivedAt = DateTime.utc(2026, 8, 1, 12);
    final record = SocialPushRecord(
      installationId: installationId,
      optedIn: true,
      mutationRevision: 9,
      pending: PendingSocialNotification(
        notificationId: 123,
        recipientBinding: binding,
        receivedAt: receivedAt,
      ),
    );

    final decoded = SocialPushRecord.fromJson(
      record.toJson(),
      receivedAt.add(const Duration(hours: 24)),
    );

    expect(decoded?.optedIn, isTrue);
    expect(decoded?.mutationRevision, 9);
    expect(decoded?.pending, isNull);
  });

  test('fresh records use UUIDv4 installation ids', () {
    expect(
      SocialPushRecord.fresh().installationId,
      matches(RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      )),
    );
  });

  test('Android backup rules exclude the shared secure-storage file', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();
    final legacyRules = await File(
      'android/app/src/main/res/xml/backup_rules.xml',
    ).readAsString();
    final extractionRules = await File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    ).readAsString();

    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(legacyRules, contains('path="FlutterSecureStorage.xml"'));
    expect(
      RegExp('path="FlutterSecureStorage.xml"').allMatches(extractionRules),
      hasLength(2),
    );
  });
}
