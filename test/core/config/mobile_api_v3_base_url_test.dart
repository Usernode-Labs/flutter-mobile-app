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
