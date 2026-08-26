import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage could not prove whether the session credential exists.
///
/// This is deliberately different from a `null` token. On iOS, Keychain can
/// be temporarily unavailable while protected data is locked; treating that
/// condition as deletion would turn a background read into a forced logout.
class AuthTokenUnavailableException implements Exception {
  const AuthTokenUnavailableException([this.cause]);

  final Object? cause;

  @override
  String toString() => cause == null
      ? 'AuthTokenUnavailableException()'
      : 'AuthTokenUnavailableException($cause)';
}

class AuthTokenStore {
  AuthTokenStore({
    FlutterSecureStorage? storage,
    FlutterSecureStorage? legacyStorage,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            ),
        _legacyStorage =
            legacyStorage ?? storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v4:session_token';
  static const _legacyKey = 'auth:v3:session_token';
  static final StreamController<void> _changes =
      StreamController<void>.broadcast(sync: true);

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage _legacyStorage;
  Future<void> _operationTail = Future.value();
  bool _legacyRetired = false;

  /// Nonsecret process-wide signal used by consumers that must react when a
  /// same-participant login rotates the bearer without changing Identity.
  static Stream<void> get changes => _changes.stream;

  /// iOS protected-data changes let a cold restore retry after first unlock.
  Stream<bool>? get protectedDataAvailabilityChanges {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
    return _storage.onCupertinoProtectedDataAvailabilityChanged;
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final run = _operationTail.then((_) => operation());
    _operationTail = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<String?> _readConfirmed(
    FlutterSecureStorage storage,
    String key,
  ) async {
    try {
      final value = await storage.read(key: key);
      if (value != null) return value;

      // flutter_secure_storage 9.2.4 can discard an initial iOS Keychain
      // error when its synchronizable fallback reports "not found". Its
      // containsKey path preserves that error, so a false result is the proof
      // required before `null` is allowed to mean genuinely absent.
      if (await storage.containsKey(key: key)) {
        throw const AuthTokenUnavailableException();
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await storage.isCupertinoProtectedDataAvailable() == false) {
        // The item may be truly absent, but that cannot be proven while an
        // older when-unlocked credential could still be hidden by Keychain.
        throw const AuthTokenUnavailableException();
      }
      return null;
    } on AuthTokenUnavailableException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthTokenUnavailableException(error),
        stackTrace,
      );
    }
  }

  Future<void> _retireLegacyBestEffort() async {
    if (_legacyRetired) return;
    try {
      await _legacyStorage.delete(key: _legacyKey);
      _legacyRetired = true;
    } catch (_) {
      // The current key is already verified and authoritative. A later read
      // retries this cleanup when the legacy accessibility class is usable.
    }
  }

  Future<String?> read() => _serialize(() async {
        final current = await _readConfirmed(_storage, _key);
        if (current != null) {
          await _retireLegacyBestEffort();
          return current;
        }

        if (_legacyRetired) return null;
        final legacy = await _readConfirmed(_legacyStorage, _legacyKey);
        if (legacy == null) {
          _legacyRetired = true;
          return null;
        }

        // Use a new key so migration is crash-safe: the when-unlocked item is
        // retained until the after-first-unlock copy has been read back.
        await _storage.write(key: _key, value: legacy);
        final migrated = await _readConfirmed(_storage, _key);
        if (migrated != legacy) {
          throw const AuthTokenUnavailableException();
        }
        await _retireLegacyBestEffort();
        return migrated;
      });

  Future<void> write(String token) => _serialize(() async {
        await _storage.write(key: _key, value: token);
        final stored = await _readConfirmed(_storage, _key);
        if (stored != token) {
          throw const AuthTokenUnavailableException();
        }
        await _retireLegacyBestEffort();
        _changes.add(null);
      });

  Future<void> clear() => _serialize(() async {
        // Delete legacy first. If this fails, the authoritative current token
        // remains in place and callers cannot observe a successful-but-
        // reversible logout where the legacy credential is migrated back.
        if (!_legacyRetired) {
          await _legacyStorage.delete(key: _legacyKey);
          _legacyRetired = true;
        }
        await _storage.delete(key: _key);
        _changes.add(null);
      });
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
