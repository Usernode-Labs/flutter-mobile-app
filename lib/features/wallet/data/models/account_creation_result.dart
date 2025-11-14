import 'dart:convert';

/// Comprehensive account creation result containing all generated data
class AccountCreationResult {
  final String mnemonic;
  final String privateKey;
  final String publicKey;
  final String address;
  final int hdIndex;
  final bool success;
  final String? error;

  const AccountCreationResult({
    required this.mnemonic,
    required this.privateKey,
    required this.publicKey,
    required this.address,
    required this.hdIndex,
    required this.success,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'mnemonic': mnemonic,
        'privateKey': privateKey,
        'publicKey': publicKey,
        'address': address,
        'hdIndex': hdIndex,
        'success': success,
        'error': error,
      };

  @override
  String toString() => jsonEncode(toJson());
}
