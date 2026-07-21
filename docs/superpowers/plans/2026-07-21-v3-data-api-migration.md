# v3 Mobile Data API Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate leaderboard/data API calls from v2 (`participant_id`-addressed) to token-scoped v3 (`/api/v3/mobile/*`), dropping `participant_id`, injecting the session token, bouncing to auth on 401, and gating guests behind a "sign in to view" card.

**Architecture:** In-place migration of `LeaderboardApiService` (keeps the class name — many test fakes extend it). Token + `onUnauthorized` injected via ctor callbacks wired in its Riverpod provider. Providers re-gate on `isAuthenticatedProvider`. New `SignInToViewCard` on data screens. `LogShareService` → v3 `/logs`.

**Tech Stack:** Riverpod, `http` + `createAppHttpClient()`, existing `{success,data}` envelope. Depends on the `feat/v3-mobile-auth` module (`authTokenStoreProvider`, `authStatusProvider`, `AuthStatus`, `onUnauthorized()`, `AppRoutes.authLanding`).

## Global Constraints

- Package import prefix `package:crypto_mobile_app/...`.
- v3 data base: `AppConfig.mobileApiV3BaseUrl`; auth base becomes `"$mobileApiV3BaseUrl/auth"`; `register` alone stays on `AppConfig.leaderboardApiBaseUrl` (v2).
- Session token attached as `Authorization: Bearer <token>` on data calls; a 401 calls `onUnauthorized()` then throws.
- Guest gating: `AuthStatus.guest`/`unauthenticated` → gated; `unknown` → loading (never flash the card).
- `participantIdProvider` is NOT removed (node/local uses remain).
- After Dart changes: `dart format .` + `flutter analyze` clean; each phase ends with a green `flutter test`.
- One branch `feat/v3-data-api-migration` off `feat/v3-mobile-auth`; a commit per phase.

---

## Phase 1 — Config, token plumbing, service

### Task 1: v3 base URL config

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Test: `test/core/config/mobile_api_v3_base_url_test.dart`

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

void main() {
  test('mobileApiV3BaseUrl path is /api/v3/mobile', () {
    expect(Uri.parse(AppConfig.mobileApiV3BaseUrl).path, '/api/v3/mobile');
  });
  test('authApiBaseUrl is the /auth sibling of the v3 base', () {
    expect(AppConfig.authApiBaseUrl, '${AppConfig.mobileApiV3BaseUrl}/auth');
  });
}
```

- [ ] **Step 2: Run → FAIL** (`flutter test test/core/config/mobile_api_v3_base_url_test.dart`)

- [ ] **Step 3: Implement.** Add `mobileApiV3BaseUrl` and re-point `authApiBaseUrl`:

```dart
  // v3 mobile API (token-scoped data + auth). Same host as v2 leaderboard.
  static const String mobileApiV3BaseUrl = String.fromEnvironment(
    'MOBILE_API_V3_BASE_URL',
    defaultValue: 'https://leaderboard.usernodelabs.org/api/v3/mobile',
  );
```

Replace the existing `authApiBaseUrl` getter (from the auth branch) with:

```dart
  // v3 auth endpoints live under the v3 mobile base.
  static String get authApiBaseUrl => '$mobileApiV3BaseUrl/auth';
```

- [ ] **Step 4: Run → PASS**; also `flutter test test/core/config/auth_base_url_test.dart` (may need its host assertion relaxed — the auth test asserts host equals `registrationEndpoint` host, still true since both default to `leaderboard.usernodelabs.org`; leave as-is).

- [ ] **Step 5: Commit** (fold into the Phase 1 commit at Task 3).

---

### Task 2: Token providers

**Files:**
- Modify: `lib/features/auth/providers/auth_providers.dart` (append)
- Test: `test/features/auth/providers/session_token_providers_test.dart`

**Interfaces:**
- Produces: `sessionTokenProvider` → `FutureProvider<String?>`; `isAuthenticatedProvider` → `Provider<bool>`.

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('sessionTokenProvider returns stored token', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(sessionTokenProvider.future), 'sess-1');
  });

  test('isAuthenticatedProvider reflects status', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(authStatusProvider); // instantiate -> load()
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(c.read(isAuthenticatedProvider), true);
  });
}
```

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement.** Append to `auth_providers.dart`:

```dart
/// The current session token (null when none stored). Async because it reads
/// secure storage; callers that need it per-request use it directly.
final sessionTokenProvider = FutureProvider<String?>(
    (ref) => ref.watch(authTokenStoreProvider).read());

/// True only when a session is fully established.
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authStatusProvider) == AuthStatus.authenticated);
```

- [ ] **Step 4: Run → PASS**

---

### Task 3: Migrate `LeaderboardApiService` to v3

**Files:**
- Modify: `lib/core/services/leaderboard_api_service.dart`
- Test: `test/core/services/leaderboard_api_service_test.dart` (update)

**Interfaces (new signatures — later phases depend on these):**
- `LeaderboardApiService({String? baseUrl, http.Client? httpClient, bool? writesEnabled, int? maxGetRetries, Duration? retryBaseDelay, Future<String?> Function()? tokenProvider, Future<void> Function()? onUnauthorized})`
- `getRanking({int? seasonId, int? eventId})`
- `getBreakdown({int? seasonId, int? eventId})`
- `getEventPoints({required int eventId})`
- `getChallenges({int? seasonId, int? eventId, bool? activeOnly, bool? onlyScheduled})`
- `getCurrentTerms()` → `Future<CurrentTerms?>`
- `postTermsConsent({required int termsVersionId, required String appVersion})`
- `completeZkPassport({required int challengeId, required String walletAddress, required String sessionId, required String nullifierHex, String? completedAt})`
- `getLeaderboard`, `getSeasons`, `register` — signatures unchanged (register stays v2).

- [ ] **Step 1: Update the test first.** In `test/core/services/leaderboard_api_service_test.dart`:
  - Change `_baseUrl` to `'https://test.example.com/api/v3/mobile'`.
  - Remove every `participantId:` argument from calls to `getRanking`/`getBreakdown`/`getEventPoints`/`getChallenges`/`getCurrentTerms`/`postTermsConsent`/`completeZkPassport`, and drop `participant_id` from any asserted query strings/bodies.
  - Add a token test:

```dart
  test('attaches Bearer token from tokenProvider on GET', () async {
    String? auth;
    final service = LeaderboardApiService(
      baseUrl: _baseUrl,
      httpClient: _mockClient(200, _envelope({'rank': 1}),
          onRequest: (r) => auth = r.headers['authorization']),
      tokenProvider: () async => 'sess-xyz',
    );
    await service.getRanking(seasonId: 1);
    expect(auth, 'Bearer sess-xyz');
  });

  test('401 invokes onUnauthorized then throws', () async {
    var cleared = false;
    final service = LeaderboardApiService(
      baseUrl: _baseUrl,
      httpClient: _mockClient(401, {'error': 'unauth'}),
      tokenProvider: () async => 'sess-xyz',
      onUnauthorized: () async => cleared = true,
      maxGetRetries: 0,
    );
    await expectLater(
        () => service.getRanking(seasonId: 1), throwsA(isA<LeaderboardApiException>()));
    expect(cleared, true);
  });
```

- [ ] **Step 2: Run → FAIL** (`flutter test test/core/services/leaderboard_api_service_test.dart`)

- [ ] **Step 3: Implement service changes.**

Constructor + fields — change the base default and add callbacks:

```dart
  LeaderboardApiService({
    String? baseUrl,
    http.Client? httpClient,
    bool? writesEnabled,
    int? maxGetRetries,
    Duration? retryBaseDelay,
    Future<String?> Function()? tokenProvider,
    Future<void> Function()? onUnauthorized,
  })  : _baseUrl = baseUrl ?? AppConfig.mobileApiV3BaseUrl,
        _http = httpClient ?? createAppHttpClient(),
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly,
        _maxGetRetries = maxGetRetries ?? 2,
        _retryBaseDelay = retryBaseDelay ?? const Duration(milliseconds: 300),
        _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized;

  final Future<String?> Function()? _tokenProvider;
  final Future<void> Function()? _onUnauthorized;
```

Auth header helper:

```dart
  Future<Map<String, String>> _authHeaders(Map<String, String> base) async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return base;
    return {...base, 'Authorization': 'Bearer $token'};
  }
```

`register` keeps v2 — post to the v2 URL explicitly:

```dart
  Future<RegistrationV2Result> register({
    required String registrationCode,
    required String identifier,
  }) async {
    _ensureWritesEnabled();
    final data = await _postAbsolute(
      '${AppConfig.leaderboardApiBaseUrl}/register',
      body: {'registration_code': registrationCode, 'identifier': identifier},
    );
    return RegistrationV2Result.fromJson(data as Map<String, dynamic>);
  }
```

`getRanking` (drop participant_id):

```dart
  Future<RankingResult> getRanking({int? seasonId, int? eventId}) async {
    final params = <String, String>{};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }
    final data = await _get('/me/ranking', queryParams: params);
    return RankingResult.fromJson(data as Map<String, dynamic>);
  }
```

`getChallenges` (drop participant_id param entirely):

```dart
  Future<List<ChallengeDto>> getChallenges({
    int? seasonId,
    int? eventId,
    bool? activeOnly,
    bool? onlyScheduled,
  }) async {
    final params = <String, String>{};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }
    if (activeOnly != null) params['active_only'] = activeOnly ? '1' : '0';
    if (onlyScheduled == true) params['only_scheduled'] = '1';
    final data = await _get('/challenges', queryParams: params);
    return (data as List)
        .map((e) => ChallengeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
```

`getBreakdown` (drop participant_id):

```dart
  Future<BreakdownResult> getBreakdown({int? seasonId, int? eventId}) async {
    final params = <String, String>{'include_activity': '1'};
    if (eventId != null) {
      params['event_id'] = eventId.toString();
    } else if (seasonId != null) {
      params['season_id'] = seasonId.toString();
    }
    final data = await _get('/me/breakdown', queryParams: params);
    return BreakdownResult.fromJson(data as Map<String, dynamic>);
  }
```

`getEventPoints` (drop participant_id):

```dart
  Future<EventPointsResult> getEventPoints({required int eventId}) async {
    final data = await _get('/event/points',
        queryParams: {'event_id': eventId.toString()});
    return EventPointsResult.fromJson(data as Map<String, dynamic>);
  }
```

`completeZkPassport` (drop participant_id, add optional completed_at):

```dart
  Future<bool> completeZkPassport({
    required int challengeId,
    required String walletAddress,
    required String sessionId,
    required String nullifierHex,
    String? completedAt,
  }) async {
    _ensureWritesEnabled();
    try {
      await _post('/zkpassport/complete', body: {
        'challenge_id': challengeId,
        'wallet_address': walletAddress,
        'session_id': sessionId,
        'nullifier_hex': nullifierHex,
        if (completedAt != null) 'completed_at': completedAt,
      });
      return true;
    } on LeaderboardApiException catch (e) {
      if (e.statusCode == 409) return true;
      rethrow;
    }
  }
```

`getCurrentTerms` / `postTermsConsent` (drop participant_id):

```dart
  Future<CurrentTerms?> getCurrentTerms() async {
    try {
      final data =
          await _get('/terms/current', expectedStatuses: const {404});
      return CurrentTerms.fromJson(data as Map<String, dynamic>);
    } on LeaderboardApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> postTermsConsent({
    required int termsVersionId,
    required String appVersion,
  }) async {
    _ensureWritesEnabled();
    await _post(
      '/terms/consent',
      body: {
        'terms_version_id': termsVersionId,
        'status': TermsConsentStatus.accepted,
        'app_version': appVersion,
      },
      expectedStatuses: const {422},
    );
  }
```

`_get`/`_post` — attach auth headers and handle 401; add `_postAbsolute` for register:

```dart
  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParams,
    Set<int> expectedStatuses = const {},
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final url = queryParams != null && queryParams.isNotEmpty
        ? uri.replace(queryParameters: queryParams)
        : uri;
    _log.trace('GET $url');
    final headers = await _authHeaders(_acceptJson);
    final resp = await _sendWithRetry(() => _http.get(url, headers: headers));
    return _parseEnvelope(resp, url, expectedStatuses: expectedStatuses);
  }

  Future<dynamic> _post(
    String path, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
  }) async {
    return _postAbsolute('$_baseUrl$path',
        body: body, expectedStatuses: expectedStatuses);
  }

  Future<dynamic> _postAbsolute(
    String absoluteUrl, {
    required Map<String, dynamic> body,
    Set<int> expectedStatuses = const {},
  }) async {
    final url = Uri.parse(absoluteUrl);
    _log.trace('POST $url');
    final headers = await _authHeaders(_jsonHeaders);
    final resp = await _send(
        () => _http.post(url, headers: headers, body: jsonEncode(body)));
    return _parseEnvelope(resp, url, expectedStatuses: expectedStatuses);
  }
```

In `_parseEnvelope`, before the final `throw` for a non-2xx, add 401 handling:

```dart
    if (resp.statusCode == 401) {
      await _onUnauthorized?.call();
    }
```

(place it right after the Sentry capture block, before `throw LeaderboardApiException(...)`.)

Wire the provider callbacks:

```dart
final leaderboardApiServiceProvider = Provider<LeaderboardApiService>((ref) {
  final service = LeaderboardApiService(
    tokenProvider: () => ref.read(authTokenStoreProvider).read(),
    onUnauthorized: () => ref.read(authStatusProvider.notifier).onUnauthorized(),
  );
  ref.onDispose(service.dispose);
  return service;
});
```

Add imports to the service file:

```dart
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
```

- [ ] **Step 4: Run service tests → PASS** (`flutter test test/core/services/leaderboard_api_service_test.dart`). Fix any residual `participant_id` assertions.

- [ ] **Step 5: Commit Phase 1**

```bash
dart format lib/core/config/app_config.dart lib/core/services/leaderboard_api_service.dart lib/features/auth/providers/auth_providers.dart test/
git add -A
git commit -m "feat(migration): v3 base URL, token plumbing, LeaderboardApiService v3"
```

---

## Phase 2 — Providers & call sites

### Task 4: Re-gate providers on auth, drop participant_id at call sites

**Files (modify):**
- `lib/core/providers/ranking_provider.dart`
- `lib/core/providers/points_breakdown_provider.dart`
- `lib/core/providers/event_points_provider.dart`
- `lib/core/providers/challenges_provider.dart`
- `lib/core/providers/profile_completed_challenges_provider.dart`
- `lib/core/providers/leaderboard_bootstrap.dart`
- `lib/features/terms/providers/terms_provider.dart`
- `lib/features/zkpassport/providers/zkpassport_flow_provider.dart`
- Tests: the provider/terms/profile tests listed in the spec.

**Rule:** replace `ref.watch(participantIdProvider).valueOrNull != null` gates with `ref.watch(isAuthenticatedProvider)`, and drop `participantId:` from every migrated call. Import `package:crypto_mobile_app/features/auth/providers/auth_providers.dart` where needed.

- [ ] **Step 1: `ranking_provider.dart`**

```dart
  @override
  bool watchDeps() {
    final authed = ref.watch(isAuthenticatedProvider);
    final ctx = ref.watch(seasonEventContextProvider);
    return authed && (ctx.eventId != null || ctx.seasonId != null);
  }

  @override
  Future<RankingResult> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getRanking(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
    );
  }
```

- [ ] **Step 2: `points_breakdown_provider.dart`** — gate `authed && (ctx.eventId != null || ctx.seasonId != null)`; `fetch()` drops the `participantId` read and the `participantId:` arg. Keep the `participantEventIdsProvider` update logic unchanged.

- [ ] **Step 3: `event_points_provider.dart`** — gate `authed && ctx.seasonId != null && ctx.eventId != null`; `fetch()` calls `getEventPoints(eventId: ctx.eventId!)`.

- [ ] **Step 4: `challenges_provider.dart`** — `watchDeps` watches `seasonEventContextProvider` + `isAuthenticatedProvider`, returns the authed bool; `fetch()` drops `participantId`. (Challenges still load for authed users; completion reflects the token's participant.)

```dart
  @override
  bool watchDeps() {
    ref.watch(seasonEventContextProvider);
    return ref.watch(isAuthenticatedProvider);
  }

  @override
  Future<List<ChallengeDto>> fetch() async {
    final ctx = ref.read(seasonEventContextProvider);
    final service = ref.read(leaderboardApiServiceProvider);
    return service.getChallenges(
      seasonId: ctx.eventId == null ? ctx.seasonId : null,
      eventId: ctx.eventId,
      activeOnly: true,
    );
  }
```

- [ ] **Step 5: `profile_completed_challenges_provider.dart`** — replace the `participantIdProvider` guard with auth:

```dart
final profileCompletedChallengesProvider =
    FutureProvider<ProfileCompletedChallengeHistory?>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  final ctx = ref.watch(seasonEventContextProvider);
  final service = ref.read(leaderboardApiServiceProvider);
  final seasonId = ctx.seasonId;
  final breakdown = await service.getBreakdown(seasonId: seasonId);
  final challenges = await _fetchProfileChallenges(
      service: service, seasonId: seasonId, breakdown: breakdown);
  // ...unchanged enrich/filter...
});
```

And `_fetchProfileChallenges` drops `required int participantId` and the `participantId:` args in its three `getChallenges` calls.

- [ ] **Step 6: `leaderboard_bootstrap.dart`** — the freshness backfill `getRanking(participantId: participantId, seasonId: currentSeasonId)` becomes `getRanking(seasonId: currentSeasonId)`. `getSeasons()` unchanged. (This runs post-registration; the participant is still available locally for logging, just not passed to the API.)

- [ ] **Step 7: `terms_provider.dart`** — `watchDeps` → `ref.watch(isAuthenticatedProvider)`; `fetch()` → `getCurrentTerms()`; `acceptCurrentTerms()` drops the participant guard/arg → `postTermsConsent(termsVersionId: terms.id, appVersion: ...)`.

- [ ] **Step 8: `zkpassport_flow_provider.dart`** — both `completeZkPassport(...)` calls drop `participantId:` (keep `challengeId`, `walletAddress`, `sessionId`, `nullifierHex`).

- [ ] **Step 9: Update tests.** For each provider test using `_RecordingLeaderboardApiService`/`_FakeService extends LeaderboardApiService`, update the overridden method signatures to match Task 3, remove `participant_id` expectations, and override `isAuthenticatedProvider`/`authStatusProvider` to authenticated where the provider now gates on it (e.g. `ProviderContainer(overrides: [isAuthenticatedProvider.overrideWithValue(true)])`). Update `terms_provider_test`, `terms_screen_test`, `profile_screen_test` similarly.

- [ ] **Step 10: Analyze + full test → green**

```bash
dart format .
flutter analyze
flutter test
```

- [ ] **Step 11: Commit Phase 2**

```bash
git add -A
git commit -m "feat(migration): re-gate leaderboard providers on auth, drop participant_id"
```

---

## Phase 3 — Guest gated UI

### Task 5: `SignInToViewCard` on data screens

**Files:**
- Create: `lib/features/auth/widgets/sign_in_to_view_card.dart`
- Modify: data screens — profile, leaderboard, challenges, terms (exact files confirmed by grepping `ref.watch(rankingProvider|breakdownProvider|challengesProvider|leaderboardProvider|currentTermsProvider)` in `lib/features/*/screens`).
- Add ARB: `authSignInToViewTitle`, `authSignInToViewCta`; run `flutter gen-l10n`.
- Test: `test/features/auth/widgets/sign_in_to_view_card_test.dart` + one screen test asserting the card shows for a guest.

- [ ] **Step 1: ARB strings** (append to `app_en.arb`, then `flutter gen-l10n`):

```json
  "authSignInToView": "Sign in to view your progress",
  "@authSignInToView": { "description": "Guest gate title on data screens" },
  "authSignInToViewCta": "Sign in",
  "@authSignInToViewCta": { "description": "Guest gate button" }
```

- [ ] **Step 2: Widget**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';

class SignInToViewCard extends StatelessWidget {
  const SignInToViewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.authSignInToView,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Button(
              label: l.authSignInToViewCta,
              variant: ButtonVariant.primary,
              onTap: () => context.go(AppRoutes.authLanding),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Wire into each data screen.** At the top of the relevant `build`, when the user is a guest show the card instead of the data body:

```dart
final status = ref.watch(authStatusProvider);
if (status == AuthStatus.guest || status == AuthStatus.unauthenticated) {
  return const SignInToViewCard(); // wrap in the screen's Scaffold/appbar as needed
}
```

Apply to each screen consuming a migrated provider. `unknown` falls through to the existing loading UI.

- [ ] **Step 4: Widget test** — pumps `SignInToViewCard`, taps the button, asserts navigation to `AppRoutes.authLanding` (use a minimal `GoRouter` harness). Plus one screen test with `authStatusProvider` overridden to `guest` asserting the card renders.

- [ ] **Step 5: Analyze + test → green; Commit Phase 3**

```bash
git add -A
git commit -m "feat(migration): guest sign-in-to-view gate on data screens"
```

---

## Phase 4 — Device logs → v3

### Task 6: `LogShareService` to v3 `/logs`

**Files:**
- Modify: `lib/core/services/log_share_service.dart`
- Modify: `lib/core/providers/log_share_provider.dart`
- Test: create `test/core/services/log_share_service_test.dart`

- [ ] **Step 1: Failing test** — MockClient asserting `POST {base}/logs` (no participant segment), `Authorization: Bearer` present, `{continue:true}` → `keepGoing`, `{continue:false}` → `stop`, 401 → `stop`, no token → skip/`stop`.

- [ ] **Step 2: Run → FAIL**

- [ ] **Step 3: Implement.** In `LogShareService`:
  - Base default → `AppConfig.mobileApiV3BaseUrl`.
  - ctor adds `Future<String?> Function()? tokenProvider`.
  - `postLogs` drops `required int participantId`; URL becomes `Uri.parse('$_baseUrl/logs')`; add `Authorization: Bearer <token>` header (fetched via `tokenProvider`); if no token, return `LogShareOutcome.stop` without sending. Treat 401 as `stop`. Keep `{continue}`/5xx-retry logic.

```dart
  Future<LogShareOutcome> postLogs({required Map<String, dynamic> body}) async {
    final token = await _tokenProvider?.call();
    if (token == null || token.isEmpty) return LogShareOutcome.stop;
    final url = Uri.parse('$_baseUrl/logs');
    final headers = {..._headers, 'Authorization': 'Bearer $token'};
    // ...existing retry loop, using `headers`; add: if (resp.statusCode == 401) return LogShareOutcome.stop;
  }
```

- [ ] **Step 4: Update `log_share_provider.dart`.** Construct `LogShareService(tokenProvider: () => ref.read(authTokenStoreProvider).read())` (thread `ref`/token into the controller), gate flushing on `isAuthenticatedProvider`, and call `_service.postLogs(body: _buildBody(toSend))` (drop `participantId:`). Remove now-unused participant plumbing in the flush path.

- [ ] **Step 5: Run → PASS; analyze + full test → green**

- [ ] **Step 6: Commit Phase 4**

```bash
git add -A
git commit -m "feat(migration): device logs upload to v3 /logs with session token"
```

---

## Self-review notes

- **Spec coverage:** base/token/service → Phase 1; participant_id removal + auth gating → Phase 2; guest UI → Phase 3; logs → Phase 4; 401→onUnauthorized → Task 3; `register` untouched (v2 via `_postAbsolute`) → Task 3.
- **Type consistency:** new service signatures in Task 3 match every call-site edit in Task 4; `isAuthenticatedProvider`/`sessionTokenProvider` names consistent across Tasks 2/4/5/6.
- **Test-fake ripple:** because the class name `LeaderboardApiService` is preserved, `extends`-based fakes only need signature updates (Task 4 Step 9), not rewrites.
- **Screen list:** Phase 3 finalizes the exact screen files by grep at execution time; the gate condition (`guest`/`unauthenticated`, not `unknown`) is fixed.
