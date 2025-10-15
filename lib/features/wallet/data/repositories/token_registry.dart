/// Token Registry for managing token metadata
///
/// This service maps token IDs to human-readable names, symbols, and other metadata.
/// In the future, this should be replaced with:
/// - On-chain token registry lookup
/// - Remote API for token metadata
/// - Local database cache
class TokenRegistry {
  TokenRegistry._();

  static final TokenRegistry instance = TokenRegistry._();

  /// Known token metadata by token ID
  final Map<String, TokenMetadata> _registry = {
    // Native token (zero address or default)
    '0x0000000000000000000000000000000000000000000000000000000000000000':
        TokenMetadata(
      tokenId:
          '0x0000000000000000000000000000000000000000000000000000000000000000',
      name: 'Native Token',
      symbol: 'NATIVE',
      decimals: 0,
      icon: null,
    ),
    'default': TokenMetadata(
      tokenId: 'default',
      name: 'Native Token',
      symbol: 'NATIVE',
      decimals: 0,
      icon: null,
    ),
    // Add more known tokens here as needed
  };

  /// Get metadata for a token ID
  /// Returns null if token is not in registry
  TokenMetadata? getMetadata(String tokenId) {
    return _registry[tokenId];
  }

  /// Get metadata for a token ID or create a fallback
  TokenMetadata getMetadataOrFallback(String tokenId) {
    final metadata = _registry[tokenId];
    if (metadata != null) {
      return metadata;
    }

    // Create fallback metadata for unknown tokens
    final shortId = _shortenTokenId(tokenId);
    return TokenMetadata(
      tokenId: tokenId,
      name: 'Token $shortId',
      symbol: 'TKN',
      decimals: 0,
      icon: null,
    );
  }

  /// Register a new token in the registry
  void registerToken(TokenMetadata metadata) {
    _registry[metadata.tokenId] = metadata;
  }

  /// Check if a token is registered
  bool isRegistered(String tokenId) {
    return _registry.containsKey(tokenId);
  }

  /// Get all registered tokens
  List<TokenMetadata> getAllTokens() {
    return _registry.values.toList();
  }

  /// Clear all registered tokens (useful for testing)
  void clear() {
    _registry.clear();
  }

  /// Helper to shorten token ID for display
  String _shortenTokenId(String tokenId) {
    if (tokenId.length <= 10) {
      return tokenId;
    }
    return '${tokenId.substring(0, 6)}...${tokenId.substring(tokenId.length - 4)}';
  }
}

/// Token metadata model
class TokenMetadata {
  final String tokenId;
  final String name;
  final String symbol;
  final int decimals;
  final String? icon;

  const TokenMetadata({
    required this.tokenId,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenMetadata &&
          runtimeType == other.runtimeType &&
          tokenId == other.tokenId &&
          name == other.name &&
          symbol == other.symbol &&
          decimals == other.decimals &&
          icon == other.icon;

  @override
  int get hashCode =>
      tokenId.hashCode ^
      name.hashCode ^
      symbol.hashCode ^
      decimals.hashCode ^
      icon.hashCode;

  @override
  String toString() =>
      'TokenMetadata(tokenId: $tokenId, name: $name, symbol: $symbol, decimals: $decimals)';
}
