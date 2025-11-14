import '../entities/transaction.dart';
import '../entities/wallet_balance.dart';

abstract class WalletRepository {
  Future<WalletBalanceEntity> getBalance();
  Future<List<Transaction>> getRecentTransactions({int limit = 10});
  Future<void> refresh();
}
