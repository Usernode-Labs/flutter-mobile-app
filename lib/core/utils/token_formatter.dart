import 'package:crypto_mobile_app/features/wallet/data/repositories/token_registry.dart';

/// Utility functions for formatting token information
class TokenFormatter {
  TokenFormatter._();

  /// Format a token ID for display by returning its symbol or a shortened ID
  ///
  /// Examples:
  /// - Native token: "NATIVE"
  /// - Unknown token: "TKN" or "0x1234...abcd"
  static String formatTokenDisplay(String tokenId) {
    final metadata = TokenRegistry.instance.getMetadataOrFallback(tokenId);
    return metadata.symbol;
  }

  /// Format a token ID with its name for detailed display
  ///
  /// Examples:
  /// - Native token: "Native Token (NATIVE)"
  /// - Unknown token: "Token 0x1234...abcd (TKN)"
  static String formatTokenDisplayWithName(String tokenId) {
    final metadata = TokenRegistry.instance.getMetadataOrFallback(tokenId);
    return '${metadata.name} (${metadata.symbol})';
  }

  /// Get the full name of a token
  static String getTokenName(String tokenId) {
    final metadata = TokenRegistry.instance.getMetadataOrFallback(tokenId);
    return metadata.name;
  }

  /// Get the symbol of a token
  static String getTokenSymbol(String tokenId) {
    final metadata = TokenRegistry.instance.getMetadataOrFallback(tokenId);
    return metadata.symbol;
  }
}
