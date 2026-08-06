# v3 Mobile Data API Migration — Design

**Date:** 2026-07-21
**Status:** Approved (pending spec review)
**Depends on:** the v3 auth module (`feat/v3-mobile-auth`) — `AuthTokenStore`,
`authStatusProvider`, `onUnauthorized()`, `AppRoutes.authLanding`.

## Goal

Migrate the leaderboard/data API calls from v2 (`/api/v3/mobile` was auth-only;
data was `/api/v2/mobile`, addressed by `participant_id`) to the token-scoped v3
data endpoints (`/api/v3/mobile/*`). The participant is resolved from the session
token, so `participant_id` is dropped everywhere. Guests (no token) get an
explicit "sign in to view" gate.

Package `crypto_mobile_app`. Confirmed: same participant identity between the v3
session token and the existing leaderboard participant — migration is mechanical.

## Endpoint mapping (v2 → v3)

Base changes from `AppConfig.leaderboardApiBaseUrl` (`…/api/v2/mobile`) to
`AppConfig.mobileApiV3BaseUrl` (`…/api/v3/mobile`). All data endpoints require
`Authorization: Bearer <session_token>`. Envelope `{success, data}` unchanged.

| Service method | v3 path | Change |
|---|---|---|
| `getRanking` | GET `/me/ranking` | drop `participant_id` |
| `getBreakdown` | GET `/me/breakdown` | drop `participant_id` (keep `include_activity`) |
| `getEventPoints` | GET `/event/points` | drop `participant_id` (keep `event_id`) |
| `getChallenges` | GET `/challenges` | drop `participant_id` |
| `getLeaderboard` | GET `/leaderboard` | no param change (already no `participant_id`) |
| `getSeasons` | GET `/seasons` | no param change |
| `getCurrentTerms` | GET `/terms/current` | drop `participant_id` |
| `postTermsConsent` | POST `/terms/consent` | drop `participant_id` |
| `completeZkPassport` | POST `/zkpassport/complete` | drop `participant_id`; body = `challenge_id`, `session_id`, `nullifier_hex`, `wallet_address`, optional `completed_at` |
| device logs (`LogShareService.postLogs`) | POST `/logs` | drop `/{participant}` path segment; add Bearer |
| `register` | — (no v3 equivalent) | **untouched**, stays on v2 `leaderboardApiBaseUrl`; not on the app's live path (registration goes through `RegistrationRepository`) |

## Config (`lib/core/config/app_config.dart`)

- Add `mobileApiV3BaseUrl` = `String.fromEnvironment('MOBILE_API_V3_BASE_URL',
  default 'https://leaderboard.usernodelabs.org/api/v3/mobile')`.
- Refactor `authApiBaseUrl` (from the auth branch) to `"$mobileApiV3BaseUrl/auth"`.
- Keep `leaderboardApiBaseUrl` (v2) for `register` only.

## Token plumbing

- `sessionTokenProvider` → `FutureProvider<String?>` reading
  `authTokenStoreProvider.read()`.
- `isAuthenticatedProvider` → `Provider<bool>` = `authStatus == authenticated`.
- `LeaderboardApiService` ctor gains:
  - `Future<String?> Function()? tokenProvider`
  - `Future<void> Function()? onUnauthorized`
  - `_get`/`_post` attach `Authorization: Bearer <token>` when the token is
    non-null. On an HTTP **401**, call `onUnauthorized()` (clears token, flips
    `authStatus` → unauthenticated → router redirects to `authLanding`), then
    throw as today.
- Wiring in `leaderboardApiServiceProvider`:
  ```dart
  LeaderboardApiService(
    tokenProvider: () => ref.read(authTokenStoreProvider).read(),
    onUnauthorized: () => ref.read(authStatusProvider.notifier).onUnauthorized(),
  );
  ```
  Same callbacks wired into `LogShareService`.

## Providers / call sites

- Remove every `participantId:` argument from calls to the migrated methods
  (`ranking_provider`, `points_breakdown_provider`, `event_points_provider`,
  `challenges_provider`, `profile_completed_challenges_provider`,
  `leaderboard_bootstrap`, `terms_provider`, `zkpassport_flow_provider`).
- Change `watchDeps()` gates from `participantIdProvider.valueOrNull != null` to
  `ref.watch(isAuthenticatedProvider)` (combined with existing season/event
  context checks where present). A guest → deps unsatisfied → `AsyncData(null)`.
- `participantIdProvider` stays for local/node uses (re-registration prompt in
  `main.dart`, node identity, zkpassport local state) — **not** removed.

## Guest gated UI

- New DS-styled `SignInToViewCard` (label + CTA button) that routes to
  `AppRoutes.authLanding`.
- Shown when `authStatus` is `guest` or `unauthenticated` on the data screens:
  profile (ranking/breakdown), leaderboard, challenges, terms. `unknown` (boot)
  is treated as loading (no card), so the card never flashes at startup.
- Authenticated-but-empty keeps the existing empty state; only the guest/
  unauthenticated case swaps in the card. Exact screen list finalized during
  planning.

## 401 handling

Confirmed: clear the token and bounce to the auth landing. Implemented via the
`onUnauthorized()` callback above — no per-screen 401 handling needed.

## Testing

- `test/core/services/leaderboard_api_service_test.dart` — update all method
  calls (no `participant_id`), assert `Authorization: Bearer` is sent when a
  token is provided and absent when not, assert a 401 triggers `onUnauthorized`.
- Provider tests using `_RecordingLeaderboardApiService` / `_FakeService extends
  LeaderboardApiService` — update overridden signatures; add `isAuthenticated`
  overrides where gating changed.
- `terms_provider_test`, `terms_screen_test`, `profile_screen_test` — drop
  `participant_id`, add authenticated gating.
- New `test/core/services/log_share_service_test.dart` — v3 `/logs`, Bearer,
  `{continue}` handling, no-token skip.

## Delivery

One branch `feat/v3-data-api-migration` off `feat/v3-mobile-auth`, a commit per
phase, one PR at the end.

**Phases (each ends green — analyze + full test):**
1. Config + token plumbing + `LeaderboardApiService` v3 (data + zkpassport, 401)
   + its unit tests.
2. Provider re-gating + call-site `participant_id` removal + provider tests.
3. Guest `SignInToViewCard` + screen wiring.
4. `LogShareService` → v3 `/logs` + tests.

## Out of scope

- `register` (no v3 equivalent) and `RegistrationRepository` — unchanged.
- `ExplorerService`, `ObservabilityReportingService` — different hosts, unrelated.
- Removing `participantIdProvider` or node-registration identity.
