import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/features/auth/data/auth_token_store.dart';
import 'package:crypto_mobile_app/features/auth/data/models/auth_models.dart';
import 'package:crypto_mobile_app/features/auth/data/repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, guest, authenticated }

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authTokenStoreProvider =
    Provider<AuthTokenStore>((ref) => AuthTokenStore());

final authGuestFlagProvider = Provider<AuthGuestFlag>((ref) => AuthGuestFlag());

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
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      state = AuthStatus.authenticated;
      return;
    }
    final guest = await _guestFlag.isGuest();
    if (!mounted) return;
    state = guest ? AuthStatus.guest : AuthStatus.unauthenticated;
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
  const AuthFlowState({
    this.email,
    this.setPasswordToken,
    this.recovery = false,
  });
  final String? email;
  final String? setPasswordToken;

  /// When true, the email step skips the password branch and forces the OTP
  /// path so the user can set a new password (forgot-password recovery).
  final bool recovery;

  AuthFlowState copyWith({
    String? email,
    String? setPasswordToken,
    bool? recovery,
  }) =>
      AuthFlowState(
        email: email ?? this.email,
        setPasswordToken: setPasswordToken ?? this.setPasswordToken,
        recovery: recovery ?? this.recovery,
      );
}

final authFlowProvider = StateNotifierProvider<AuthFlowNotifier, AuthFlowState>(
    (ref) => AuthFlowNotifier());

class AuthFlowNotifier extends StateNotifier<AuthFlowState> {
  AuthFlowNotifier() : super(const AuthFlowState());

  void setEmail(String email) => state = state.copyWith(email: email);
  void setPasswordToken(String token) =>
      state = state.copyWith(setPasswordToken: token);

  /// Start a fresh flow. [recovery] true forces the forgot-password OTP path.
  void start({bool recovery = false}) =>
      state = AuthFlowState(recovery: recovery);

  void reset() => state = const AuthFlowState();
}
