import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v3:session_token';
  static final StreamController<void> _changes =
      StreamController<void>.broadcast(sync: true);
  final FlutterSecureStorage _storage;

  /// Nonsecret process-wide signal used by consumers that must react when a
  /// same-participant login rotates the bearer without changing Identity.
  static Stream<void> get changes => _changes.stream;

  Future<String?> read() => _storage.read(key: _key);

  Future<void> write(String token) async {
    await _storage.write(key: _key, value: token);
    _changes.add(null);
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    _changes.add(null);
  }
}

class AuthGuestFlag {
  AuthGuestFlag({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'auth:v3:guest';
  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<bool> isGuest({bool reload = false}) async {
    final prefs = await _prefs;
    if (reload) await prefs.reload();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setGuest() async => (await _prefs).setBool(_key, true);
  Future<void> clear() async => (await _prefs).remove(_key);
}
