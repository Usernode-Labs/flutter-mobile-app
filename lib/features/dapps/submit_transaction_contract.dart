/// Exact native bridge request accepted by `submitTransaction`.
final class SubmitTransactionRequest {
  SubmitTransactionRequest._({
    required this.destinationPubkey,
    required this.amount,
    required this.memo,
    required this.confirmation,
  });

  static const int maxSafeInteger = 9007199254740991;
  static const _requestKeys = <String>{
    'destinationPubkey',
    'amount',
    'memo',
    'confirmation',
  };

  final String destinationPubkey;
  final BigInt amount;
  final String memo;
  final SubmitTransactionConfirmation? confirmation;

  factory SubmitTransactionRequest.fromBridgeArgs(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('args must be an object');
    }
    _rejectUnknownKeys(value, _requestKeys, 'args');

    final destination = value['destinationPubkey'];
    if (destination is! String || destination.trim().isEmpty) {
      throw const FormatException(
        'args.destinationPubkey must be a non-empty string',
      );
    }

    final rawAmount = value['amount'];
    if (rawAmount is! num ||
        !rawAmount.isFinite ||
        rawAmount <= 0 ||
        rawAmount > maxSafeInteger ||
        rawAmount != rawAmount.truncate()) {
      throw const FormatException(
        'args.amount must be a positive safe integer',
      );
    }

    final memo = value['memo'];
    if (memo is! String) {
      throw const FormatException('args.memo must be a string');
    }

    return SubmitTransactionRequest._(
      destinationPubkey: destination.trim(),
      amount: BigInt.from(rawAmount),
      memo: memo,
      confirmation: SubmitTransactionConfirmation._fromBridgeValue(
        value['confirmation'],
      ),
    );
  }
}

final class SubmitTransactionConfirmation {
  const SubmitTransactionConfirmation._({this.title, this.subtitle});

  static const _keys = <String>{'title', 'subtitle'};

  final String? title;
  final String? subtitle;

  static SubmitTransactionConfirmation? _fromBridgeValue(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('args.confirmation must be an object');
    }
    _rejectUnknownKeys(value, _keys, 'args.confirmation');
    return SubmitTransactionConfirmation._(
      title: _optionalTrimmedString(value, 'title'),
      subtitle: _optionalTrimmedString(value, 'subtitle'),
    );
  }
}

/// Exact successful bridge result returned by `submitTransaction`.
final class SubmitTransactionResult {
  SubmitTransactionResult({required String txId}) : txId = _validatedTxId(txId);

  final String txId;

  Map<String, Object> toBridgeJson() => {'txId': txId};
}

void _rejectUnknownKeys(
  Map<String, dynamic> value,
  Set<String> allowed,
  String path,
) {
  final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
  if (unknown.isNotEmpty) {
    throw FormatException('$path contains unsupported field ${unknown.first}');
  }
}

String? _optionalTrimmedString(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field == null) return null;
  if (field is! String) {
    throw FormatException('args.confirmation.$key must be a string');
  }
  final trimmed = field.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _validatedTxId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed != value) {
    throw ArgumentError.value(value, 'txId', 'must be non-empty and canonical');
  }
  return value;
}
