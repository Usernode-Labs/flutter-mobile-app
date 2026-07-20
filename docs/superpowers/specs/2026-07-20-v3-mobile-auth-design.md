# v3 Mobile Auth — Design

**Date:** 2026-07-20
**Status:** Approved (pending spec review)

## Goal

Add email + OTP + password authentication against the new v3 mobile API
(`{host}/api/v3/mobile/auth`). The Log in / Sign in / Continue as guest landing
becomes the app's first screen after splash and gates the app on a v3 **session
token**. The existing onboarding + permission-management flow runs unchanged once
the user is authenticated or continues as guest.

Package: `crypto_mobile_app`. Stack (confirmed): Riverpod, go_router, `http` +
`createAppHttpClient()`, `flutter_secure_storage`, freezed, `flutter_test` +
`http` `MockClient`.

## Screen flow

```
splash
  └─ auth_landing (Log in / Sign in / Continue as guest)
       ├─ Continue as guest ─────────────► existing onboarding/permission flow → home
       └─ Log in / Sign in → email_screen
            POST /check-email
              ├─ exists && password_set ─► password_screen → POST /login ─┐
              └─ otherwise ─► POST /otp/request → otp_screen               │
                     POST /otp/verify → set_password_screen                │
                        POST /set-password ─────────────────────► session ┘
                                                                     │
                    store session token → existing onboarding/permission flow → home
```

Log in and Sign in are the same flow, different entry labels.

## Endpoints & mapping

Base: `AppConfig.authApiBaseUrl` = `https://<registration-host>/api/v3/mobile/auth`
(host parsed from the existing `registrationEndpoint`; no new dart-define).
All JSON. `Authorization: Bearer <token>` on authenticated calls.

| Call | Method / path | Auth header | Success | Errors → `AuthException` kind |
|------|---------------|-------------|---------|-------------------------------|
| checkEmail | POST /check-email | — | `{exists, password_set}` | 429 → rateLimited |
| login | POST /login | — | `{token, participant}` | 401 → invalidCredentials; 429 → rateLimited |
| requestOtp | POST /otp/request | — | `{message}` (always 200) | 429 → rateLimited |
| verifyOtp | POST /otp/verify | — | `{set_password_token}` | 422 → invalidCode; 429 → rateLimited |
| setPassword | POST /set-password | Bearer **set_password_token** | `{token, participant}` | 422 → validation; 403 → wrongToken |
| logout | POST /logout | Bearer **session_token** | `{message}` | 401 → treat as already-logged-out (no throw; clear locally) |

`AuthException` kinds: `invalidCredentials`, `invalidCode`, `rateLimited`,
`wrongToken`, `validation`, `network`. Non-mapped/5xx/socket → `network`. Each
carries the kind + optional server `message`. `logout` is best-effort: a 401 (or
any failure) still clears the local token rather than surfacing an error.

## Two tokens (critical)

- **set_password_token** — from `/otp/verify`, short-lived (~10 min), single-use,
  ONLY for the `/set-password` call. Held in memory in `AuthFlowController`.
  **Never persisted.**
- **session_token** — from `/login` or `/set-password`. Persisted in secure
  storage. Valid ~90 days. Sent as Bearer on authenticated calls.

## Module layout — `lib/features/auth/`

Mirrors `lib/features/onboarding/`.

- `data/models/` (freezed): `Participant {id, email, displayName, emailConfirmed}`,
  `AuthSession {token, participant}`, `CheckEmailResult {exists, passwordSet}`,
  `OtpTicket {setPasswordToken}`.
- `data/repositories/auth_repository.dart` — ctor `{http.Client? httpClient,
  String? baseUrl}` (mirrors `registration_repository.dart`, uses
  `createAppHttpClient()`). One private `_post(path, {body, bearer})` helper that
  sets JSON headers + optional `Authorization`, parses JSON, maps status → typed
  `AuthException`. Writes are not retried.
- `data/auth_token_store.dart` — thin `FlutterSecureStorage` wrapper:
  `read()/write(token)/clear()`, key `auth:v3:session_token`. Mirrors
  `AccountsRepository` secure-storage use.
- `data/auth_guest_flag.dart` — `shared_preferences` bool `auth:v3:guest` so a
  guest choice survives restart.

## State — `providers/auth_providers.dart`

- `authRepositoryProvider`, `authTokenStoreProvider`.
- `authStatusProvider` (`StateNotifier<AuthStatus>`), states:
  `unknown` (boot, before storage read) → `unauthenticated` | `guest` |
  `authenticated`. On construction reads token + guest flag. Actions:
  `completeLogin(session)` (persist token, clear guest flag → authenticated),
  `continueAsGuest()` (set flag → guest), `logout()` (call repo, clear token →
  unauthenticated), `onUnauthorized()` (clear token, no network → unauthenticated).
- `authFlowController` (`StateNotifier<AuthFlowState>`) — transient `email` +
  `setPasswordToken` threaded across email → otp → set-password screens.

## Bearer + 401 handling (scope: auth endpoints only + reusable hook)

- The repository attaches Bearer itself for `setPassword` (set_password_token) and
  `logout` (session_token). No changes to `leaderboard_api_service` in this task.
- Reusable hook for later adopters: a small `authHeader(token)` helper +
  `authStatusProvider.onUnauthorized()`. On any 401 from an authenticated endpoint,
  callers invoke `onUnauthorized()` → status flips to `unauthenticated` → the
  router redirect bounces the user back to the auth landing/email screen.

## Routing — `lib/core/config/app_router.dart`

- New `AppRoutes`: `authLanding`, `authEmail`, `authPassword`, `authOtp`,
  `authSetPassword`; matching `GoRoute`s.
- Add all auth routes to `publicRoutes`.
- Add `authStatusProvider` to `GoRouterRefreshStream` so the guard re-runs on
  status change.
- Redirect guard gains a **first** clause (before the existing account/onboarding
  logic): while `authStatus == unknown` → allow (loading); if `unauthenticated`
  and the route is not an auth route → redirect to `authLanding`; if
  `authenticated` or `guest`, fall through to the **existing, unchanged**
  account/onboarding/permission redirect logic.

## Upgrade / migration

Users upgrading from a pre-auth version already have a node account (secret key),
a completed-onboarding flag, and a leaderboard registration, but **no v3 auth
state**. Decision: **force the auth landing on upgrade — no grandfathering.**

- On first launch of this version they have no session token and no guest flag →
  `authStatusProvider` boots to `unauthenticated` → redirect guard sends them to
  `authLanding`. They pick Log in / Sign in / Continue as guest once.
- Whatever they pick, they then proceed into the app; their existing node
  account, onboarding completion, and registration are untouched. Picking Continue
  as guest persists the guest flag so they are not re-prompted on later launches.
- Consequence: boot logic needs no special "is this an upgrade?" detection — the
  absence of both the session token and the guest flag is sufficient, whether the
  install is fresh or upgraded.

## UX rules

- 429 (rateLimited) → friendly "Please try again shortly."
- OTP: 6 digits, 10-min expiry, max 5 wrong attempts. On `invalidCode` show error;
  offer "Resend code" → `requestOtp` again (fresh code, resets attempts server-side).
- 403 on set-password (wrongToken / expired set_password_token) → discard it,
  send user back to request a new OTP.
- Password screen (set): min 8 chars, must match confirmation — validated client-side
  before calling, plus server 422 surfaced.
- Screens follow the existing manual form pattern (`TextEditingController` +
  `errorText` + `setState` + isLoading button), DS `Button`, localized ARB strings.

## Testing (TDD — `MockClient` + `ProviderContainer`)

- `test/features/auth/data/auth_repository_test.dart` — each endpoint: success
  parse + 401/422/429/403 → correct `AuthException` kind; verifies the
  set-password/logout Bearer header is sent.
- `test/features/auth/data/auth_token_store_test.dart` — write/read/clear (fake
  secure storage).
- `test/features/auth/providers/auth_status_test.dart` — boot with stored token →
  authenticated; boot with guest flag → guest; `completeLogin` persists +
  authenticated; `continueAsGuest`; `logout` clears; `onUnauthorized` clears.

## Out of scope

- Retrofitting `leaderboard_api_service` (or other existing services) to send Bearer.
- Refresh tokens / silent re-auth (token is long-lived ~90 days).
- Server-driven password policy beyond min-8 + match.
