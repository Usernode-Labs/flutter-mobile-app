import 'dart:convert';

import 'package:crypto_mobile_app/features/social_notifications/social_push_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/session_authority_test_helpers.dart';

const _baseUrl = 'https://social.example.test/api/v4/mobile///';
const _endpoint = 'https://social.example.test/api/v4/mobile/push-registration';
const _bearer = 'mobile-bearer-secret';
const _registration = 'fcm-registration-secret';
const _installationId = '5b35e700-267d-4aa1-8702-e6e731a0ed13';
const _environment = 'production';
const _firebaseProjectId = 'usernode-test';
final _credential = testCredentialLease(
  epoch: 7,
  token: _bearer,
  sessionId: 'session-a',
  credentialRef: 'credential-a',
  credentialGeneration: 3,
);

Future<SocialPushRegistrationReply> _register(
  _ApiHarness api, {
  int mutationRevision = 42,
}) =>
    api.register(
      installationId: _installationId,
      registrationToken: _registration,
      platform: 'ios',
      permissionStatus: 'authorized',
      mutationRevision: mutationRevision,
    );

class _ApiHarness {
  _ApiHarness({required http.Client client})
      : _api = HttpSocialPushRegistrationApi(
          mobileApiBaseUrl: _baseUrl,
          expectedEnvironment: _environment,
          expectedFirebaseProjectId: _firebaseProjectId,
          client: client,
        );

  final HttpSocialPushRegistrationApi _api;

  Future<SocialPushRegistrationReply> getStatus({
    required String installationId,
  }) =>
      _api.getStatus(
        credential: _credential,
        installationId: installationId,
      );

  Future<SocialPushRegistrationReply> register({
    required String installationId,
    required String registrationToken,
    required String platform,
    required String permissionStatus,
    required int mutationRevision,
  }) =>
      _api.register(
        credential: _credential,
        installationId: installationId,
        registrationToken: registrationToken,
        platform: platform,
        permissionStatus: permissionStatus,
        mutationRevision: mutationRevision,
      );

  Future<void> unregister({
    required String installationId,
    required int mutationRevision,
    required SocialPushUnregisterReason reason,
  }) =>
      _api.unregister(
        credential: _credential,
        installationId: installationId,
        mutationRevision: mutationRevision,
        reason: reason,
      );
}

void main() {
  test('PUT sends the captured bearer through the injected HTTP client',
      () async {
    late http.Request capturedRequest;
    final api = HttpSocialPushRegistrationApi(
      mobileApiBaseUrl: _baseUrl,
      expectedEnvironment: _environment,
      expectedFirebaseProjectId: _firebaseProjectId,
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'registered': true,
            'delivery_active': false,
            'mutation_revision': '42',
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
          }),
          200,
        );
      }),
    );

    final reply = await api.register(
      credential: _credential,
      installationId: _installationId,
      registrationToken: _registration,
      platform: 'ios',
      permissionStatus: 'authorized',
      mutationRevision: 42,
    );

    expect(capturedRequest.method, 'PUT');
    expect(capturedRequest.headers['authorization'], 'Bearer $_bearer');
    expect(reply.registered, isTrue);
  });

  test('PUT sends the exact registration contract and parses its ack',
      () async {
    late http.Request captured;
    final api = _ApiHarness(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'registered': true,
            'delivery_active': false,
            'mutation_revision': '42',
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
          }),
          200,
        );
      }),
    );

    final reply = await _register(api);

    expect(captured.method, 'PUT');
    expect(captured.url.toString(), _endpoint);
    expect(captured.headers['authorization'], 'Bearer $_bearer');
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers['content-type'], 'application/json; charset=utf-8');
    expect(jsonDecode(captured.body), {
      'installation_id': _installationId,
      'provider': 'fcm',
      'registration': _registration,
      'platform': 'ios',
      'permission_status': 'authorized',
      'mutation_revision': '42',
    });
    expect(reply.registered, isTrue);
    expect(reply.deliveryActive, isFalse);
  });

  test('GET sends only the installation query and reads delivery status',
      () async {
    late http.Request captured;
    final api = _ApiHarness(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'registered': true,
            'delivery_active': false,
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
          }),
          200,
        );
      }),
    );

    final reply = await api.getStatus(
      installationId: _installationId,
    );

    expect(captured.method, 'GET');
    expect(captured.url.path, Uri.parse(_endpoint).path);
    expect(captured.url.queryParameters, {
      'installation_id': _installationId,
    });
    expect(captured.body, isEmpty);
    expect(captured.headers, isNot(contains('content-type')));
    expect(reply.registered, isTrue);
    expect(reply.deliveryActive, isFalse);
  });

  test('DELETE sends the installation fence and validates its exact ack',
      () async {
    late http.Request captured;
    final api = _ApiHarness(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'registered': false,
            'delivery_active': false,
            'mutation_revision': '43',
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
            'installation_cleanup': {
              'installation_id': _installationId,
              'environment': 'production',
              'mutation_revision': '43',
            },
          }),
          200,
        );
      }),
    );

    await api.unregister(
      installationId: _installationId,
      mutationRevision: 43,
      reason: SocialPushUnregisterReason.notificationsDisabled,
    );

    expect(captured.method, 'DELETE');
    expect(captured.url.toString(), _endpoint);
    expect(captured.headers['authorization'], 'Bearer $_bearer');
    expect(jsonDecode(captured.body), {
      'installation_id': _installationId,
      'mutation_revision': '43',
      'reason': 'notifications_disabled',
    });
  });

  test('409 exposes only stable conflict metadata', () async {
    final api = _ApiHarness(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'untrusted diagnostic text',
            'code': 'push_mutation_conflict',
            'latest_mutation_revision': '91',
          }),
          409,
        ),
      ),
    );

    await expectLater(
      _register(api),
      throwsA(
        isA<SocialPushApiException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having(
              (error) => error.code,
              'code',
              'push_mutation_conflict',
            )
            .having(
              (error) => error.latestMutationRevision,
              'latestMutationRevision',
              91,
            ),
      ),
    );
  });

  test('PUT rejects a successful response without the exact revision ack',
      () async {
    final api = _ApiHarness(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'registered': true,
            'delivery_active': true,
            'mutation_revision': '41',
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
          }),
          200,
        ),
      ),
    );

    await expectLater(
      _register(api),
      throwsA(
        isA<SocialPushApiException>()
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  test('DELETE rejects a cleanup ack for another installation', () async {
    final api = _ApiHarness(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'registered': false,
            'delivery_active': false,
            'mutation_revision': '43',
            'environment': _environment,
            'firebase_project_id': _firebaseProjectId,
            'installation_cleanup': {
              'installation_id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              'environment': _environment,
              'mutation_revision': '43',
            },
          }),
          200,
        ),
      ),
    );

    await expectLater(
      api.unregister(
        installationId: _installationId,
        mutationRevision: 43,
        reason: SocialPushUnregisterReason.permissionDenied,
      ),
      throwsA(
        isA<SocialPushApiException>()
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });

  test('PUT, GET, and DELETE reject another deployment identity', () async {
    final api = _ApiHarness(
      client: MockClient((request) async {
        final response = <String, Object?>{
          'success': true,
          'registered': request.method == 'PUT',
          'delivery_active': false,
          'environment': 'staging',
          'firebase_project_id': 'another-project',
        };
        if (request.method != 'GET') {
          response['mutation_revision'] = '42';
        }
        if (request.method == 'DELETE') {
          response['installation_cleanup'] = {
            'installation_id': _installationId,
            'environment': 'staging',
            'mutation_revision': '42',
          };
        }
        return http.Response(jsonEncode(response), 200);
      }),
    );

    final operations = <Future<Object?> Function()>[
      () => _register(api),
      () => api.getStatus(
            installationId: _installationId,
          ),
      () => api.unregister(
            installationId: _installationId,
            mutationRevision: 42,
            reason: SocialPushUnregisterReason.identityBoundary,
          ),
    ];
    for (final operation in operations) {
      await expectLater(
        operation(),
        throwsA(
          isA<SocialPushApiException>()
              .having((error) => error.statusCode, 'statusCode', 200),
        ),
      );
    }
  });

  test('transport and server failures never expose request secrets', () async {
    final transportApi = _ApiHarness(
      client: MockClient(
        (_) async => throw Exception('$_bearer $_registration'),
      ),
    );

    Object? transportError;
    try {
      await _register(transportApi);
    } catch (error) {
      transportError = error;
    }
    expect(transportError, isA<SocialPushApiException>());
    expect(transportError.toString(), isNot(contains(_bearer)));
    expect(transportError.toString(), isNot(contains(_registration)));

    final serverApi = _ApiHarness(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': '$_bearer $_registration',
            'code': 'invalid code containing $_registration',
            'latest_mutation_revision': _registration,
          }),
          500,
        ),
      ),
    );

    Object? serverError;
    try {
      await _register(serverApi);
    } catch (error) {
      serverError = error;
    }
    expect(serverError, isA<SocialPushApiException>());
    expect(serverError.toString(), isNot(contains(_bearer)));
    expect(serverError.toString(), isNot(contains(_registration)));
    expect((serverError as SocialPushApiException).code, isNull);
    expect(serverError.latestMutationRevision, isNull);
  });
}
