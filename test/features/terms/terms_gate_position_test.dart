import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/models/leaderboard_api_models.dart';
import 'package:crypto_mobile_app/core/providers/leaderboard_participant_provider.dart';
import 'package:crypto_mobile_app/core/services/leaderboard_api_service.dart';
import 'package:crypto_mobile_app/features/terms/screens/terms_screen.dart';

import '../../design_system/helpers/ds_test_helpers.dart';

class _FakeService extends LeaderboardApiService {
  final List<String> posted = [];

  @override
  Future<CurrentTerms?> getCurrentTerms({required int participantId}) async =>
      const CurrentTerms(
        id: 3,
        version: '1.0',
        title: 'Terms of Service',
        bodyMarkdown: 'Body text.',
        consent: TermsConsent(status: null, accepted: false),
      );

  @override
  Future<void> postTermsConsent({
    required int participantId,
    required int termsVersionId,
    required String status,
    required String appVersion,
  }) async =>
      posted.add(status);

  @override
  void dispose() {}
}

/// Mounts the gate exactly where `_AppWrapper` does: inside `MaterialApp.builder`,
/// which Flutter invokes *above* the Router/Navigator (see `widget.builder!(context,
/// routing)` in widgets/app.dart). Anything in the gate that reaches for a
/// Navigator ancestor therefore finds none — a `home:`-mounted test cannot catch it.
Widget _appWithGateOverlay(_FakeService service) {
  return ProviderScope(
    overrides: [
      participantIdProvider.overrideWith((ref) => 19),
      leaderboardApiServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: themeWithExtensions(),
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          child ?? const SizedBox.shrink(),
          const ScaffoldMessenger(child: TermsScreen(gateMode: true)),
        ],
      ),
      home: const Scaffold(body: Center(child: Text('app underneath'))),
    ),
  );
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'crypto_mobile_app',
      packageName: 'org.usernodelabs.app',
      version: '3.2.1',
      buildNumber: '1210',
      buildSignature: '',
    );
  });

  testWidgets('gate accepts when stacked above the Navigator', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(_appWithGateOverlay(service));
    await tester.pumpAndSettle();

    expect(find.text('Accept'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(service.posted, ['accepted']);
  });

  testWidgets('gate refuses when stacked above the Navigator', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(_appWithGateOverlay(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(service.posted, ['refused']);
  });
}
