import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SocialPushRegistrationReply {
  const SocialPushRegistrationReply({
    required this.registered,
    required this.deliveryActive,
  });

  final bool registered;
  final bool deliveryActive;
}

enum SocialPushUnregisterReason {
  notificationsDisabled('notifications_disabled'),
  permissionDenied('permission_denied'),
  signedOut('signed_out'),
  accountChanged('account_changed'),
  identityBoundary('identity_boundary'),
  terminalReset('terminal_reset'),
  configurationUnavailable('configuration_unavailable');

  const SocialPushUnregisterReason(this.wireName);

  final String wireName;
}

class SocialPushApiException implements Exception {
  const SocialPushApiException({
    required this.statusCode,
    this.code,
    this.latestMutationRevision,
  });

  final int statusCode;
  final String? code;
  final int? latestMutationRevision;

  @override
  String toString() => 'SocialPushApiException('
      'statusCode: $statusCode, code: ${code ?? 'none'})';
}

abstract interface class SocialPushRegistrationApi {
  Future<SocialPushRegistrationReply> getStatus({
    required String bearer,
    required String installationId,
  });

  Future<SocialPushRegistrationReply> register({
    required String bearer,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  });

  Future<void> unregister({
    required String bearer,
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  });
}

class HttpSocialPushRegistrationApi implements SocialPushRegistrationApi {
  HttpSocialPushRegistrationApi({
    required String mobileApiBaseUrl,
    required this.expectedEnvironment,
    required this.expectedFirebaseProjectId,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _endpoint = Uri.parse(
          '${mobileApiBaseUrl.replaceFirst(RegExp(r'/+$'), '')}/'
          'push-registration',
        ),
        _client = client ?? http.Client();

  final Uri _endpoint;
  final http.Client _client;
  final Duration timeout;
  final String expectedEnvironment;
  final String expectedFirebaseProjectId;

  @override
  Future<SocialPushRegistrationReply> getStatus({
    required String bearer,
    required String installationId,
  }) async {
    final response = await _send(
      'GET',
      bearer: bearer,
      endpoint: _endpoint.replace(queryParameters: {
        'installation_id': installationId,
      }),
    );
    final json = _successJson(response);
    final registered = json['registered'];
    final deliveryActive = json['delivery_active'];
    if (registered is! bool ||
        deliveryActive is! bool ||
        (!registered && deliveryActive)) {
      throw SocialPushApiException(statusCode: response.statusCode);
    }
    return SocialPushRegistrationReply(
      registered: registered,
      deliveryActive: deliveryActive,
    );
  }

  @override
  Future<SocialPushRegistrationReply> register({
    required String bearer,
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  }) async {
    final response = await _send(
      'PUT',
      bearer: bearer,
      body: {
        'installation_id': installationId,
        'provider': 'fcm',
        'registration': registrationToken,
        'platform': platform,
        'permission_status': permissionStatus,
        'mutation_revision': '$mutationRevision',
      },
    );
    final json = _successJson(response);
    if (json['registered'] != true ||
        json['delivery_active'] is! bool ||
        json['mutation_revision'] != '$mutationRevision') {
      throw SocialPushApiException(statusCode: response.statusCode);
    }
    return SocialPushRegistrationReply(
      registered: true,
      deliveryActive: json['delivery_active'] as bool,
    );
  }

  @override
  Future<void> unregister({
    required String bearer,
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  }) async {
    final response = await _send(
      'DELETE',
      bearer: bearer,
      body: {
        'installation_id': installationId,
        'mutation_revision': '$mutationRevision',
        'reason': reason.wireName,
      },
    );
    final json = _successJson(response);
    final cleanup = json['installation_cleanup'];
    if (json['registered'] != false ||
        json['delivery_active'] != false ||
        json['mutation_revision'] != '$mutationRevision' ||
        cleanup is! Map<String, dynamic> ||
        cleanup['installation_id'] != installationId ||
        cleanup['environment'] != expectedEnvironment ||
        cleanup['mutation_revision'] != '$mutationRevision') {
      throw SocialPushApiException(statusCode: response.statusCode);
    }
  }

  Future<http.Response> _send(
    String method, {
    required String bearer,
    Uri? endpoint,
    Map<String, Object>? body,
  }) async {
    final request = http.Request(method, endpoint ?? _endpoint)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $bearer',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const SocialPushApiException(statusCode: 0);
    } catch (_) {
      // Provider tokens and bearer headers must not leak through a transport
      // exception's string representation.
      throw const SocialPushApiException(statusCode: 0);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _error(response);
    }
    return response;
  }

  Map<String, dynamic> _successJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['success'] == true &&
          decoded['environment'] == expectedEnvironment &&
          decoded['firebase_project_id'] == expectedFirebaseProjectId) {
        return decoded;
      }
    } catch (_) {
      // Fall through to a body-free error.
    }
    throw SocialPushApiException(statusCode: response.statusCode);
  }

  SocialPushApiException _error(http.Response response) {
    String? code;
    int? latestRevision;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final rawCode = decoded['code'];
        if (rawCode is String &&
            RegExp(r'^[a-z0-9_]{1,64}$').hasMatch(rawCode)) {
          code = rawCode;
        }
        final rawLatest = decoded['latest_mutation_revision'];
        if (rawLatest is String &&
            RegExp(r'^[0-9]{1,19}$').hasMatch(rawLatest)) {
          latestRevision = int.tryParse(rawLatest);
        }
      }
    } catch (_) {
      // Response bodies are untrusted and intentionally discarded.
    }
    return SocialPushApiException(
      statusCode: response.statusCode,
      code: code,
      latestMutationRevision: latestRevision,
    );
  }
}
