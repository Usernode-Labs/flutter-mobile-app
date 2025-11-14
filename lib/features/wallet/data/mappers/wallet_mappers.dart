import 'package:crypto_mobile_app/features/wallet/data/models/transaction_model.dart'
    as data;
import 'package:crypto_mobile_app/features/wallet/domain/entities/transaction.dart'
    as domain;
import 'package:crypto_mobile_app/features/wallet/domain/entities/wallet_balance.dart';

extension TransactionModelToDomain on data.TransactionModel {
  domain.Transaction toDomain() {
    return domain.Transaction(
      id: id,
      title: title,
      subtitle: subtitle,
      amount: amount,
      currency: currency,
      type: switch (type) {
        data.TransactionType.receive => domain.TxType.receive,
        data.TransactionType.send => domain.TxType.send,
        data.TransactionType.reward => domain.TxType.reward,
        data.TransactionType.fee => domain.TxType.fee,
      },
      status: switch (status) {
        data.TransactionStatus.completed => domain.TxStatus.completed,
        data.TransactionStatus.pending => domain.TxStatus.pending,
        data.TransactionStatus.failed => domain.TxStatus.failed,
      },
      timestamp: timestamp,
    );
  }
}

extension WalletBalanceToDomain on data.WalletBalance {
  WalletBalanceEntity toDomain() => WalletBalanceEntity(
        tokenAmount: tokenAmount,
        tokenSymbol: tokenSymbol,
        usdValue: usdValue,
      );
}
