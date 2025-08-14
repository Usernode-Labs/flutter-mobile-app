enum SendStep {
  enterDetails,
  review,
  processing,
  success,
  error,
}

class SendRequest {
  final String toAddress;
  final double amount;
  final String? memo;
  final double? customFee;

  SendRequest({
    required this.toAddress,
    required this.amount,
    this.memo,
    this.customFee,
  });

  SendRequest copyWith({
    String? toAddress,
    double? amount,
    String? memo,
    double? customFee,
  }) {
    return SendRequest(
      toAddress: toAddress ?? this.toAddress,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      customFee: customFee ?? this.customFee,
    );
  }

  bool get isValid {
    return toAddress.isNotEmpty && amount > 0 && isValidAddress(toAddress);
  }

  static bool isValidAddress(String address) {
    // Mock address validation - in real app this would be proper validation
    return address.length >= 20 &&
        (address.startsWith('0x') || address.startsWith('addr'));
  }
}

class NetworkFee {
  final double slow;
  final double standard;
  final double fast;
  final String currency;

  NetworkFee({
    required this.slow,
    required this.standard,
    required this.fast,
    required this.currency,
  });

  double getFeeForType(FeeType type) {
    switch (type) {
      case FeeType.slow:
        return slow;
      case FeeType.standard:
        return standard;
      case FeeType.fast:
        return fast;
      case FeeType.custom:
        return standard; // Default fallback
    }
  }

  String getTimeEstimate(FeeType type) {
    switch (type) {
      case FeeType.slow:
        return '~10 min';
      case FeeType.standard:
        return '~5 min';
      case FeeType.fast:
        return '~2 min';
      case FeeType.custom:
        return 'Variable';
    }
  }
}

enum FeeType {
  slow,
  standard,
  fast,
  custom,
}

class SendResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;

  SendResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
  });

  SendResult.success(this.transactionId)
      : success = true,
        errorMessage = null;

  SendResult.error(this.errorMessage)
      : success = false,
        transactionId = null;
}
