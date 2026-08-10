import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const socialPushPayloadSource = 'usernode_social';
const socialPushPayloadSchema = '1';
const socialPushRecipientBindingContext = 'usernode-social-push-recipient-v1';
const socialPushPendingLifetime = Duration(hours: 24);

enum SocialPushPermission {
  notDetermined('not_determined'),
  denied('denied'),
  authorized('authorized'),
  provisional('provisional');

  const SocialPushPermission(this.wireName);

  final String wireName;
}

enum SocialPushRegistrationStatus {
  disabled('disabled'),
  unregistered('unregistered'),
  registering('registering'),
  registered('registered'),
  disabling('disabling'),
  permissionDenied('permission_denied'),
  error('error');

  const SocialPushRegistrationStatus(this.wireName);

  final String wireName;
}

class SocialPushState {
  const SocialPushState({
    required this.enabled,
    required this.permission,
    required this.registrationStatus,
    required this.deliveryActive,
  });

  final bool enabled;
  final SocialPushPermission permission;
  final SocialPushRegistrationStatus registrationStatus;
  final bool deliveryActive;

  Map<String, Object> toBridgeJson() => {
        'enabled': enabled,
        'permissionStatus': permission.wireName,
        'registrationStatus': registrationStatus.wireName,
        'deliveryActive': deliveryActive,
      };
}

class PendingSocialNotification {
  const PendingSocialNotification({
    required this.notificationId,
    required this.recipientBinding,
    required this.receivedAt,
  });

  final int notificationId;
  final String recipientBinding;
  final DateTime receivedAt;

  bool isExpired(DateTime now) =>
      !now.toUtc().isBefore(receivedAt.toUtc().add(socialPushPendingLifetime));

  Map<String, Object> toJson() => {
        'notificationId': notificationId,
        'recipientBinding': recipientBinding,
        'receivedAt': receivedAt.toUtc().toIso8601String(),
      };

  static PendingSocialNotification? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final notificationId = value['notificationId'];
    final recipientBinding = value['recipientBinding'];
    final receivedAt = value['receivedAt'];
    if (notificationId is! int ||
        notificationId <= 0 ||
        notificationId > 2147483647 ||
        recipientBinding is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(recipientBinding) ||
        receivedAt is! String) {
      return null;
    }
    final parsedReceivedAt = DateTime.tryParse(receivedAt);
    if (parsedReceivedAt == null) return null;
    return PendingSocialNotification(
      notificationId: notificationId,
      recipientBinding: recipientBinding,
      receivedAt: parsedReceivedAt.toUtc(),
    );
  }
}

class SocialPushRecord {
  const SocialPushRecord({
    required this.installationId,
    required this.optedIn,
    required this.mutationRevision,
    this.pending,
  });

  static const schema = 1;
  static const maxMutationRevision = 9223372036854775807;

  final String installationId;
  final bool optedIn;
  final int mutationRevision;
  final PendingSocialNotification? pending;

  factory SocialPushRecord.fresh() => SocialPushRecord(
        installationId: _randomUuid(),
        optedIn: true,
        mutationRevision: 0,
      );

  SocialPushRecord copyWith({
    bool? optedIn,
    int? mutationRevision,
    PendingSocialNotification? pending,
    bool clearPending = false,
  }) =>
      SocialPushRecord(
        installationId: installationId,
        optedIn: optedIn ?? this.optedIn,
        mutationRevision: mutationRevision ?? this.mutationRevision,
        pending: clearPending ? null : pending ?? this.pending,
      );

  Map<String, Object?> toJson() => {
        'schema': schema,
        'installationId': installationId,
        'optedIn': optedIn,
        'mutationRevision': mutationRevision,
        if (pending != null) 'pending': pending!.toJson(),
      };

  static SocialPushRecord? fromJson(Object? value, DateTime now) {
    if (value is! Map<String, dynamic> || value['schema'] != schema) {
      return null;
    }
    final installationId = value['installationId'];
    final optedIn = value['optedIn'];
    final mutationRevision = value['mutationRevision'];
    if (installationId is! String ||
        !_uuidPattern.hasMatch(installationId) ||
        optedIn is! bool ||
        mutationRevision is! int ||
        mutationRevision < 0 ||
        mutationRevision > maxMutationRevision) {
      return null;
    }
    final pending = PendingSocialNotification.fromJson(value['pending']);
    return SocialPushRecord(
      installationId: installationId,
      // Version 1 originally persisted an implicit false before the user had
      // made any choice. A zero mutation revision distinguishes that default
      // from an explicit opt-out, so existing installations inherit the new
      // default without overriding a saved user preference.
      optedIn: mutationRevision == 0 ? true : optedIn,
      mutationRevision: mutationRevision,
      pending: pending == null || pending.isExpired(now) ? null : pending,
    );
  }
}

abstract interface class SocialPushPersistence {
  Future<SocialPushRecord> load();
  Future<void> save(SocialPushRecord record);
  Future<void> clear();
}

/// Stores the whole installation-scoped record outside backup and transfer.
///
/// The installation id and mutation fence must never be cloned onto a second
/// device. Android additionally excludes this storage file in the app backup
/// rules; iOS uses a ThisDeviceOnly keychain accessibility class.
class SecureStorageSocialPushPersistence implements SocialPushPersistence {
  SecureStorageSocialPushPersistence({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    ),
  }) : _storage = storage;

  static const _key = 'usernode_social_push_record_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<SocialPushRecord> load() async {
    String? encoded;
    try {
      encoded = await _storage.read(key: _key);
    } catch (_) {
      // This file also contains auth and account keys on Android. Never use
      // flutter_secure_storage's resetOnError because it clears the whole
      // shared file; recover only this feature-owned key instead.
      try {
        await _storage.delete(key: _key);
      } catch (_) {
        // A later save reports persistent storage failure to the service.
      }
      return SocialPushRecord.fresh();
    }
    if (encoded == null) return SocialPushRecord.fresh();
    try {
      final record = SocialPushRecord.fromJson(
        jsonDecode(encoded),
        DateTime.now().toUtc(),
      );
      return record ?? SocialPushRecord.fresh();
    } catch (_) {
      return SocialPushRecord.fresh();
    }
  }

  @override
  Future<void> save(SocialPushRecord record) async {
    await _storage.write(key: _key, value: jsonEncode(record.toJson()));
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String _randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
