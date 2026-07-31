import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v3:session_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
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
