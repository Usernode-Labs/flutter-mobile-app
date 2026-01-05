import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';
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
      return RegistrationResult.fromJson(data);
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
        return detail ?? 'Registration phase inactive. Please try later.';
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
    required this.identityUid,
    required this.publicKey,
    required this.address,
    required this.tier,
    required this.secretKey,
    this.phaseId,
    this.phaseName,
    this.phaseEndsAt,
  });

  final String identityUid;
  final String publicKey;
  final String address;
  final String tier;
  final String secretKey;
  final int? phaseId;
  final String? phaseName;
  final String? phaseEndsAt;

  factory RegistrationResult.fromJson(Map<String, dynamic> json) {
    final phase = json['phase'];

    String requiredString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) return value;
      }
      throw FormatException('Missing required field: ${keys.join(' or ')}');
    }

    return RegistrationResult(
      identityUid: requiredString(['identity_uid', 'identity_uid_hex']),
      publicKey: requiredString(['public_key', 'public_key_hex']),
      address: requiredString([
        'address',
        'public_key_hash_bech32m',
        'public_key_hash',
      ]),
      tier: json['tier'] as String,
      secretKey: requiredString(['secret_key', 'secret_key_hex']),
      phaseId: phase is Map<String, dynamic> ? phase['id'] as int? : null,
      phaseName:
          phase is Map<String, dynamic> ? phase['name'] as String? : null,
      phaseEndsAt:
          phase is Map<String, dynamic> ? phase['ends_at'] as String? : null,
    );
  }
}
