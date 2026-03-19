import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final _log = LoggingService.instance.withTag('usernode/RegistrationRepository');

class RegistrationApiException implements Exception {
  RegistrationApiException(this.statusCode, this.message, {this.body});
  final int statusCode;
  final String message;
  final Object? body;
  @override
  String toString() => 'RegistrationApiException($statusCode, $message)';
}

class RegistrationRepository {
  RegistrationRepository({
    String? endpoint,
    http.Client? httpClient,
  })  : _endpoint = endpoint ?? AppConfig.registrationEndpoint,
        _http = httpClient ?? http.Client();

  final String _endpoint;
  final http.Client _http;

  Future<RegistrationResult> register({
    required String registrationCode,
    required String identifier,
  }) async {
    final url = Uri.parse(_endpoint);
    _log.trace('Calling registration endpoint', context: {
      'url': url.toString(),
      'identifier': identifier,
    });
    http.Response resp;
    try {
      resp = await _http
          .post(
            url,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'registration_code': registrationCode,
              'identifier': identifier,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e, stackTrace) {
      _log.warn('Registration request failed: $e');
      await SentryUtil.captureError(
        e,
        stackTrace,
        tag: 'registration',
        context: {
          'registration': {
            'identifier': identifier,
            'error_type': 'network_error',
          },
        },
      );
      rethrow;
    }

    _log.trace('Registration response received', context: {
      'statusCode': resp.statusCode,
    });

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw RegistrationApiException(
          resp.statusCode,
          'Unexpected response format',
          body: resp.body,
        );
      }
      final success = decoded['success'] == true;
      final data = decoded['data'];
      if (!success || data is! Map<String, dynamic>) {
        throw RegistrationApiException(
          resp.statusCode,
          'Unexpected response format',
          body: resp.body,
        );
      }
      final result = RegistrationResult.fromJson(data);
      await saveParticipantId(result.participantId);
      return result;
    }

    // Map known error codes to messages
    final message = _friendlyErrorMessage(resp);

    // Log API error to Sentry
    await SentryUtil.captureMessageWithData(
      'Registration API error',
      {
        'identifier': identifier,
        'status_code': resp.statusCode,
        'response_body': resp.body,
        'error_message': message,
      },
      level: SentryLevel.error,
    );

    throw RegistrationApiException(resp.statusCode, message, body: resp.body);
  }

  String _friendlyErrorMessage(http.Response resp) {
    String? detail;
    try {
      final parsed = jsonDecode(resp.body);
      if (parsed is Map && parsed['detail'] is String) {
        detail = parsed['detail'] as String;
      } else if (parsed is Map && parsed['message'] is String) {
        detail = parsed['message'] as String;
      }
    } catch (e) {
      _log.debug('Could not parse error response JSON: $e');
    }
    switch (resp.statusCode) {
      case 403:
        return detail ?? 'Registration event inactive. Please try later.';
      case 404:
        return detail ??
            'Participant not found or code invalid. Check your identifier and code.';
      case 409:
        return detail ?? 'This registration code has already been used.';
      default:
        return detail ?? 'Registration failed (HTTP ${resp.statusCode}).';
    }
  }

  void dispose() {
    _http.close();
  }
}

class RegistrationResult {
  RegistrationResult({
    required this.participantId,
    required this.identityUid,
    required this.publicKey,
    required this.address,
    required this.tier,
    required this.secretKey,
    this.eventId,
    this.eventName,
    this.eventEndsAt,
  });

  final int participantId;
  final String identityUid;
  final String publicKey;
  final String address;
  final String tier;
  final String secretKey;
  final int? eventId;
  final String? eventName;
  final String? eventEndsAt;

  factory RegistrationResult.fromJson(Map<String, dynamic> json) {
    final event = json['event'] ?? json['phase'];

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    String requiredString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) return value;
      }
      throw FormatException('Missing required field: ${keys.join(' or ')}');
    }

    final participantId = parseInt(json['participant_id'] ?? json['id']) ??
        (throw const FormatException('Missing participant_id'));

    final rawSecretKey = requiredString(['secret_key', 'secret_key_hex']);
    final rawPublicKey = requiredString(['public_key', 'public_key_hex']);
    final rawAddress = requiredString([
      'address',
      'public_key_hash_bech32m',
      'public_key_hash',
    ]);

    // Convert hex keys to bech32m if needed — Rust FFI expects bech32m encoding.
    final secretKey = _ensureBech32m(rawSecretKey, 'utsk');
    final publicKey = _ensureBech32m(rawPublicKey, 'utpk');
    final address = _ensureBech32m(rawAddress, 'ut');

    return RegistrationResult(
      participantId: participantId,
      identityUid: requiredString(['identity_uid', 'identity_uid_hex']),
      publicKey: publicKey,
      address: address,
      tier: json['tier'] as String,
      secretKey: secretKey,
      eventId: event is Map<String, dynamic>
          ? parseInt(event['event_id'] ?? event['id'])
          : null,
      eventName:
          event is Map<String, dynamic> ? event['name'] as String? : null,
      eventEndsAt:
          event is Map<String, dynamic> ? event['ends_at'] as String? : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Bech32m encoding helpers (BIP350)
  // ---------------------------------------------------------------------------

  static const _bech32mConst = 0x2bc830a3;
  static const _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

  static final _hexRegExp = RegExp(r'^[0-9a-fA-F]+$');

  /// Returns [key] as-is if it already looks like bech32m (starts with [hrp]1).
  /// If it looks like hex, encodes it as bech32m with the given [hrp].
  static String _ensureBech32m(String key, String hrp) {
    if (key.startsWith('${hrp}1')) return key;
    // Only convert even-length hex strings
    if (key.length.isEven && _hexRegExp.hasMatch(key)) {
      _log.debug(
        'Converting hex key to bech32m '
        '(len: ${key.length}, hrp: $hrp)',
      );
      return _bech32mEncode(hrp, _hexToBytes(key));
    }
    // Unknown format — return as-is, let downstream report the error.
    return key;
  }

  static Uint8List _hexToBytes(String hex) {
    final length = hex.length ~/ 2;
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static List<int> _convertBits(
    List<int> data,
    int fromBits,
    int toBits, {
    bool pad = true,
  }) {
    var acc = 0;
    var bits = 0;
    final result = <int>[];
    final maxV = (1 << toBits) - 1;
    for (final value in data) {
      acc = (acc << fromBits) | value;
      bits += fromBits;
      while (bits >= toBits) {
        bits -= toBits;
        result.add((acc >> bits) & maxV);
      }
    }
    if (pad && bits > 0) {
      result.add((acc << (toBits - bits)) & maxV);
    }
    return result;
  }

  static int _bech32Polymod(List<int> values) {
    const gen = [
      0x3b6a57b2,
      0x26508e6d,
      0x1ea119fa,
      0x3d4233dd,
      0x2a1462b3,
    ];
    var chk = 1;
    for (final v in values) {
      final top = chk >> 25;
      chk = ((chk & 0x1ffffff) << 5) ^ v;
      for (var i = 0; i < 5; i++) {
        chk ^= ((top >> i) & 1) != 0 ? gen[i] : 0;
      }
    }
    return chk;
  }

  static List<int> _hrpExpand(String hrp) {
    final result = <int>[];
    for (final c in hrp.codeUnits) {
      result.add(c >> 5);
    }
    result.add(0);
    for (final c in hrp.codeUnits) {
      result.add(c & 31);
    }
    return result;
  }

  static List<int> _bech32mChecksum(String hrp, List<int> data) {
    final values = _hrpExpand(hrp) + data + [0, 0, 0, 0, 0, 0];
    final polymod = _bech32Polymod(values) ^ _bech32mConst;
    return List.generate(6, (i) => (polymod >> (5 * (5 - i))) & 31);
  }

  static String _bech32mEncode(String hrp, Uint8List data) {
    final converted = _convertBits(data, 8, 5);
    final checksum = _bech32mChecksum(hrp, converted);
    final encoded =
        (converted + checksum).map((d) => _charset[d]).join();
    return '${hrp}1$encoded';
  }
}
