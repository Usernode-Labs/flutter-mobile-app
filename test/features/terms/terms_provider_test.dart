import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';

class _FakeService extends LeaderboardApiService {
  _FakeService({this.terms});

  final CurrentTerms? terms;
  final List<Map<String, dynamic>> posted = [];

  @override
  Future<CurrentTerms?> getCurrentTerms() async => terms;

  @override
  Future<void> postTermsConsent({
    required int termsVersionId,
    required String appVersion,
  }) async {
    posted.add({
      'terms_version_id': termsVersionId,
      'status': TermsConsentStatus.accepted,
    });
  }

  @override
  void dispose() {}
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

ProviderContainer _container(_FakeService service) {
  final container = ProviderContainer(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(true),
      leaderboardApiServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
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
}
