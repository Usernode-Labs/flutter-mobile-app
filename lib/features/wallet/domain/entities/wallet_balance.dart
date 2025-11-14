// Domain entity for wallet balance (UI-agnostic)

class WalletBalanceEntity {
  final double tokenAmount;
  final String tokenSymbol;
  final double usdValue;

  const WalletBalanceEntity({
    required this.tokenAmount,
    required this.tokenSymbol,
    required this.usdValue,
  });
}
