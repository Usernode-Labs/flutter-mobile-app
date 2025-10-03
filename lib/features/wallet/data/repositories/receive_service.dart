import 'dart:math';
import 'package:crypto_mobile_app/features/wallet/data/models/receive_models.dart';

class ReceiveService {
  static ReceiveService? _instance;
  static ReceiveService get instance {
    _instance ??= ReceiveService._();
    return _instance!;
  }

  ReceiveService._();

  // List of generated addresses
  final List<ReceiveAddress> _addresses = [];

  // Current active address
  ReceiveAddress? _currentAddress;

  // Get current receiving address
  Future<ReceiveAddress> getCurrentAddress() async {
    if (_currentAddress == null || _currentAddress!.isExpired) {
      _currentAddress = await generateNewAddress();
    }
    return _currentAddress!;
  }

  // Generate a new receiving address
  Future<ReceiveAddress> generateNewAddress({
    ReceiveAddressType? type,
    String? label,
    Duration? expiration,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final addressType = type ?? ReceiveAddressType.standard;
    final address = _generateMockAddress(addressType);

    final newAddress = ReceiveAddress(
      address: address,
      type: addressType,
      createdAt: DateTime.now(),
      expiresAt: expiration != null ? DateTime.now().add(expiration) : null,
      label: label,
    );

    _addresses.add(newAddress);
    _currentAddress = newAddress;

    return newAddress;
  }

  // Address listing APIs removed (screen no longer shows history)

  // Generate mock address based on type
  String _generateMockAddress(ReceiveAddressType type) {
    switch (type) {
      case ReceiveAddressType.standard:
        return '0x${_generateHexString(40)}';
      case ReceiveAddressType.temporary:
        return 'temp_${_generateHexString(32)}';
      case ReceiveAddressType.stealth:
        return 'stealth_${_generateHexString(48)}';
    }
  }

  String _generateHexString(int length) {
    const chars = '0123456789abcdef';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

}
// ValidationResult for receive removed. Send flow has its own type.
