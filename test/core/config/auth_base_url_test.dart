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
