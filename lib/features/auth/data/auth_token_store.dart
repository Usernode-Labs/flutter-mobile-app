import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crypto_mobile_app/features/auth/data/models/me.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v3:session_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

/// The last known user tier, cached in prefs.
///
/// This is a cache of backend authority, not the authority itself: [UserLevel]
/// still resolves from `/me` when it is reachable. It exists so bootstrap can
/// pick the node mode and the first frame can pick the tab set without waiting
/// on a network round trip, and so both still work offline.
///
/// Replaces the old `auth:v3:guest` boolean — one representation of the tier
/// rather than two that can disagree.
class UserTypeStore {
  UserTypeStore({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'app:user_type';
  final SharedPreferences? _injected;

  /// Reads through to disk rather than trusting the in-memory cache.
  ///
  /// Android runs a second Flutter engine for background alarm work
  /// (`BackgroundAlarmEngine.kt`), and each engine caches prefs independently.
  /// A long-lived headless engine would otherwise keep serving a stale tier
  /// after the UI engine wrote a new one — and act on it.
  Future<SharedPreferences> get _prefs async {
    final prefs = _injected ?? await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  Future<UserLevel?> read() async {
    final raw = (await _prefs).getString(_key);
    if (raw == null) return null;
    return UserLevel.values.where((l) => l.name == raw).firstOrNull;
  }

  Future<void> write(UserLevel level) async =>
      (await _prefs).setString(_key, level.name);

  Future<void> clear() async => (await _prefs).remove(_key);

  /// True when the cached tier is [UserLevel.guest].
  Future<bool> isGuest() async => await read() == UserLevel.guest;
}
