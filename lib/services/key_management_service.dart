import '../models/wallet_key_models.dart';
import '../models/account_creation_result.dart';
import 'package:flutter/foundation.dart';

/// KeyManagementService
///
/// Responsibilities:
/// - Hold and manage mnemonic and derived keypair
/// - Provide a clear API for generate/import/export/clear
/// - Abstract storage so we can later swap to secure storage (Keychain/Keystore)
///
/// Notes:
/// - This implementation uses an in-memory backing store only.
/// - For production, replace [_store] with a secure implementation (e.g. flutter_secure_storage).
class KeyManagementService {
  static KeyManagementService? _instance;
  static KeyManagementService get instance {
    _instance ??= KeyManagementService._();
    return _instance!;
  }

  KeyManagementService._();

  final _store = _InMemoryKeyStore();

  // State cache
  WalletKeys _keys = const WalletKeys();

  // Public API
  WalletKeys get keys => _keys;
  bool get isInitialized => _keys.hasMnemonic || _keys.hasKeypair;

  // Optional pluggable derivation implementation injected by app layer.
  // Provide a function that, given a mnemonic and hdIndex, returns private/public/address.
  // For example, wire this to your Rust crypto via flutter_rust_bridge.
  Future<({String privateKey, String publicKey, String address})> Function(
      {required String mnemonic, required int hdIndex})?
      deriveFromMnemonic;

  // Provide a function to derive publicKey/address from a privateKey, if supported.
  Future<({String publicKey, String address})> Function(
      {required String privateKey})? deriveFromPrivateKey;

  // Optional mnemonic generator injection (e.g., BIP39). Return a space-separated phrase.
  Future<String> Function({int wordCount})? generateMnemonic;

  /// Save an existing mnemonic (does not derive keys yet)
  Future<void> saveMnemonic(String mnemonic) async {
    _keys = _keys.copyWith(mnemonic: mnemonic);
    await _store.saveMnemonic(mnemonic);
  }

  /// Save a keypair (use when keys come from outside)
  Future<void> saveKeypair({required String privateKey, required String publicKey}) async {
    _keys = _keys.copyWith(privateKey: privateKey, publicKey: publicKey);
    await _store.saveKeypair(privateKey: privateKey, publicKey: publicKey);
  }

  /// Import from mnemonic and (optionally) derive keys for the target network.
  /// Replace the body with actual derivation using your crypto/Rust layer.
  Future<void> importFromMnemonic(String mnemonic) async {
    // Persist mnemonic first
    await saveMnemonic(mnemonic);

    // TODO: Replace with real derivation using your chain's path
    // Example (pseudo):
    // final seed = await RustCrypto.deriveSeed(mnemonic, passphrase: '');
    // final pair = await RustCrypto.deriveKeypairFromSeed(seed, path: "m/44'/..." );
    // await saveKeypair(privateKey: pair.privateHex, publicKey: pair.publicHex);
  }

  /// High-level: create a complete account by generating mnemonic, deriving keys and caching them.
  /// Note: mnemonic generation itself is not implemented here; pass an existing mnemonic or
  /// inject a generator in your UI layer.
  Future<AccountCreationResult> createAccountFromMnemonic({
    required String mnemonic,
    int hdIndex = 0,
  }) async {
    try {
      await saveMnemonic(mnemonic);

      if (deriveFromMnemonic == null) {
        throw StateError(
            'No derivation implementation set. Provide KeyManagementService.deriveFromMnemonic.');
      }

      final derived = await deriveFromMnemonic!(mnemonic: mnemonic, hdIndex: hdIndex);
      await saveKeypair(privateKey: derived.privateKey, publicKey: derived.publicKey);
      _keys = _keys.copyWith(address: derived.address, hdIndex: hdIndex);

      return AccountCreationResult(
        mnemonic: mnemonic,
        privateKey: derived.privateKey,
        publicKey: derived.publicKey,
        address: derived.address,
        hdIndex: hdIndex,
        success: true,
        error: null,
      );
    } catch (e) {
      debugPrint('createAccountFromMnemonic error: $e');
      return AccountCreationResult(
        mnemonic: mnemonic,
        privateKey: '',
        publicKey: '',
        address: '',
        hdIndex: hdIndex,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// High-level: import an account from an existing private key.
  Future<AccountCreationResult> createAccountFromPrivateKey({
    required String privateKey,
  }) async {
    try {
      if (deriveFromPrivateKey == null) {
        throw StateError(
            'No private key derivation set. Provide KeyManagementService.deriveFromPrivateKey.');
      }

      final derived = await deriveFromPrivateKey!(privateKey: privateKey);
      await saveKeypair(privateKey: privateKey, publicKey: derived.publicKey);
      _keys = _keys.copyWith(address: derived.address, hdIndex: 0);

      return AccountCreationResult(
        mnemonic: '',
        privateKey: privateKey,
        publicKey: derived.publicKey,
        address: derived.address,
        hdIndex: 0,
        success: true,
        error: null,
      );
    } catch (e) {
      debugPrint('createAccountFromPrivateKey error: $e');
      return AccountCreationResult(
        mnemonic: '',
        privateKey: privateKey,
        publicKey: '',
        address: '',
        hdIndex: 0,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Load from storage into memory (no-op for in-memory store)
  Future<void> load() async {
    final stored = await _store.load();
    if (stored != null) {
      _keys = stored;
    }
  }

  /// Generate a new mnemonic and derive keys, returning a structured result.
  /// Requires [generateMnemonic] and [deriveFromMnemonic] to be provided by the app.
  Future<AccountCreationResult> generateAndCreateAccount({int hdIndex = 0, int wordCount = 12}) async {
    try {
      if (generateMnemonic == null) {
        throw StateError('No mnemonic generator set. Provide KeyManagementService.generateMnemonic.');
      }
      final mnemonic = await generateMnemonic!(wordCount: wordCount);
      return createAccountFromMnemonic(mnemonic: mnemonic, hdIndex: hdIndex);
    } catch (e) {
      debugPrint('generateAndCreateAccount error: $e');
      return AccountCreationResult(
        mnemonic: '',
        privateKey: '',
        publicKey: '',
        address: '',
        hdIndex: hdIndex,
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Clear all keys from memory and storage
  Future<void> clear() async {
    _keys = const WalletKeys();
    await _store.clear();
  }
}

/// Simple storage abstraction so we can later swap to secure storage
abstract class _KeyStore {
  Future<void> saveMnemonic(String mnemonic);
  Future<void> saveKeypair({required String privateKey, required String publicKey});
  Future<WalletKeys?> load();
  Future<void> clear();
}

/// In-memory only store (for development/demo). Not persisted.
class _InMemoryKeyStore implements _KeyStore {
  String? _mnemonic;
  String? _priv;
  String? _pub;
  String? _address;
  int? _hdIndex;

  @override
  Future<void> saveMnemonic(String mnemonic) async {
    _mnemonic = mnemonic;
  }

  @override
  Future<void> saveKeypair({required String privateKey, required String publicKey}) async {
    _priv = privateKey;
    _pub = publicKey;
  }

  @override
  Future<WalletKeys?> load() async {
    if ((_mnemonic == null || _mnemonic!.isEmpty) &&
        (_priv == null || _priv!.isEmpty) &&
        (_pub == null || _pub!.isEmpty)) {
      return null;
    }
    return WalletKeys(
      mnemonic: _mnemonic,
      privateKey: _priv,
      publicKey: _pub,
      address: _address,
      hdIndex: _hdIndex,
    );
  }

  @override
  Future<void> clear() async {
    _mnemonic = null;
    _priv = null;
    _pub = null;
    _address = null;
    _hdIndex = null;
  }
}
