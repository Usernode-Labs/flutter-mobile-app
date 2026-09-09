import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_mobile_app/core/config/app_config.dart';

void main() {
  const configuredApi = String.fromEnvironment('MOBILE_API_BASE_URL');
  final expectedApi = configuredApi.isEmpty
      ? 'https://my.onhomeroom.com/api/v4/mobile'
      : configuredApi;
  final deployment = Uri.parse(expectedApi)
      .path
      .replaceFirst(RegExp(r'/api/v4/mobile/?$'), '');
  final origin = Uri.parse(expectedApi).origin;

  test('mobile API uses the deployment override or Homeroom default', () {
    expect(AppConfig.mobileApiBaseUrl, expectedApi);
    expect(AppConfig.authApiBaseUrl, '$expectedApi/auth');
  });

  test('platform follows the API deployment unless explicitly overridden', () {
    const platform = String.fromEnvironment('PLATFORM_BASE_URL');
    const legacy = String.fromEnvironment('DAPPS_TAB_URL');
    expect(
      AppConfig.platformBaseUrl,
      platform.isNotEmpty
          ? platform
          : legacy.isNotEmpty
              ? legacy
              : '$origin$deployment/',
    );
  });

  test('version checks follow the API deployment and preserve empty overrides',
      () {
    expect(
      AppConfig.versionCheckApiUrl,
      const bool.hasEnvironment('VERSION_CHECK_API_URL')
          ? const String.fromEnvironment('VERSION_CHECK_API_URL')
          : '$origin$deployment/api/v4/app-version/check',
    );
  });
}
