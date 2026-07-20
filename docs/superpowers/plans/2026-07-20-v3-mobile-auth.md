# v3 Mobile Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add email + OTP + password authentication against `{host}/api/v3/mobile/auth`, with a 3-option landing (Log in / Sign in / Continue as guest) that gates the app on a v3 session token before the existing onboarding/permission flow.

**Architecture:** New `lib/features/auth/` module (data repo + plain models + secure token store + guest flag + Riverpod status/flow providers + 5 screens), mirroring `lib/features/onboarding/`. A synchronous `authStatusProvider` (StateNotifier) is added as the first clause of the go_router redirect guard; existing account/onboarding logic runs unchanged afterward.

**Tech Stack:** Riverpod, go_router, `http` + `createAppHttpClient()`, `flutter_secure_storage`, `shared_preferences`, `flutter_test` + `http` `MockClient`. Package: `crypto_mobile_app`.

## Global Constraints

- Package import prefix: `package:crypto_mobile_app/...`.
- HTTP client: always `createAppHttpClient()` (never raw `http.Client()`); repo ctor takes `http.Client? httpClient` for test injection.
- Base URL: derive host from `AppConfig.registrationEndpoint`; NO new dart-define.
- Two tokens: `set_password_token` is in-memory only (never persisted); `session_token` in secure storage key `auth:v3:session_token`.
- Writes (POST) are never retried.
- Models are plain hand-written classes with `fromJson` (match `RegistrationResult`), not freezed.
- User-facing strings via `AppLocalizations.of(context)` (ARB in `lib/core/config/l10n/app_en.arb`, run `flutter gen-l10n`).
- Screens: `ConsumerStatefulWidget`, Material `TextField` + `InputDecoration(errorText:)` + `setState`, DS `Button` from `package:crypto_mobile_app/design_system/design_system.dart`.
- After Dart changes: `dart format .` and `flutter analyze` must pass.

---

### Task 1: Auth base URL config

**Files:**
- Modify: `lib/core/config/app_config.dart` (add near `registrationEndpoint`, ~line 52)
- Test: `test/core/config/auth_base_url_test.dart`

**Interfaces:**
- Produces: `AppConfig.authApiBaseUrl` → `String` (e.g. `https://leaderboard.usernodelabs.org/api/v3/mobile/auth`)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

void main() {
  test('authApiBaseUrl derives v3 auth path from registration host', () {
    final uri = Uri.parse(AppConfig.authApiBaseUrl);
    expect(uri.path, '/api/v3/mobile/auth');
    expect(uri.host, Uri.parse(AppConfig.registrationEndpoint).host);
    expect(uri.scheme, 'https');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/config/auth_base_url_test.dart`
Expected: FAIL — `authApiBaseUrl` not defined.

- [ ] **Step 3: Implement**

Add to `AppConfig`, immediately after the `registrationEndpoint` declaration:

```dart
  // v3 mobile auth API. Same host as registration; no separate dart-define.
  static String get authApiBaseUrl {
    final reg = Uri.parse(registrationEndpoint);
    return Uri(
      scheme: reg.scheme,
      host: reg.host,
      port: reg.hasPort ? reg.port : null,
      path: '/api/v3/mobile/auth',
    ).toString();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/config/auth_base_url_test.dart` → PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_config.dart test/core/config/auth_base_url_test.dart
git commit -m "feat(auth): derive v3 auth base URL from registration host"
```

---

### Task 2: Models + AuthRepository

**Files:**
- Create: `lib/features/auth/data/models/auth_models.dart`
- Create: `lib/features/auth/data/repositories/auth_repository.dart`
- Test: `test/features/auth/data/auth_repository_test.dart`

**Interfaces:**
- Consumes: `AppConfig.authApiBaseUrl`, `createAppHttpClient()`.
- Produces:
  - `Participant {int id; String email; String? displayName; bool emailConfirmed}` + `Participant.fromJson`
  - `AuthSession {String token; Participant participant}` + `AuthSession.fromJson`
  - `CheckEmailResult {bool exists; bool passwordSet}` + `.fromJson`
  - `OtpTicket {String setPasswordToken}` + `.fromJson`
  - `enum AuthErrorKind { invalidCredentials, invalidCode, rateLimited, wrongToken, validation, network }`
  - `class AuthException implements Exception { AuthErrorKind kind; String message; }`
  - `AuthRepository({http.Client? httpClient, String? baseUrl})` with:
    - `Future<CheckEmailResult> checkEmail(String email)`
    - `Future<AuthSession> login({required String email, required String password})`
    - `Future<void> requestOtp(String email)`
    - `Future<OtpTicket> verifyOtp({required String email, required String code})`
    - `Future<AuthSession> setPassword({required String setPasswordToken, required String password, required String passwordConfirmation})`
    - `Future<void> logout(String sessionToken)`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

const _base = 'https://test.example.com/api/v3/mobile/auth';

MockClient _client(int status, Object body, {void Function(http.Request)? onReq}) =>
    MockClient((req) async {
      onReq?.call(req);
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    });

AuthRepository _repo(http.Client c) => AuthRepository(httpClient: c, baseUrl: _base);

void main() {
  group('checkEmail', () {
    test('parses exists/password_set', () async {
      final r = await _repo(_client(200, {'exists': true, 'password_set': false}))
          .checkEmail('a@b.com');
      expect(r.exists, true);
      expect(r.passwordSet, false);
    });
    test('429 -> rateLimited', () async {
      expect(
        () => _repo(_client(429, {'message': 'slow down'})).checkEmail('a@b.com'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.rateLimited)),
      );
    });
  });

  group('login', () {
    test('200 -> AuthSession', () async {
      final r = await _repo(_client(200, {
        'token': 'sess-1',
        'participant': {
          'id': 7,
          'email': 'a@b.com',
          'display_name': 'Ann',
          'email_confirmed': true,
        },
      })).login(email: 'a@b.com', password: 'pw');
      expect(r.token, 'sess-1');
      expect(r.participant.id, 7);
      expect(r.participant.displayName, 'Ann');
      expect(r.participant.emailConfirmed, true);
    });
    test('401 -> invalidCredentials', () async {
      expect(
        () => _repo(_client(401, {'message': 'Invalid email or password.'}))
            .login(email: 'a@b.com', password: 'x'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.invalidCredentials)),
      );
    });
  });

  group('requestOtp', () {
    test('200 completes', () async {
      await _repo(_client(200, {'message': 'sent'})).requestOtp('a@b.com');
    });
  });

  group('verifyOtp', () {
    test('200 -> set_password_token', () async {
      final r = await _repo(_client(200, {'set_password_token': 'spt-1'}))
          .verifyOtp(email: 'a@b.com', code: '123456');
      expect(r.setPasswordToken, 'spt-1');
    });
    test('422 -> invalidCode', () async {
      expect(
        () => _repo(_client(422, {'message': 'Invalid or expired code.'}))
            .verifyOtp(email: 'a@b.com', code: '000000'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.invalidCode)),
      );
    });
  });

  group('setPassword', () {
    test('sends bearer set_password_token and returns session', () async {
      String? auth;
      final r = await _repo(_client(200, {
        'token': 'sess-2',
        'participant': {'id': 1, 'email': 'a@b.com', 'email_confirmed': false},
      }, onReq: (req) => auth = req.headers['authorization']))
          .setPassword(
              setPasswordToken: 'spt-1',
              password: 'password1',
              passwordConfirmation: 'password1');
      expect(auth, 'Bearer spt-1');
      expect(r.token, 'sess-2');
    });
    test('422 -> validation', () async {
      expect(
        () => _repo(_client(422, {'message': 'too short'})).setPassword(
            setPasswordToken: 't', password: 'x', passwordConfirmation: 'x'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.validation)),
      );
    });
    test('403 -> wrongToken', () async {
      expect(
        () => _repo(_client(403, {'message': 'nope'})).setPassword(
            setPasswordToken: 't', password: 'password1', passwordConfirmation: 'password1'),
        throwsA(isA<AuthException>()
            .having((e) => e.kind, 'kind', AuthErrorKind.wrongToken)),
      );
    });
  });

  group('logout', () {
    test('sends bearer session token', () async {
      String? auth;
      await _repo(_client(200, {'message': 'Logged out.'},
              onReq: (req) => auth = req.headers['authorization']))
          .logout('sess-9');
      expect(auth, 'Bearer sess-9');
    });
    test('401 does not throw (already logged out)', () async {
      await _repo(_client(401, {'message': 'x'})).logout('sess-9');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`
Expected: FAIL — models/repository not defined.

- [ ] **Step 3: Implement models**

Create `lib/features/auth/data/models/auth_models.dart`:

```dart
class Participant {
  const Participant({
    required this.id,
    required this.email,
    required this.emailConfirmed,
    this.displayName,
  });

  final int id;
  final String email;
  final bool emailConfirmed;
  final String? displayName;

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        emailConfirmed: json['email_confirmed'] == true,
        displayName: json['display_name'] as String?,
      );
}

class AuthSession {
  const AuthSession({required this.token, required this.participant});

  final String token;
  final Participant participant;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        token: json['token'] as String,
        participant:
            Participant.fromJson(json['participant'] as Map<String, dynamic>),
      );
}

class CheckEmailResult {
  const CheckEmailResult({required this.exists, required this.passwordSet});

  final bool exists;
  final bool passwordSet;

  factory CheckEmailResult.fromJson(Map<String, dynamic> json) =>
      CheckEmailResult(
        exists: json['exists'] == true,
        passwordSet: json['password_set'] == true,
      );
}

class OtpTicket {
  const OtpTicket({required this.setPasswordToken});

  final String setPasswordToken;

  factory OtpTicket.fromJson(Map<String, dynamic> json) =>
      OtpTicket(setPasswordToken: json['set_password_token'] as String);
}
```

- [ ] **Step 4: Implement repository**

Create `lib/features/auth/data/repositories/auth_repository.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/core/network/logging_http_client.dart';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';

final _log = LoggingService.instance.withTag('usernode/AuthRepository');

enum AuthErrorKind {
  invalidCredentials,
  invalidCode,
  rateLimited,
  wrongToken,
  validation,
  network,
}

class AuthException implements Exception {
  AuthException(this.kind, this.message);
  final AuthErrorKind kind;
  final String message;
  @override
  String toString() => 'AuthException($kind, $message)';
}

class AuthRepository {
  AuthRepository({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? createAppHttpClient(),
        _baseUrl = baseUrl ?? AppConfig.authApiBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<CheckEmailResult> checkEmail(String email) async {
    final json = await _post('/check-email', body: {'email': email});
    return CheckEmailResult.fromJson(json);
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final json =
        await _post('/login', body: {'email': email, 'password': password});
    return AuthSession.fromJson(json);
  }

  Future<void> requestOtp(String email) async {
    await _post('/otp/request', body: {'email': email});
  }

  Future<OtpTicket> verifyOtp(
      {required String email, required String code}) async {
    final json =
        await _post('/otp/verify', body: {'email': email, 'code': code});
    return OtpTicket.fromJson(json);
  }

  Future<AuthSession> setPassword({
    required String setPasswordToken,
    required String password,
    required String passwordConfirmation,
  }) async {
    final json = await _post(
      '/set-password',
      body: {
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      bearer: setPasswordToken,
    );
    return AuthSession.fromJson(json);
  }

  Future<void> logout(String sessionToken) async {
    try {
      await _post('/logout', body: const {}, bearer: sessionToken);
    } catch (e) {
      // Best-effort: an expired/invalid session still clears locally.
      _log.debug('logout ignored error: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    required Map<String, dynamic> body,
    String? bearer,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    http.Response resp;
    try {
      resp = await _http
          .post(
            url,
            headers: {
              ..._jsonHeaders,
              if (bearer != null) 'Authorization': 'Bearer $bearer',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      _log.warn('auth request failed: $e');
      throw AuthException(AuthErrorKind.network, 'Network error. Please try again.');
    }

    final decoded = _tryDecode(resp.body);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return decoded ?? const {};
    }
    throw _mapError(resp.statusCode, decoded);
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }

  AuthException _mapError(int status, Map<String, dynamic>? json) {
    final serverMsg = json?['message'] as String?;
    switch (status) {
      case 401:
        return AuthException(AuthErrorKind.invalidCredentials,
            serverMsg ?? 'Invalid email or password.');
      case 403:
        return AuthException(AuthErrorKind.wrongToken,
            serverMsg ?? 'This link is no longer valid.');
      case 422:
        // /otp/verify uses 422 for a bad code; /set-password for validation.
        final kind = (serverMsg != null &&
                serverMsg.toLowerCase().contains('code'))
            ? AuthErrorKind.invalidCode
            : AuthErrorKind.validation;
        return AuthException(kind, serverMsg ?? 'Please check your input.');
      case 429:
        return AuthException(
            AuthErrorKind.rateLimited, 'Please try again shortly.');
      default:
        return AuthException(
            AuthErrorKind.network, serverMsg ?? 'Something went wrong.');
    }
  }
}
```

Note: the `422 → invalidCode vs validation` split keys off the server message. `/otp/verify` returns "Invalid or expired code." (contains "code" → invalidCode); `/set-password` validation messages do not → validation. This matches the test expectations.

- [ ] **Step 5: Run tests → PASS**

Run: `flutter test test/features/auth/data/auth_repository_test.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/auth/data test/features/auth/data/auth_repository_test.dart
git commit -m "feat(auth): v3 auth models and repository with typed errors"
```

---

### Task 3: Session token store + guest flag

**Files:**
- Create: `lib/features/auth/data/auth_token_store.dart`
- Test: `test/features/auth/data/auth_token_store_test.dart`

**Interfaces:**
- Produces:
  - `AuthTokenStore({FlutterSecureStorage? storage})` with `Future<String?> read()`, `Future<void> write(String token)`, `Future<void> clear()` (key `auth:v3:session_token`).
  - `AuthGuestFlag({SharedPreferences? prefs})` with `Future<bool> isGuest()`, `Future<void> setGuest()`, `Future<void> clear()` (key `auth:v3:guest`). Reads `SharedPreferences.getInstance()` lazily when `prefs` not injected.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('token store write/read/clear', () async {
    final store = AuthTokenStore();
    expect(await store.read(), isNull);
    await store.write('sess-1');
    expect(await store.read(), 'sess-1');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('guest flag set/read/clear', () async {
    final flag = AuthGuestFlag();
    expect(await flag.isGuest(), false);
    await flag.setGuest();
    expect(await flag.isGuest(), true);
    await flag.clear();
    expect(await flag.isGuest(), false);
  });
}
```

- [ ] **Step 2: Run test → FAIL** (`AuthTokenStore` undefined)

Run: `flutter test test/features/auth/data/auth_token_store_test.dart`

- [ ] **Step 3: Implement**

Create `lib/features/auth/data/auth_token_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'auth:v3:session_token';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

class AuthGuestFlag {
  AuthGuestFlag({SharedPreferences? prefs}) : _injected = prefs;

  static const _key = 'auth:v3:guest';
  final SharedPreferences? _injected;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? await SharedPreferences.getInstance();

  Future<bool> isGuest() async => (await _prefs).getBool(_key) ?? false;
  Future<void> setGuest() async => (await _prefs).setBool(_key, true);
  Future<void> clear() async => (await _prefs).remove(_key);
}
```

- [ ] **Step 4: Run test → PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/auth_token_store.dart test/features/auth/data/auth_token_store_test.dart
git commit -m "feat(auth): secure session token store and guest flag"
```

---

### Task 4: Auth status + flow providers

**Files:**
- Create: `lib/features/auth/providers/auth_providers.dart`
- Test: `test/features/auth/providers/auth_status_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthTokenStore`, `AuthGuestFlag`, `AuthSession`.
- Produces:
  - `enum AuthStatus { unknown, unauthenticated, guest, authenticated }`
  - `authRepositoryProvider` → `Provider<AuthRepository>`
  - `authTokenStoreProvider` → `Provider<AuthTokenStore>`
  - `authGuestFlagProvider` → `Provider<AuthGuestFlag>`
  - `authStatusProvider` → `StateNotifierProvider<AuthStatusNotifier, AuthStatus>`
  - `AuthStatusNotifier` methods: `Future<void> completeLogin(AuthSession)`, `Future<void> continueAsGuest()`, `Future<void> logout()`, `Future<void> onUnauthorized()`.
  - `authFlowProvider` → `StateNotifierProvider<AuthFlowNotifier, AuthFlowState>` with `AuthFlowState {String? email; String? setPasswordToken}` and setters `setEmail`, `setPasswordToken`, `reset`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

AuthSession _session(String token) => AuthSession(
      token: token,
      participant: const Participant(id: 1, email: 'a@b.com', emailConfirmed: true),
    );

Future<AuthStatus> _settle(ProviderContainer c) async {
  // Wait for the notifier's async boot to resolve off `unknown`.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return c.read(authStatusProvider);
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('boots to unauthenticated when nothing stored', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.unauthenticated);
  });

  test('boots to authenticated when token stored', () async {
    FlutterSecureStorage.setMockInitialValues({'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.authenticated);
  });

  test('boots to guest when guest flag set', () async {
    SharedPreferences.setMockInitialValues({'auth:v3:guest': true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await _settle(c), AuthStatus.guest);
  });

  test('completeLogin persists token and authenticates', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).completeLogin(_session('sess-2'));
    expect(c.read(authStatusProvider), AuthStatus.authenticated);
    expect(await c.read(authTokenStoreProvider).read(), 'sess-2');
  });

  test('continueAsGuest sets guest', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).continueAsGuest();
    expect(c.read(authStatusProvider), AuthStatus.guest);
  });

  test('onUnauthorized clears token and unauthenticates', () async {
    FlutterSecureStorage.setMockInitialValues({'auth:v3:session_token': 'sess-1'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await _settle(c);
    await c.read(authStatusProvider.notifier).onUnauthorized();
    expect(c.read(authStatusProvider), AuthStatus.unauthenticated);
    expect(await c.read(authTokenStoreProvider).read(), isNull);
  });
}
```

- [ ] **Step 2: Run test → FAIL**

Run: `flutter test test/features/auth/providers/auth_status_test.dart`

- [ ] **Step 3: Implement**

Create `lib/features/auth/providers/auth_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider =
    Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

final authStatusProvider =
    StateNotifierProvider<AuthStatusNotifier, AuthStatus>((ref) {
  return AuthStatusNotifier(
    tokenStore: ref.watch(authTokenStoreProvider),
    guestFlag: ref.watch(authGuestFlagProvider),
    repository: ref.watch(authRepositoryProvider),
  )..load();
});

class AuthStatusNotifier extends StateNotifier<AuthStatus> {
  AuthStatusNotifier({
    required AuthTokenStore tokenStore,
    required AuthGuestFlag guestFlag,
    required AuthRepository repository,
  })  : _tokenStore = tokenStore,
        _guestFlag = guestFlag,
        _repository = repository,
        super(AuthStatus.unknown);

  final AuthTokenStore _tokenStore;
  final AuthGuestFlag _guestFlag;
  final AuthRepository _repository;

  Future<void> load() async {
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      state = AuthStatus.authenticated;
      return;
    }
    state =
        await _guestFlag.isGuest() ? AuthStatus.guest : AuthStatus.unauthenticated;
  }

  Future<void> completeLogin(AuthSession session) async {
    await _tokenStore.write(session.token);
    await _guestFlag.clear();
    state = AuthStatus.authenticated;
  }

  Future<void> continueAsGuest() async {
    await _guestFlag.setGuest();
    state = AuthStatus.guest;
  }

  Future<void> logout() async {
    final token = await _tokenStore.read();
    if (token != null && token.isNotEmpty) {
      await _repository.logout(token);
    }
    await _tokenStore.clear();
    await _guestFlag.clear();
    state = AuthStatus.unauthenticated;
  }

  Future<void> onUnauthorized() async {
    await _tokenStore.clear();
    state = AuthStatus.unauthenticated;
  }
}

class AuthFlowState {
  const AuthFlowState({this.email, this.setPasswordToken});
  final String? email;
  final String? setPasswordToken;

  AuthFlowState copyWith({String? email, String? setPasswordToken}) =>
      AuthFlowState(
        email: email ?? this.email,
        setPasswordToken: setPasswordToken ?? this.setPasswordToken,
      );
}

final authFlowProvider =
    StateNotifierProvider<AuthFlowNotifier, AuthFlowState>(
        (ref) => AuthFlowNotifier());

class AuthFlowNotifier extends StateNotifier<AuthFlowState> {
  AuthFlowNotifier() : super(const AuthFlowState());

  void setEmail(String email) => state = state.copyWith(email: email);
  void setPasswordToken(String token) =>
      state = state.copyWith(setPasswordToken: token);
  void reset() => state = const AuthFlowState();
}
```

- [ ] **Step 4: Run test → PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/providers test/features/auth/providers/auth_status_test.dart
git commit -m "feat(auth): auth status and flow providers"
```

---

### Task 5: Router wiring + redirect gate

**Files:**
- Modify: `lib/core/config/app_router.dart` — add routes to `AppRoutes` (~line 56), add `GoRoute`s to the `routes:` list (~line 178), add auth listener to `GoRouterRefreshStream` (~line 120), add auth clause at the top of the `redirect:` guard (~line 496).
- Test: `test/features/auth/auth_redirect_test.dart`

**Interfaces:**
- Consumes: `authStatusProvider`, `AuthStatus`.
- Produces: `AppRoutes.authLanding/authEmail/authPassword/authOtp/authSetPassword` string constants and an exported pure helper `String? authRedirect(AuthStatus status, String location)` for unit testing the gate logic.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';
import 'package:crypto_mobile_app/core/config/app_router.dart';

void main() {
  test('unknown -> allow (loading)', () {
    expect(authRedirect(AuthStatus.unknown, AppRoutes.home), isNull);
  });
  test('unauthenticated on private route -> landing', () {
    expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.home),
        AppRoutes.authLanding);
  });
  test('unauthenticated on an auth route -> allow', () {
    expect(authRedirect(AuthStatus.unauthenticated, AppRoutes.authEmail), isNull);
  });
  test('authenticated on an auth route -> leave to splash', () {
    expect(authRedirect(AuthStatus.authenticated, AppRoutes.authLanding),
        AppRoutes.splash);
  });
  test('authenticated on private route -> defer to existing logic (null)', () {
    expect(authRedirect(AuthStatus.authenticated, AppRoutes.home), isNull);
  });
  test('guest behaves like authenticated for the gate', () {
    expect(authRedirect(AuthStatus.guest, AppRoutes.authLanding), AppRoutes.splash);
    expect(authRedirect(AuthStatus.guest, AppRoutes.home), isNull);
  });
}
```

- [ ] **Step 2: Run test → FAIL** (`authRedirect` / auth routes undefined)

Run: `flutter test test/features/auth/auth_redirect_test.dart`

- [ ] **Step 3: Add route constants** to `AppRoutes` (after `staleRegistration`, ~line 71):

```dart
  // v3 auth flow
  static const authLanding = '/auth';
  static const authEmail = '/auth/email';
  static const authPassword = '/auth/password';
  static const authOtp = '/auth/otp';
  static const authSetPassword = '/auth/set-password';
```

- [ ] **Step 4: Add the pure gate helper** at top-level in `app_router.dart` (below `AppRoutes`):

```dart
const _authRoutes = <String>[
  AppRoutes.authLanding,
  AppRoutes.authEmail,
  AppRoutes.authPassword,
  AppRoutes.authOtp,
  AppRoutes.authSetPassword,
];

/// First-stage auth gate. Returns a redirect target, or null to defer to the
/// existing account/onboarding logic. Pure for unit testing.
String? authRedirect(AuthStatus status, String location) {
  final isAuthRoute = _authRoutes.contains(location);
  switch (status) {
    case AuthStatus.unknown:
      return null; // still loading; don't bounce
    case AuthStatus.unauthenticated:
      return isAuthRoute ? null : AppRoutes.authLanding;
    case AuthStatus.guest:
    case AuthStatus.authenticated:
      return isAuthRoute ? AppRoutes.splash : null;
  }
}
```

Add imports at top: `import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';` and the screen imports (Step 6).

- [ ] **Step 5: Run redirect test → PASS**

Run: `flutter test test/features/auth/auth_redirect_test.dart`

- [ ] **Step 6: Register routes.** In the `routes:` list add:

```dart
      GoRoute(
        path: AppRoutes.authLanding,
        builder: (context, state) => const AuthLandingScreen(),
      ),
      GoRoute(
        path: AppRoutes.authEmail,
        builder: (context, state) => const AuthEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.authPassword,
        builder: (context, state) => const AuthPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authOtp,
        builder: (context, state) => const AuthOtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.authSetPassword,
        builder: (context, state) => const AuthSetPasswordScreen(),
      ),
```

with imports for the five screens from `package:crypto_mobile_app/features/auth/screens/...` (created in Task 6).

- [ ] **Step 7: Wire the refresh stream.** In `GoRouterRefreshStream` constructor add:

```dart
    _ref.listen(authStatusProvider, (previous, next) {
      notifyListeners();
    });
```

- [ ] **Step 8: Insert the gate** as the FIRST logic inside `redirect:` (right after `final currentLocation = state.matchedLocation;`, before the deep-link block):

```dart
      final authGate =
          authRedirect(ref.read(authStatusProvider), currentLocation);
      if (authGate != null) return authGate;
      if (ref.read(authStatusProvider) == AuthStatus.unauthenticated) {
        // On an auth route while unauthenticated: allow it, skip account logic.
        return null;
      }
```

- [ ] **Step 9: Run analyzer + redirect test**

Run: `flutter analyze lib/core/config/app_router.dart && flutter test test/features/auth/auth_redirect_test.dart`
Expected: analyzer clean (screens exist after Task 6 — if doing Task 5 before 6, temporarily comment the screen routes/imports and re-enable in Task 6), test PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/core/config/app_router.dart test/features/auth/auth_redirect_test.dart
git commit -m "feat(auth): gate router redirect on auth status"
```

---

### Task 6: Screens + localized strings

**Files:**
- Create: `lib/features/auth/screens/auth_landing_screen.dart`, `auth_email_screen.dart`, `auth_password_screen.dart`, `auth_otp_screen.dart`, `auth_set_password_screen.dart`
- Modify: `lib/core/config/l10n/app_en.arb` (add auth strings), then run `flutter gen-l10n`
- Modify: `lib/core/config/app_router.dart` (uncomment screen imports/routes if deferred from Task 5)

**Interfaces:**
- Consumes: `authRepositoryProvider`, `authStatusProvider`, `authFlowProvider`, `AuthException`/`AuthErrorKind`, `CheckEmailResult`, `AuthRoutes`, `Button`.

Screens follow the established pattern in `lib/features/onboarding/screens/import_api_account_screen.dart`: `ConsumerStatefulWidget`, `TextEditingController`s, local `String? _error`, `bool _submitting`, a `_submit()` that calls the repo then `context.go(...)`, Material `TextField` with `InputDecoration(errorText:)`, DS `Button(isLoading: _submitting, ...)`, and `context.go` navigation via `go_router`.

- [ ] **Step 1: Add ARB strings** to `lib/core/config/l10n/app_en.arb` (before the closing brace; keep valid JSON):

```json
  "authLandingTitle": "Welcome",
  "authLogIn": "Log in",
  "authSignIn": "Sign in",
  "authContinueGuest": "Continue as guest",
  "authEmailLabel": "Email",
  "authEmailContinue": "Continue",
  "authPasswordLabel": "Password",
  "authPasswordContinue": "Log in",
  "authOtpLabel": "6-digit code",
  "authOtpVerify": "Verify",
  "authOtpResend": "Resend code",
  "authSetPasswordLabel": "New password",
  "authConfirmPasswordLabel": "Confirm password",
  "authSetPasswordSubmit": "Set password",
  "authErrorRateLimited": "Please try again shortly.",
  "authErrorInvalidCredentials": "Invalid email or password.",
  "authErrorInvalidCode": "Invalid or expired code.",
  "authErrorNetwork": "Network error. Please try again.",
  "authErrorPasswordTooShort": "Password must be at least 8 characters.",
  "authErrorPasswordMismatch": "Passwords do not match."
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Landing screen** — `auth_landing_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class AuthLandingScreen extends ConsumerWidget {
  const AuthLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l.authLandingTitle,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              Button(
                label: l.authLogIn,
                variant: ButtonVariant.primary,
                onTap: () => context.go(AppRoutes.authEmail),
              ),
              const SizedBox(height: 12),
              Button(
                label: l.authSignIn,
                onTap: () => context.go(AppRoutes.authEmail),
              ),
              const SizedBox(height: 12),
              Button(
                label: l.authContinueGuest,
                variant: ButtonVariant.outlined,
                onTap: () async {
                  await ref.read(authStatusProvider.notifier).continueAsGuest();
                  if (context.mounted) context.go(AppRoutes.splash);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Email screen** — `auth_email_screen.dart`. On submit call `checkEmail`; store email in `authFlowProvider`; if `exists && passwordSet` → `context.go(AppRoutes.authPassword)`, else `requestOtp` then `context.go(AppRoutes.authOtp)`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';
import 'package:crypto_mobile_app/features/auth/providers/auth_providers.dart';

class AuthEmailScreen extends ConsumerStatefulWidget {
  const AuthEmailScreen({super.key});
  @override
  ConsumerState<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends ConsumerState<AuthEmailScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _controller.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final repo = ref.read(authRepositoryProvider);
    try {
      ref.read(authFlowProvider.notifier).setEmail(email);
      final res = await repo.checkEmail(email);
      if (res.exists && res.passwordSet) {
        if (mounted) context.go(AppRoutes.authPassword);
      } else {
        await repo.requestOtp(email);
        if (mounted) context.go(AppRoutes.authOtp);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                    labelText: l.authEmailLabel, errorText: _error),
              ),
              const SizedBox(height: 24),
              Button(
                label: l.authEmailContinue,
                variant: ButtonVariant.primary,
                isLoading: _submitting,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Password screen** — `auth_password_screen.dart`. Reads `authFlowProvider.email`, calls `login`, on success `ref.read(authStatusProvider.notifier).completeLogin(session)` then `context.go(AppRoutes.splash)`. Same scaffold/pattern as email screen, obscureText field, error from `AuthException`.

- [ ] **Step 5: OTP screen** — `auth_otp_screen.dart`. 6-digit `TextField` (`keyboardType: TextInputType.number`, `maxLength: 6`), calls `verifyOtp(email, code)`; on success `ref.read(authFlowProvider.notifier).setPasswordToken(ticket.setPasswordToken)` then `context.go(AppRoutes.authSetPassword)`. A "Resend code" `TextButton` calls `requestOtp(email)` again. Map `AuthErrorKind.invalidCode` to `l.authErrorInvalidCode`.

- [ ] **Step 6: Set-password screen** — `auth_set_password_screen.dart`. Two obscured fields (password + confirm). Client validation: min 8 chars → `l.authErrorPasswordTooShort`; must match → `l.authErrorPasswordMismatch`. Reads `authFlowProvider.setPasswordToken`; calls `setPassword(...)`; on success `completeLogin(session)`, `authFlowProvider.reset()`, `context.go(AppRoutes.splash)`. On `AuthErrorKind.wrongToken` (403) show error and offer `context.go(AppRoutes.authOtp)` to restart.

- [ ] **Step 7: Enable screen routes** in `app_router.dart` (imports + `GoRoute`s from Task 5 Step 6 if they were deferred).

- [ ] **Step 8: Analyze + format + full test**

Run: `dart format . && flutter analyze && flutter test`
Expected: no analyzer issues; all tests pass.

- [ ] **Step 9: Commit**

```bash
git add lib/features/auth/screens lib/core/config/l10n lib/core/config/app_router.dart
git commit -m "feat(auth): landing, email, password, otp and set-password screens"
```

---

## Self-review notes

- **Spec coverage:** check-email/login/otp/verify/set-password/logout → Task 2; two-token separation → Tasks 2+4 (set_password_token only in `authFlowProvider`, never persisted); token storage → Task 3; 429/OTP-resend/403-restart UX → Task 6; landing + gate + upgrade-forces-landing → Task 5 (`unauthenticated` regardless of existing account) + Task 6; base URL from registration host → Task 1; Bearer scope (auth endpoints only + `onUnauthorized` hook) → Tasks 2+4.
- **Deferred-route note:** Task 5 registers screen routes that Task 6 creates. If executing strictly in order, keep the five screen `GoRoute`s/imports commented in Task 5 Step 6 and enable them in Task 6 Step 7 so `flutter analyze` stays green between tasks.
- **Type consistency:** `AuthStatus`, `AuthErrorKind`, `AuthException`, `AuthSession`, `CheckEmailResult`, `OtpTicket`, `authRedirect(AuthStatus, String)`, provider names, and the `auth:v3:*` storage keys are used identically across tasks.
