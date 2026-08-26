import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preserves Usernode's v9 Android storage behavior during the v10 rollout.
///
/// Keeping the legacy cipher pair avoids an unverified in-place migration of
/// existing account secrets and auth tokens. A cipher upgrade can be rolled
/// out separately after its install/upgrade path is validated on Android.
const usernodeAndroidSecureStorageOptions = AndroidOptions(
  resetOnError: false,
  migrateOnAlgorithmChange: false,
  // Intentionally retained for compatibility with data written by v9.
  // ignore: deprecated_member_use
  keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
  // Intentionally retained for compatibility with data written by v9.
  // ignore: deprecated_member_use
  storageCipherAlgorithm: StorageCipherAlgorithm.AES_CBC_PKCS7Padding,
);
