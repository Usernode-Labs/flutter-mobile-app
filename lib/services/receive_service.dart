import 'dart:math';
import '../models/receive_models.dart';

class ReceiveService {
  static ReceiveService? _instance;
  static ReceiveService get instance {
    _instance ??= ReceiveService._();
    return _instance!;
  }

  ReceiveService._();

  // Current receive settings
  ReceiveSettings _settings = ReceiveSettings();

  // List of generated addresses
  final List<ReceiveAddress> _addresses = [];

  // Current active address
  ReceiveAddress? _currentAddress;

  // Get current receive settings
  ReceiveSettings getSettings() => _settings;

  // Update receive settings
  void updateSettings(ReceiveSettings settings) {
    _settings = settings;
  }

  // Get current receiving address
  Future<ReceiveAddress> getCurrentAddress() async {
    if (_currentAddress == null ||
        _currentAddress!.isExpired ||
        (_settings.generateNewAddressForEachRequest &&
            _currentAddress!.isUsed)) {
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

    final addressType = type ?? _settings.preferredAddressType;
    final address = _generateMockAddress(addressType);

    final newAddress = ReceiveAddress(
      address: address,
      type: addressType,
      createdAt: DateTime.now(),
      expiresAt: expiration != null
          ? DateTime.now().add(expiration)
          : (addressType == ReceiveAddressType.temporary
              ? DateTime.now().add(_settings.defaultExpiration)
              : null),
      label: label,
    );

    _addresses.add(newAddress);
    _currentAddress = newAddress;

    return newAddress;
  }

  // Create a payment request
  PaymentRequest createPaymentRequest({
    required String address,
    double? amount,
    String? memo,
    Duration? expiration,
  }) {
    return PaymentRequest(
      address: address,
      amount: amount,
      memo: memo,
      createdAt: DateTime.now(),
      expiresAt: expiration != null ? DateTime.now().add(expiration) : null,
    );
  }

  // Address listing APIs removed (screen no longer shows history)

  // Mark address as used (when payment is received)
  void markAddressAsUsed(String address, double amount) {
    final index = _addresses.indexWhere((addr) => addr.address == address);
    if (index != -1) {
      _addresses[index] = _addresses[index].copyWith(
        isUsed: true,
        totalReceived: _addresses[index].totalReceived + amount,
      );
    }
  }

  // Amount validation removed (no longer used on receive screen)

  // Share address via different methods
  Future<bool> shareAddress(String address, ShareMethod method) async {
    await Future.delayed(const Duration(milliseconds: 300));

    switch (method) {
      case ShareMethod.copy:
        // In real app, this would copy to clipboard
        return true;
      case ShareMethod.share:
        // In real app, this would open system share sheet
        return true;
      case ShareMethod.email:
        // In real app, this would open email app
        return true;
      case ShareMethod.message:
        // In real app, this would open messaging app
        return true;
      case ShareMethod.qrCode:
        // QR code is handled in UI
        return true;
    }
  }

  // Check for incoming payments (mock)
  Future<List<IncomingPayment>> checkIncomingPayments() async {
    await Future.delayed(const Duration(seconds: 1));

    // Mock incoming payments
    final random = Random();
    if (random.nextDouble() > 0.7) {
      // 30% chance of new payment
      final amount = (random.nextDouble() * 100).roundToDouble();
      final address =
          _addresses.isNotEmpty ? _addresses.last.address : 'mock_address';

      return [
        IncomingPayment(
          address: address,
          amount: amount,
          transactionId: _generateTransactionId(),
          timestamp: DateTime.now(),
          confirmations: random.nextInt(6) + 1,
        ),
      ];
    }

    return [];
  }

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

  String _generateTransactionId() {
    return '0x${_generateHexString(64)}';
  }
}

class IncomingPayment {
  final String address;
  final double amount;
  final String transactionId;
  final DateTime timestamp;
  final int confirmations;

  IncomingPayment({
    required this.address,
    required this.amount,
    required this.transactionId,
    required this.timestamp,
    required this.confirmations,
  });

  bool get isConfirmed => confirmations >= 3;
  String get formattedAmount => '${amount.toStringAsFixed(2)} TOKENS';
}

// ValidationResult for receive removed. Send flow has its own type.
