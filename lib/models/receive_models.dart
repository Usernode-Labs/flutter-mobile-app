enum ReceiveAddressType {
  standard,
  temporary,
  stealth,
}

class ReceiveAddress {
  final String address;
  final ReceiveAddressType type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? label;
  final bool isUsed;
  final double totalReceived;

  ReceiveAddress({
    required this.address,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.label,
    this.isUsed = false,
    this.totalReceived = 0.0,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isValid => !isExpired;

  String get typeLabel {
    switch (type) {
      case ReceiveAddressType.standard:
        return 'Standard';
      case ReceiveAddressType.temporary:
        return 'Temporary';
      case ReceiveAddressType.stealth:
        return 'Stealth';
    }
  }

  String get statusText {
    if (isExpired) return 'Expired';
    if (isUsed) return 'Used';
    return 'Active';
  }

  String get formattedAddress {
    if (address.length <= 20) return address;
    return '${address.substring(0, 8)}...${address.substring(address.length - 8)}';
  }

  ReceiveAddress copyWith({
    String? address,
    ReceiveAddressType? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? label,
    bool? isUsed,
    double? totalReceived,
  }) {
    return ReceiveAddress(
      address: address ?? this.address,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      label: label ?? this.label,
      isUsed: isUsed ?? this.isUsed,
      totalReceived: totalReceived ?? this.totalReceived,
    );
  }
}

class PaymentRequest {
  final String address;
  final double? amount;
  final String? memo;
  final DateTime createdAt;
  final DateTime? expiresAt;

  PaymentRequest({
    required this.address,
    this.amount,
    this.memo,
    required this.createdAt,
    this.expiresAt,
  });

  String get qrData {
    final uri = StringBuffer();
    uri.write('usernode:$address');

    final params = <String>[];
    if (amount != null) {
      params.add('amount=${amount!.toStringAsFixed(8)}');
    }
    if (memo != null && memo!.isNotEmpty) {
      params.add('message=${Uri.encodeComponent(memo!)}');
    }

    if (params.isNotEmpty) {
      uri.write('?${params.join('&')}');
    }

    return uri.toString();
  }

  bool get hasAmount => amount != null && amount! > 0;
  bool get hasMemo => memo != null && memo!.isNotEmpty;

  String get formattedAmount {
    if (amount == null) return 'Any amount';
    return '${amount!.toStringAsFixed(2)} TOKENS';
  }

  PaymentRequest copyWith({
    String? address,
    double? amount,
    String? memo,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return PaymentRequest(
      address: address ?? this.address,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

enum ShareMethod {
  qrCode,
  copy,
  share,
  email,
  message,
}

class ReceiveSettings {
  final bool generateNewAddressForEachRequest;
  final bool showAmount;
  final bool showMemo;
  final Duration defaultExpiration;
  final ReceiveAddressType preferredAddressType;

  ReceiveSettings({
    this.generateNewAddressForEachRequest = false,
    this.showAmount = true,
    this.showMemo = true,
    this.defaultExpiration = const Duration(hours: 24),
    this.preferredAddressType = ReceiveAddressType.standard,
  });

  ReceiveSettings copyWith({
    bool? generateNewAddressForEachRequest,
    bool? showAmount,
    bool? showMemo,
    Duration? defaultExpiration,
    ReceiveAddressType? preferredAddressType,
  }) {
    return ReceiveSettings(
      generateNewAddressForEachRequest: generateNewAddressForEachRequest ??
          this.generateNewAddressForEachRequest,
      showAmount: showAmount ?? this.showAmount,
      showMemo: showMemo ?? this.showMemo,
      defaultExpiration: defaultExpiration ?? this.defaultExpiration,
      preferredAddressType: preferredAddressType ?? this.preferredAddressType,
    );
  }
}
