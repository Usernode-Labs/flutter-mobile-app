import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zkPassport bridge uses the deployment override or Homeroom default',
      () {
    const override = String.fromEnvironment('ZKPASSPORT_BRIDGE_BASE_URL');

    expect(
      AppConfig.zkPassportBridgeBaseUrl,
      override.isNotEmpty ? override : 'https://zkbridge.onhomeroom.com',
    );
  });
}
