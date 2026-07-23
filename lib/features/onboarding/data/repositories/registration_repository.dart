import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/sentry.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final _log = LoggingService.instance.withTag('usernode/RegistrationRepository');
const _backendWritesDisabledMessage =
    'Backend write requests are disabled in view-only mode.';

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
    bool? writesEnabled,
  })  : _endpoint = endpoint ?? AppConfig.registrationEndpoint,
        _http = httpClient ?? createAppHttpClient(),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly;

  final String _endpoint;
  final http.Client _http;
  final bool _writesEnabled;

  Future<RegistrationResult> register({
    required String registrationCode,
    required String identifier,
  }) async {
    if (!_writesEnabled) {
      throw RegistrationApiException(503, _backendWritesDisabledMessage);
    }

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
      // Intentionally does not persist the participant ID: that is a
      // bucket-scoped write, and the active identity is not settled until the
      // caller has imported the account and switched buckets. registerAndApply
      // owns that write. See its comment for why order matters.
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
      if (parsed is Map) {
        // Try: detail → message → debug → error (backend uses different fields)
        detail = parsed['detail'] as String? ??
            parsed['message'] as String? ??
            parsed['debug'] as String?;
        if (detail == null &&
            parsed['error'] is String &&
            parsed['error'] != 'Registration failed') {
          detail = parsed['error'] as String;
        }
        // Handle 422 Laravel validation errors
        if (resp.statusCode == 422 && parsed['errors'] is Map) {
          final errors = parsed['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstField = errors.values.first;
            if (firstField is List && firstField.isNotEmpty) {
              detail = firstField.first.toString();
            }
          }
        }
      }
    } catch (e) {
      _log.debug('Could not parse error response JSON: $e');
    }
    switch (resp.statusCode) {
      case 403:
        return detail ??
            'This registration code is no longer active. Please check your latest invite email for updated credentials.';
      case 404:
        return detail ??
            'Username not found or registration code invalid. Please double-check both fields and try again.';
      case 409:
        return detail ??
            'This registration code has already been used. If this is your code, try re-entering your exact username.';
      case 422:
        return detail ??
            'Please fill in both your username and registration code.';
      default:
        return detail ??
            'Registration failed. Please try again or contact support.';
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
    this.seasonId,
    this.seasonName,
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
  final int? seasonId;
  final String? seasonName;
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

    return RegistrationResult(
      participantId: participantId,
      identityUid: requiredString(['identity_uid', 'identity_uid_hex']),
      publicKey: requiredString(['public_key', 'public_key_hex']),
      address: requiredString([
        'address',
        'public_key_hash_bech32m',
        'public_key_hash',
      ]),
      tier: json['tier'] as String,
      secretKey: requiredString(['secret_key', 'secret_key_hex']),
      seasonId: parseInt(json['season_id']),
      seasonName: json['season_name'] as String?,
      eventId: event is Map<String, dynamic>
          ? parseInt(event['event_id'] ?? event['id'])
          : null,
      eventName:
          event is Map<String, dynamic> ? event['name'] as String? : null,
      eventEndsAt:
          event is Map<String, dynamic> ? event['ends_at'] as String? : null,
    );
  }
}
