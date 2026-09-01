/// The active identity's wallet balance, served to the SV web app via the
/// bridge's `getWalletState`.
class WalletBalance {
  final double tokenAmount;
  final String tokenSymbol;
  final BigInt totalBalance; // Base units.
  final DateTime? lastUpdated;

  WalletBalance({
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.totalBalance,
    this.lastUpdated,
  });
}
