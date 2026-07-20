import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_api_client.dart';

class ActivitySessionStore {
  ActivitySessionStore({
    required String baseUrl,
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  })  : _baseUrl = ActivityApiClient.normalizeBaseUrl(baseUrl),
        _secureStorage = secureStorage;

  static const _storageKey = 'activity:consumer-session:v1';

  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  Future<ActivitySession?> load() async {
    final raw = await _secureStorage.read(key: _storageKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a session object');
      }
      expectActivityJsonKeys(
        decoded,
        const {'baseUrl', 'accessToken', 'tokenType', 'expiresAt'},
      );
      if (requiredActivityString(decoded, 'baseUrl') != _baseUrl) {
        await clear();
        return null;
      }
      final session = ActivitySession.fromJson({
        'accessToken': decoded['accessToken'],
        'tokenType': decoded['tokenType'],
        'expiresAt': decoded['expiresAt'],
      });
      return session;
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> save(ActivitySession session) async {
    await _secureStorage.write(
      key: _storageKey,
      value: jsonEncode({
        'baseUrl': _baseUrl,
        ...session.toJson(),
      }),
    );
  }

  Future<void> clear() => _secureStorage.delete(key: _storageKey);
}
