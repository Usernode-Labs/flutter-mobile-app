import 'dart:math';
import '../models/send_models.dart';
import '../models/transaction_model.dart';
import 'wallet_service.dart';

class SendService {
  static SendService? _instance;
  static SendService get instance {
    _instance ??= SendService._();
    return _instance!;
  }

  SendService._();

  final WalletService _walletService = WalletService.instance;

  // Get current network fees
  Future<NetworkFee> getNetworkFees() async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500));

    // Mock network fees - in real app this would fetch from network
    return NetworkFee(
      slow: 0.001,
      standard: 0.005,
      fast: 0.01,
      currency: 'TOKENS',
    );
  }

  // Validate send request
  ValidationResult validateSendRequest(SendRequest request) {
    final balance = _walletService.getBalance();

    // Check if address is valid
    if (!SendRequest.isValidAddress(request.toAddress)) {
      return ValidationResult.error('Invalid recipient address');
    }

    // Check if amount is positive
    if (request.amount <= 0) {
      return ValidationResult.error('Amount must be greater than 0');
    }

    // Check if amount exceeds balance
    if (request.amount > balance.tokenAmount) {
      return ValidationResult.error('Insufficient balance');
    }

    // Check minimum amount (mock validation)
    if (request.amount < 0.001) {
      return ValidationResult.error('Amount must be at least 0.001 TOKENS');
    }

    return ValidationResult.success();
  }

  // Calculate total amount including fees
  double calculateTotalAmount(double amount, double fee) {
    return amount + fee;
  }

  // Estimate transaction time
  String estimateTransactionTime(FeeType feeType) {
    final fees = NetworkFee(
      slow: 0.001,
      standard: 0.005,
      fast: 0.01,
      currency: 'TOKENS',
    );
    return fees.getTimeEstimate(feeType);
  }

  // Send tokens
  Future<SendResult> sendTokens(SendRequest request, FeeType feeType,
      {double? customFee}) async {
    try {
      // Validate request
      final validation = validateSendRequest(request);
      if (!validation.isValid) {
        return SendResult.error(validation.errorMessage!);
      }

      // Get network fees
      final networkFees = await getNetworkFees();
      final fee = customFee ?? networkFees.getFeeForType(feeType);
      final totalAmount = calculateTotalAmount(request.amount, fee);

      // Check total amount against balance
      final balance = _walletService.getBalance();
      if (totalAmount > balance.tokenAmount) {
        return SendResult.error('Insufficient balance for amount + fees');
      }

      // Simulate network delay for processing
      await Future.delayed(Duration(seconds: 2 + Random().nextInt(3)));

      // Mock transaction success/failure (90% success rate)
      final success = Random().nextDouble() > 0.1;

      if (success) {
        // Generate mock transaction ID
        final txId = _generateTransactionId();

        // In a real app, this would be handled by the wallet service
        // after receiving confirmation from the blockchain
        return SendResult.success(txId);
      } else {
        return SendResult.error('Transaction failed. Please try again.');
      }
    } catch (e) {
      return SendResult.error('Network error: ${e.toString()}');
    }
  }

  // Check if address is in contacts (mock)
  Future<String?> getContactName(String address) async {
    await Future.delayed(Duration(milliseconds: 200));

    // Mock contacts
    final mockContacts = {
      '0x1234567890abcdef1234567890abcdef12345678': 'Alice Johnson',
      '0xabcdef1234567890abcdef1234567890abcdef12': 'Bob Smith',
      'addr1qxy2lm4u2hjkl0987654321': 'Charlie Brown',
    };

    return mockContacts[address];
  }

  // Scan QR code (mock)
  Future<String?> scanQRCode() async {
    await Future.delayed(Duration(seconds: 1));

    // Mock QR code result
    final mockAddresses = [
      '0x1234567890abcdef1234567890abcdef12345678',
      '0xabcdef1234567890abcdef1234567890abcdef12',
      'addr1qxy2lm4u2hjkl0987654321',
    ];

    return mockAddresses[Random().nextInt(mockAddresses.length)];
  }

  // Generate mock transaction ID
  String _generateTransactionId() {
    const chars = '0123456789abcdef';
    final random = Random();
    return '0x' +
        String.fromCharCodes(Iterable.generate(
            64, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult._(this.isValid, this.errorMessage);

  factory ValidationResult.success() => ValidationResult._(true, null);
  factory ValidationResult.error(String message) =>
      ValidationResult._(false, message);
}
