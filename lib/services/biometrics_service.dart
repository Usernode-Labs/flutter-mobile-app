import 'package:local_auth/local_auth.dart';

class BiometricsService {
  BiometricsService._();
  static final instance = BiometricsService._();
  final _localAuth = LocalAuthentication();

  Future<bool> canCheck() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock to view private data'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
