import 'dart:convert';

import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_mempool.dart';
import 'package:crypto_mobile_app/src/rust/rpc/rpcs_generated/list_utxos_by_owner.dart';
import 'package:crypto_mobile_app/src/rust/frb_types.dart' as frb_types;

/// Represents a transaction activity item (either pending or confirmed)
class TransactionItem {
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final List<AssetAmount> amounts;
  final String? recipientAddress;
  final BigInt? fee;

  const TransactionItem({
    required this.id,
    required this.type,
    required this.status,
    required this.amounts,
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
          amounts == other.amounts &&
          recipientAddress == other.recipientAddress &&
          fee == other.fee;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      status.hashCode ^
      amounts.hashCode ^
      recipientAddress.hashCode ^
      fee.hashCode;

  @override
  String toString() =>
      'TransactionItem(id: $id, type: $type, status: $status, amounts: ${amounts.length})';

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

      // Extract assets
      final assetsJson = utxoData['assets'] as List<dynamic>? ?? [];
      final amounts = assetsJson.map((assetJson) {
        return AssetAmount(
          tokenId: assetJson['token_id'] as String,
          amount: BigInt.from(assetJson['balance'] as int),
        );
      }).toList();

      // Extract recipient
      String? recipientAddress;
      final recipientJson = utxoData['recipient'] as Map<String, dynamic>?;
      if (recipientJson != null) {
        if (recipientJson.containsKey('Key')) {
          final keyData = recipientJson['Key'] as Map<String, dynamic>;
          recipientAddress = keyData['pk_hash'] as String;
        } else if (recipientJson.containsKey('Script')) {
          final scriptData = recipientJson['Script'] as Map<String, dynamic>;
          final scriptRoot = scriptData['script_root'] as String;
          recipientAddress = 'Script: ${scriptRoot.substring(0, scriptRoot.length > 16 ? 16 : scriptRoot.length)}...';
        }
      }

      // Determine transaction type based on amount
      TransactionType txType = TransactionType.received;
      if (amounts.isNotEmpty) {
        final firstAmount = amounts.first.amount.toInt();
        final rewardAmount = coinbaseRewardAmount?.toInt() ?? 20;
        if (firstAmount == rewardAmount) {
          txType = TransactionType.coinbaseReward;
        } else if (firstAmount == 50000000) {
          txType = TransactionType.genesis;
        }
      }

      return TransactionItem(
        id: commitmentHex,
        type: txType,
        status: TransactionStatus.confirmed,
        amounts: amounts,
        recipientAddress: recipientAddress,
        fee: null,
      );
    } catch (e) {
      // Fallback if JSON parsing fails
      return TransactionItem(
        id: commitmentHex,
        type: TransactionType.received,
        status: TransactionStatus.confirmed,
        amounts: const [],
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
    // NOTE: The outputs are List<Utxo> which are RustOpaqueInterface
    // We cannot access their fields directly from Dart

    // For now, we can determine send vs receive based on input/output count
    // If we have inputs, we're spending UTXOs (sent)
    // If we have no inputs but have outputs, we're receiving
    final isSent = tx.inputs.isNotEmpty;

    return TransactionItem(
      id: tx.id.toString(),
      type: isSent ? TransactionType.sent : TransactionType.received,
      status: TransactionStatus.pending,
      amounts: const [], // Cannot access - opaque type
      recipientAddress: null, // Cannot access - opaque type
      fee: tx.fee,
    );
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
