enum ReceiveAddressType { standard, temporary, stealth }

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

// Removed unused PaymentRequest, ShareMethod, and ReceiveSettings.
