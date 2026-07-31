import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/identity/identity.dart';
import 'package:crypto_mobile_app/core/identity/identity_scope.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';

class _FakeService extends LeaderboardApiService {
  _FakeService({this.terms});

  final CurrentTerms? terms;
  final List<Map<String, dynamic>> posted = [];

  @override
  Future<CurrentTerms?> getCurrentTerms({
    required AuthenticatedUserLease authority,
  }) async =>
      terms;

  @override
  Future<void> postTermsConsent({
    required int termsVersionId,
    required String appVersion,
    required AuthenticatedUserLease authority,
  }) async {
    if (!authority.isCurrent) {
      throw const StaleIdentityLeaseException();
    }
    posted.add({
      'terms_version_id': termsVersionId,
      'status': TermsConsentStatus.accepted,
    });
  }

  @override
  void dispose() {}
}

AuthenticatedUserLease _publishOwner({int epoch = 7, int participantId = 1}) {
  final identity = Identity(
    epoch: epoch,
    phase: IdentityPhase.ready,
    participantId: participantId,
    accountId: 'account-$participantId',
    address: 'address-$participantId',
  );
  IdentitySnapshots.publish(identity);
  return AuthenticatedUserLease.capture(identity)!;
}

CurrentTerms _terms({bool accepted = false, int id = 3}) => CurrentTerms(
      id: id,
      version: '1.0',
      title: 'Terms',
      termsLink: 'https://example.com/terms',
      consent: TermsConsent(
        status: accepted ? TermsConsentStatus.accepted : null,
        accepted: accepted,
      ),
    );

ProviderContainer _container(
  _FakeService service, {
  Future<String>? appVersion,
}) {
  final owner = _publishOwner();
  final container = ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(true),
      authenticatedUserLeaseProvider.overrideWithValue(owner),
      leaderboardApiServiceProvider.overrideWithValue(service),
      if (appVersion != null)
        termsAppVersionProvider.overrideWith((ref) => appVersion),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(IdentitySnapshots.reset);
  tearDown(IdentitySnapshots.reset);

  test('loads the current acceptance status', () async {
    final container = _container(_FakeService(terms: _terms(accepted: true)));

    final snapshot = await container.read(currentTermsProvider.future);

    expect(snapshot!.terms!.consent!.accepted, isTrue);
  });

  test('acceptCurrentTerms only posts accepted for the loaded version',
      () async {
    final service = _FakeService(terms: _terms(id: 7));
    final container = _container(service);
    await container.read(currentTermsProvider.future);

    await container.read(currentTermsProvider.notifier).acceptCurrentTerms();

    expect(service.posted, [
      {'terms_version_id': 7, 'status': 'accepted'},
    ]);
  });

  test('does not post without a published version', () async {
    final service = _FakeService(terms: null);
    final container = _container(service);
    await container.read(currentTermsProvider.future);

    expect(
      container.read(currentTermsProvider.notifier).acceptCurrentTerms,
      throwsA(isA<StateError>()),
    );
    expect(service.posted, isEmpty);
  });

  test('does not post terms loaded by a replaced identity', () async {
    final service = _FakeService(terms: _terms(id: 7));
    final container = _container(service);
    await container.read(currentTermsProvider.future);

    _publishOwner(epoch: 8, participantId: 2);

    await expectLater(
      container.read(currentTermsProvider.notifier).acceptCurrentTerms(),
      throwsA(isA<StaleIdentityLeaseException>()),
    );
    expect(service.posted, isEmpty);
  });

  test('does not adopt a replacement identity while resolving app version',
      () async {
    final version = Completer<String>();
    final service = _FakeService(terms: _terms(id: 7));
    final container = _container(service, appVersion: version.future);
    await container.read(currentTermsProvider.future);

    final acceptance =
        container.read(currentTermsProvider.notifier).acceptCurrentTerms();
    await pumpEventQueue();
    _publishOwner(epoch: 8, participantId: 2);
    version.complete('2.0.0');

    await expectLater(
      acceptance,
      throwsA(isA<StaleIdentityLeaseException>()),
    );
    expect(service.posted, isEmpty);
  });
}
