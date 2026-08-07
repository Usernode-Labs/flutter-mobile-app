import 'package:crypto_mobile_app/core/services/explorer_service.dart';

/// The active identity's wallet balance, served to the SV web app via the
/// bridge's `getWalletState`.
class WalletBalance {
  final double tokenAmount;
  final String tokenSymbol;
  final BigInt totalBalance; // Base units.
  final DataSource dataSource;
  final DateTime? lastUpdated;

  WalletBalance({
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.totalBalance,
    this.dataSource = DataSource.local,
    this.lastUpdated,
  });

  factory WalletBalance.fromExplorerBalance(ExplorerBalanceResponse response) {
    return WalletBalance(
      tokenAmount: response.balance,
      tokenSymbol: response.tokenSymbol,
      totalBalance: BigInt.from(response.balance.toInt()),
      dataSource: response.dataSource,
      lastUpdated: response.fetchedAt,
    );
  }
}
