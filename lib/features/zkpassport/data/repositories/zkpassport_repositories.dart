import 'dart:convert';

import 'package:crypto_mobile_app/core/providers/accounts_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/network_prefs.dart';
import 'package:crypto_mobile_app/features/zkpassport/data/models/zkpassport_models.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ZkPassportRegistrationRepository {
  static const _kRegisteredKeyBase = 'zkpassport:registered';
  static const _kRegistrationKeyBase = 'zkpassport:registration';

  Future<bool> isRegistered() async {
    final registration = await getActiveRegistration();
    return registration.registered;
  }

  Future<ZkPassportLocalRegistration> getActiveRegistration() async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return ZkPassportLocalRegistration.unregistered();
    }

    return _loadRegistrationForAccount(active.id);
  }

  Future<void> storeActiveRegistration({
    required bool registered,
    required String? nullifierHex,
  }) async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(active.id);
    final payload = ZkPassportLocalRegistration(
      registered: registered,
      nullifierHex: nullifierHex,
      registeredAtMs: registered ? DateTime.now().millisecondsSinceEpoch : null,
    );
    await prefs.setString(key, jsonEncode(payload.toJson()));
  }

  Future<void> clearActiveRegistration() async {
    final accounts = await AccountsRepository.create();
    final active = await accounts.getActive();
    if (active == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_registrationKeyForAccount(active.id));
  }

  String _registrationKeyForAccount(String accountId) {
    return NetworkPrefs.prefixKey('$_kRegistrationKeyBase:$accountId');
  }

  Future<ZkPassportLocalRegistration> _loadRegistrationForAccount(
    String accountId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _registrationKeyForAccount(accountId);
    final raw = prefs.getString(key);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final parsed = ZkPassportLocalRegistration.fromJson(decoded);
        if (parsed != null) {
          return parsed;
        }
      } catch (_) {
        // Fall through to migration/unregistered.
      }
    }

    // Migration: older versions stored a single boolean for the whole network.
    final legacyKey = NetworkPrefs.prefixKey(_kRegisteredKeyBase);
    final legacyRegistered = prefs.getBool(legacyKey) ?? false;
    if (!legacyRegistered) {
      return ZkPassportLocalRegistration.unregistered();
    }

    final migrated = ZkPassportLocalRegistration(
      registered: true,
      nullifierHex: null,
      registeredAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString(key, jsonEncode(migrated.toJson()));
    return migrated;
  }
}

class ZkPassportRuntimeSessionRepository {
  static const _kRuntimeSessionKeyBase = 'zkpassport:runtime_session_v1';

  Future<ZkPassportRuntimeSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixKey(_kRuntimeSessionKeyBase);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(key);
        return null;
      }
      final session = ZkPassportRuntimeSession.fromJson(decoded);
      if (session == null) {
        await prefs.remove(key);
        return null;
      }
      return session;
    } catch (_) {
      await prefs.remove(key);
      return null;
    }
  }

  Future<void> save(ZkPassportRuntimeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixKey(_kRuntimeSessionKeyBase);
    await prefs.setString(key, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final key = NetworkPrefs.prefixKey(_kRuntimeSessionKeyBase);
    await prefs.remove(key);
  }
}

final _sessionServerLog =
    LoggingService.instance.withTag('usernode/ZkPassportSessionServer');

class ZkPassportSessionServerException implements Exception {
  ZkPassportSessionServerException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final Object? body;

  @override
  String toString() =>
      'ZkPassportSessionServerException($statusCode, $message)';
}

class ZkPassportSessionServerRepository {
  ZkPassportSessionServerRepository({
    required String baseUrl,
    http.Client? httpClient,
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  Future<ZkPassportSessionStartResponse> startSession({
    required String walletAddress,
    required String chainId,
    required int nonce,
  }) async {
    final json = await _postJson(
      '/v1/zkp/sessions/start',
      body: {
        'wallet_address': walletAddress,
        'chain_id': chainId,
        'nonce': nonce,
      },
      timeout: const Duration(seconds: 10),
    );
    return ZkPassportSessionStartResponse.fromJson(json);
  }

  Future<ZkPassportSessionStatusResponse> getSessionStatus({
    required String sessionId,
  }) async {
    final json = await _getJson(
      '/v1/zkp/sessions/${sessionId.trim()}',
      timeout: const Duration(seconds: 5),
    );
    return ZkPassportSessionStatusResponse.fromJson(json);
  }

  Future<ZkPassportSessionResultResponse?> tryGetSessionResult({
    required String sessionId,
    int waitMs = 0,
  }) async {
    final normalizedWaitMs = waitMs > 0 ? waitMs : 0;
    final url =
        Uri.parse('$_baseUrl/v1/zkp/sessions/${sessionId.trim()}/result')
            .replace(
      queryParameters: normalizedWaitMs > 0
          ? <String, String>{'wait_ms': normalizedWaitMs.toString()}
          : null,
    );
    _sessionServerLog.trace('GET $url');

    late final http.Response response;
    try {
      final timeout = normalizedWaitMs > 0
          ? Duration(milliseconds: normalizedWaitMs + 2000)
          : const Duration(seconds: 5);
      response = await _http.get(
        url,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }

    // result_not_ready
    if (response.statusCode == 409) {
      return null;
    }

    final json = _decodeResponseJson(response);
    return ZkPassportSessionResultResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _sessionServerLog.trace('GET $url');

    late final http.Response response;
    try {
      response = await _http.get(
        url,
        headers: const {
          'Accept': 'application/json',
        },
      ).timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }
    return _decodeResponseJson(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    _sessionServerLog.trace('POST $url');

    late final http.Response response;
    try {
      response = await _http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout);
    } catch (e) {
      _sessionServerLog.warn('Session server request failed for $url: $e');
      rethrow;
    }
    return _decodeResponseJson(response);
  }

  Map<String, dynamic> _decodeResponseJson(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['error'] as String? ??
              decoded['message'] as String? ??
              'Request failed')
          : 'Request failed';
      throw ZkPassportSessionServerException(
        response.statusCode,
        message,
        body: decoded ?? response.body,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ZkPassportSessionServerException(
        response.statusCode,
        'Unexpected response shape',
        body: response.body,
      );
    }
    return decoded;
  }

  void dispose() {
    _http.close();
  }
}

String _normalizeBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw StateError('Session server base URL must not be empty.');
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.scheme.isEmpty || parsed.host.isEmpty) {
    throw StateError('Invalid session server base URL: "$raw".');
  }
  final normalized = parsed.toString();
  if (normalized.endsWith('/')) {
    return normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}
