import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

void main() {
  test('authApiBaseUrl derives the auth path from the mobile API base', () {
    final uri = Uri.parse(AppConfig.authApiBaseUrl);
    expect(uri.path, '/api/v4/mobile/auth');
    expect(uri.host, Uri.parse(AppConfig.mobileApiBaseUrl).host);
    expect(uri.scheme, 'https');
  });
}
