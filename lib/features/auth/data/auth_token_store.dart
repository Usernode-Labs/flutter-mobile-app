import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v3:session_token';
  static const _sessionRecordVersion = 1;
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

  Future<bool> clear() async {
    await _storage.delete(key: _key);
    final cleared = await _storage.read(key: _key) == null;
    if (cleared) _changes.add(null);
    return cleared;
  }

  Future<bool> writeSessionCredential(SessionCredential credential) async {
    final credentials = await _readSessionCredentials(credential.sessionId);
    for (final current in credentials) {
      if (current.credentialRef == credential.credentialRef ||
          current.credentialGeneration == credential.credentialGeneration) {
        return current == credential;
      }
    }
    await _writeSessionCredentials(
      credential.sessionId,
      [...credentials, credential],
    );
    final written = await readSessionCredential(
      sessionId: credential.sessionId,
      credentialRef: credential.credentialRef,
      credentialGeneration: credential.credentialGeneration,
    );
    if (written == credential) _changes.add(null);
    return written == credential;
  }

  Future<SessionCredential?> readSessionCredential({
    required String sessionId,
    required String credentialRef,
    required int credentialGeneration,
  }) async {
    for (final credential in await _readSessionCredentials(sessionId)) {
      if (credential.credentialRef == credentialRef &&
          credential.credentialGeneration == credentialGeneration) {
        return credential;
      }
    }
    return null;
  }

  Future<bool> clearSessionCredential(SessionCredential expected) async {
    final credentials = await _readSessionCredentials(expected.sessionId);
    final matchingIndex = credentials.indexWhere(
      (credential) =>
          credential.credentialRef == expected.credentialRef &&
          credential.credentialGeneration == expected.credentialGeneration,
    );
    if (matchingIndex < 0) return true;
    if (!credentials[matchingIndex].sameOwnerAs(expected)) return false;
    credentials.removeAt(matchingIndex);
    await _writeSessionCredentials(expected.sessionId, credentials);
    final cleared = await readSessionCredential(
          sessionId: expected.sessionId,
          credentialRef: expected.credentialRef,
          credentialGeneration: expected.credentialGeneration,
        ) ==
        null;
    if (cleared) _changes.add(null);
    return cleared;
  }

  Future<bool> clearSessionCredentials(String sessionId) async {
    final key = _sessionKey(sessionId);
    await _storage.delete(key: key);
    final cleared = await _storage.read(key: key) == null;
    if (cleared) _changes.add(null);
    return cleared;
  }

  Future<List<SessionCredential>> _readSessionCredentials(
      String sessionId) async {
    final encoded = await _storage.read(key: _sessionKey(sessionId));
    if (encoded == null) return [];
    try {
      final object = jsonDecode(encoded) as Map<String, dynamic>;
      if (object['version'] != _sessionRecordVersion ||
          object['session_id'] != sessionId ||
          object['credentials'] is! List) {
        throw const FormatException('invalid session credential envelope');
      }
      final credentials = (object['credentials'] as List)
          .map((value) => SessionCredential.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
      if (credentials.any((credential) => credential.sessionId != sessionId)) {
        throw const FormatException('cross-session credential entry');
      }
      return credentials;
    } catch (error) {
      throw StateError('Session credential record is invalid: $error');
    }
  }

  Future<void> _writeSessionCredentials(
    String sessionId,
    List<SessionCredential> credentials,
  ) async {
    final key = _sessionKey(sessionId);
    if (credentials.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(
      key: key,
      value: jsonEncode({
        'version': _sessionRecordVersion,
        'session_id': sessionId,
        'credentials': credentials.map((value) => value.toJson()).toList(),
      }),
    );
  }

  static String _sessionKey(String sessionId) => 'auth:v4:session:$sessionId';
}

class SessionCredential {
  const SessionCredential({
    required this.sessionId,
    this.transitionId,
    required this.credentialRef,
    required this.credentialGeneration,
    required this.token,
    required this.userNamespace,
  });

  factory SessionCredential.fromJson(Map<String, dynamic> json) {
    final sessionId = json['session_id'];
    final transitionId = json['transition_id'];
    final credentialRef = json['credential_ref'];
    final credentialGeneration = json['credential_generation'];
    final token = json['token'];
    final userNamespace = json['user_namespace'];
    if (sessionId is! String ||
        sessionId.isEmpty ||
        (transitionId != null && transitionId is! String) ||
        credentialRef is! String ||
        credentialRef.isEmpty ||
        credentialGeneration is! int ||
        credentialGeneration <= 0 ||
        token is! String ||
        token.isEmpty ||
        userNamespace is! String ||
        userNamespace.isEmpty) {
      throw const FormatException('invalid session credential');
    }
    return SessionCredential(
      sessionId: sessionId,
      transitionId: transitionId as String?,
      credentialRef: credentialRef,
      credentialGeneration: credentialGeneration,
      token: token,
      userNamespace: userNamespace,
    );
  }

  final String sessionId;
  final String? transitionId;
  final String credentialRef;
  final int credentialGeneration;
  final String token;
  final String userNamespace;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'transition_id': transitionId,
        'credential_ref': credentialRef,
        'credential_generation': credentialGeneration,
        'token': token,
        'user_namespace': userNamespace,
      };

  bool sameOwnerAs(SessionCredential other) =>
      sessionId == other.sessionId &&
      transitionId == other.transitionId &&
      credentialRef == other.credentialRef &&
      credentialGeneration == other.credentialGeneration &&
      userNamespace == other.userNamespace;

  @override
  bool operator ==(Object other) =>
      other is SessionCredential && sameOwnerAs(other) && token == other.token;

  @override
  int get hashCode => Object.hash(
        sessionId,
        transitionId,
        credentialRef,
        credentialGeneration,
        token,
        userNamespace,
      );

  @override
  String toString() => 'SessionCredential($sessionId, $credentialRef, '
      'generation: $credentialGeneration, token: <redacted>)';
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
  Future<bool> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_key);
    await prefs.reload();
    return !prefs.containsKey(_key);
  }
}
