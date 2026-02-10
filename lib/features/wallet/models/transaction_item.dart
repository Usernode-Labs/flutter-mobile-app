import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

typedef ParsedMempoolOutput = ({
  String? recipientAddress,
  AssetAmount? asset,
});

/// Select the output we should display as the "amount" for a pending mempool tx.
///
/// For typical wallet sends we expect:
/// - 1 output: input is fully consumed (no change)
/// - 2 outputs: [payment, change]
///
/// In the 2-output case we drop the output that pays back to `ownerAddress`
/// (change) and display the other output's asset.
///
/// Self-send edge case:
/// If the transaction sends to the same address as `ownerAddress`, filtering out
/// change can remove *all* outputs. For now we fall back to `outputs.first`,
/// relying on the node's current output ordering ([payment, change]) where the
/// change output is second. This is a temporary workaround until the node logic
/// prevents self-sends or explicitly tags change outputs.
ParsedMempoolOutput? selectMempoolOutputForDisplay({
  required List<ParsedMempoolOutput> outputs,
  required bool isSent,
  required String ownerAddress,
}) {
  if (outputs.isEmpty) return null;

  if (isSent) {
    if (outputs.length == 1) return outputs.first;

    final nonChange =
        outputs.where((o) => o.recipientAddress != ownerAddress).toList();
    return nonChange.isNotEmpty ? nonChange.first : outputs.first;
  }

  // Receiving: prefer outputs that pay to us (can be multiple in batched txs).
  final toOwner = outputs.where((o) => o.recipientAddress == ownerAddress);
  return toOwner.isNotEmpty ? toOwner.first : outputs.first;
}

/// Represents a transaction activity item (either pending or confirmed)
class TransactionItem {
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final AssetAmount? asset;
  final String? recipientAddress;
  final BigInt? fee;

  const TransactionItem({
    required this.id,
    required this.type,
    required this.status,
    this.asset,
    this.recipientAddress,
    this.fee,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          status == other.status &&
          asset == other.asset &&
          recipientAddress == other.recipientAddress &&
          fee == other.fee;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      status.hashCode ^
      asset.hashCode ^
      recipientAddress.hashCode ^
      fee.hashCode;

  @override
  String toString() =>
      'TransactionItem(id: $id, type: $type, status: $status, hasAsset: ${asset != null})';

  /// Create from a confirmed UTXO (received transaction)
  factory TransactionItem.fromUtxo({
    required OwnedUtxo utxo,
    required String commitmentHex,
    BigInt? coinbaseRewardAmount,
  }) {
    try {
      // Serialize UTXO to JSON to access its fields
      final jsonStr = frb_types.utxoToJson(utxo: utxo.utxo);
      final utxoData = json.decode(jsonStr) as Map<String, dynamic>;

      // Extract the single asset.
      final asset = _parseAssetAmount(utxoData);

      // Extract recipient
      final recipientAddress = _parseRecipientAddress(utxoData);

      // Determine transaction type based on amount
      TransactionType txType = TransactionType.received;
      if (asset != null) {
        final firstAmount = asset.amount.toInt();
        final rewardAmount = coinbaseRewardAmount?.toInt();
        if (rewardAmount != null && firstAmount == rewardAmount) {
          txType = TransactionType.coinbaseReward;
        } else if (firstAmount == 50000000) {
          txType = TransactionType.genesis;
        }
      }

      return TransactionItem(
        id: commitmentHex,
        type: txType,
        status: TransactionStatus.confirmed,
        asset: asset,
        recipientAddress: recipientAddress,
        fee: null,
      );
    } catch (e) {
      // Fallback if JSON parsing fails
      return TransactionItem(
        id: commitmentHex,
        type: TransactionType.received,
        status: TransactionStatus.confirmed,
        asset: null,
        recipientAddress: null,
        fee: null,
      );
    }
  }

  /// Create from a pending mempool transaction
  factory TransactionItem.fromMempoolTx({
    required MempoolTxSummary tx,
    required String ownerAddress,
  }) {
    // Determine send vs receive based on input count
    // If we have inputs, we're spending UTXOs (sent)
    // If we have no inputs but have outputs, we're receiving
    final isSent = tx.inputs.isNotEmpty;

    // Parse outputs via JSON serialization to extract recipient + asset.
    final parsedOutputs = tx.outputs.map((output) {
      try {
        final jsonStr = frb_types.utxoToJson(utxo: output);
        final utxoData = json.decode(jsonStr) as Map<String, dynamic>;
        return (
          recipientAddress: _parseRecipientAddress(utxoData),
          asset: _parseAssetAmount(utxoData),
        );
      } catch (_) {
        return (recipientAddress: null, asset: null);
      }
    }).toList();

    final selected = selectMempoolOutputForDisplay(
      outputs: parsedOutputs,
      isSent: isSent,
      ownerAddress: ownerAddress,
    );

    return TransactionItem(
      id: tx.id.toString(),
      type: isSent ? TransactionType.sent : TransactionType.received,
      status: TransactionStatus.pending,
      asset: selected?.asset,
      recipientAddress: isSent ? selected?.recipientAddress : null,
      fee: tx.fee,
    );
  }

  static BigInt? _parseBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is num) return BigInt.from(value.toInt());
    if (value is String) return BigInt.tryParse(value);
    return null;
  }

  static AssetAmount? _parseAssetAmount(Map<String, dynamic> utxoData) {
    final tokenId =
        (utxoData['token_id'] ?? utxoData['tokenId'])?.toString() ?? '';
    final amount = _parseBigInt(utxoData['amount'] ?? utxoData['balance']);
    if (tokenId.isNotEmpty && amount != null) {
      return AssetAmount(tokenId: tokenId, amount: amount);
    }

    return null;
  }

  static String? _parseRecipientAddress(Map<String, dynamic> utxoData) {
    final recipientJson = utxoData['recipient'] as Map<String, dynamic>?;
    if (recipientJson == null) return null;

    if (recipientJson.containsKey('Key')) {
      final keyData = recipientJson['Key'] as Map<String, dynamic>?;
      return keyData?['pk_hash'] as String?;
    }

    if (recipientJson.containsKey('Script')) {
      final scriptData = recipientJson['Script'] as Map<String, dynamic>?;
      final scriptRoot = scriptData?['script_root'] as String?;
      if (scriptRoot == null) return null;
      final prefix = scriptRoot.substring(
          0, scriptRoot.length > 16 ? 16 : scriptRoot.length);
      return 'Script: $prefix...';
    }

    return null;
  }
}

/// Type of transaction
enum TransactionType {
  sent,
  received,
  coinbaseReward,
  genesis,
}

/// Status of transaction
enum TransactionStatus {
  pending,
  confirmed,
}

/// Represents an amount of a specific asset
class AssetAmount {
  final String tokenId;
  final BigInt amount;

  const AssetAmount({
    required this.tokenId,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetAmount &&
          runtimeType == other.runtimeType &&
          tokenId == other.tokenId &&
          amount == other.amount;

  @override
  int get hashCode => tokenId.hashCode ^ amount.hashCode;

  @override
  String toString() => 'AssetAmount(tokenId: $tokenId, amount: $amount)';
}
