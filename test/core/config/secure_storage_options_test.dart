import 'package:crypto_mobile_app/core/config/secure_storage_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android keeps v9 ciphers and never resets stored data', () {
    final params = usernodeAndroidSecureStorageOptions.params;

    expect(params, containsPair('resetOnError', 'false'));
    expect(params, containsPair('migrateOnAlgorithmChange', 'false'));
    expect(params, containsPair('migrateWithBackup', 'false'));
    expect(
      params,
      containsPair(
        'keyCipherAlgorithm',
        'RSA_ECB_PKCS1Padding',
      ),
    );
    expect(
      params,
      containsPair('storageCipherAlgorithm', 'AES_CBC_PKCS7Padding'),
    );
  });
}
