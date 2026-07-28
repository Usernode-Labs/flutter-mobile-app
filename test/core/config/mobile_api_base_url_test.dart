import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

void main() {
  test('mobileApiBaseUrl defaults to the SV v4 mobile API', () {
    final uri = Uri.parse(AppConfig.mobileApiBaseUrl);
    expect(uri.path, '/api/v4/mobile');
    expect(uri.host, 'social-vibecoding.usernodelabs.org');
  });
  test('authApiBaseUrl is the /auth sibling of the mobile API base', () {
    expect(AppConfig.authApiBaseUrl, '${AppConfig.mobileApiBaseUrl}/auth');
  });
  test('versionCheckApiUrl defaults to the SV v4 public endpoint', () {
    expect(Uri.parse(AppConfig.versionCheckApiUrl).path,
        '/api/v4/app-version/check');
  });
}
