import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/terms/providers/terms_provider.dart';

/// Records consent posts and returns a scripted `/terms/current`.
class _FakeService extends LeaderboardApiService {
  _FakeService({this.terms, this.getError, this.postError});

  final CurrentTerms? terms;
  final Object? getError;
  final Object? postError;

  final List<Map<String, dynamic>> posted = [];

  @override
  Future<CurrentTerms?> getCurrentTerms({required int participantId}) async {
    if (getError != null) throw getError!;
    return terms;
  }

  @override
  Future<void> postTermsConsent({
    required int participantId,
    required int termsVersionId,
    required String status,
    required String appVersion,
  }) async {
    if (postError != null) throw postError!;
    posted.add({
      'participant_id': participantId,
      'terms_version_id': termsVersionId,
      'status': status,
    });
  }

  @override
  void dispose() {}
}

CurrentTerms _terms({String? status, bool accepted = false, int id = 3}) =>
    CurrentTerms(
      id: id,
      version: '1.0',
      title: 'Terms of Service',
      bodyMarkdown: '# Terms',
      termsLink: 'https://example.com/terms/1.0',
      consent: TermsConsent(status: status, accepted: accepted),
    );

ProviderContainer _container({
  required _FakeService service,
  int? participantId = 19,
}) {
  final container = ProviderContainer(
    overrides: [
      participantIdProvider.overrideWith((ref) => participantId),
      leaderboardApiServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('currentTermsProvider', () {
    test('resolves the published terms', () async {
      final container = _container(service: _FakeService(terms: _terms()));

      final snapshot = await container.read(currentTermsProvider.future);

      expect(snapshot!.isPublished, true);
      expect(snapshot.terms!.id, 3);
    });

    test('reports not-published when the backend 404s', () async {
      final container = _container(service: _FakeService(terms: null));

      final snapshot = await container.read(currentTermsProvider.future);

      // Distinguishable from "deps unsatisfied", which resolves to a null
      // snapshot rather than a snapshot holding null.
      expect(snapshot, isNotNull);
      expect(snapshot!.isPublished, false);
    });

    test('does not fetch before a participant exists', () async {
      final container = _container(
        service: _FakeService(terms: _terms()),
        participantId: null,
      );

      expect(await container.read(currentTermsProvider.future), isNull);
    });
  });

  group('termsGateProvider', () {
    Future<bool> gateFor(CurrentTerms? terms, {Object? getError}) async {
      final container = _container(
        service: _FakeService(terms: terms, getError: getError),
      );
      try {
        await container.read(currentTermsProvider.future);
      } catch (_) {
        // Fail-open path: the gate must cope with a thrown fetch.
      }
      return container.read(termsGateProvider);
    }

    test('opens when the version has never been answered', () async {
      expect(await gateFor(_terms(status: null)), true);
    });

    test('opens when consent is absent entirely', () async {
      expect(
        await gateFor(CurrentTerms(
          id: 3,
          version: '1.0',
          title: 'Terms',
          bodyMarkdown: '# Terms',
        )),
        true,
      );
    });

    test('stays shut after acceptance', () async {
      expect(await gateFor(_terms(status: 'accepted', accepted: true)), false);
    });

    test('stays shut after refusal', () async {
      // The product rule: a refuser is not nagged on every launch. Publishing a
      // new version resets consent server-side, which re-opens the gate without
      // the client caching anything.
      expect(await gateFor(_terms(status: 'refused')), false);
    });

    test('stays shut when nothing is published', () async {
      expect(await gateFor(null), false);
    });

    test('fails open when the terms lookup errors', () async {
      // Failing closed would strand an offline user on a screen whose content
      // comes from the request that just failed. The backend still withholds
      // tokens regardless.
      expect(await gateFor(null, getError: Exception('offline')), false);
    });
  });

  group('submitConsent', () {
    test('posts the loaded version id and status', () async {
      final service = _FakeService(terms: _terms(status: null, id: 7));
      final container = _container(service: service);
      await container.read(currentTermsProvider.future);

      await container
          .read(currentTermsProvider.notifier)
          .submitConsent(TermsConsentStatus.accepted);

      expect(service.posted, [
        {'participant_id': 19, 'terms_version_id': 7, 'status': 'accepted'},
      ]);
    });

    test('posts a refusal', () async {
      final service = _FakeService(terms: _terms(status: null));
      final container = _container(service: service);
      await container.read(currentTermsProvider.future);

      await container
          .read(currentTermsProvider.notifier)
          .submitConsent(TermsConsentStatus.refused);

      expect(service.posted.single['status'], 'refused');
    });

    test('rethrows a failed post so the UI can surface it', () async {
      final service = _FakeService(
        terms: _terms(status: null),
        postError: LeaderboardApiException(422, 'Not published'),
      );
      final container = _container(service: service);
      await container.read(currentTermsProvider.future);

      expect(
        () => container
            .read(currentTermsProvider.notifier)
            .submitConsent(TermsConsentStatus.accepted),
        throwsA(isA<LeaderboardApiException>()),
      );
    });

    test('throws rather than posting a guessed version id', () async {
      final service = _FakeService(terms: null); // nothing published
      final container = _container(service: service);
      await container.read(currentTermsProvider.future);

      expect(
        () => container
            .read(currentTermsProvider.notifier)
            .submitConsent(TermsConsentStatus.accepted),
        throwsA(isA<StateError>()),
      );
      expect(service.posted, isEmpty);
    });
  });
}
