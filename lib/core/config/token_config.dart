/// Token configuration constants
class TokenConfig {
  /// Number of decimal places for the token
  /// Similar to Bitcoin (8 decimals) or Ethereum (18 decimals)
  /// 1 TOKEN = 10^8 smallest units
  static const int decimals = 8;
  
  /// Conversion factor: 10^decimals
  /// Used to convert user-friendly amounts to smallest units
  static final BigInt conversionFactor = BigInt.from(100000000); // 10^8
  
  /// Convert user input amount (with decimals) to smallest units (BigInt)
  /// Example: 0.1 TOKEN -> 10000000 smallest units
  static BigInt toSmallestUnit(double amount) {
    // Multiply by conversion factor and round to nearest integer
    final scaled = amount * conversionFactor.toInt();
    return BigInt.from(scaled.round());
  }
  
  /// Convert smallest units (BigInt) to user-friendly amount (double)
  /// Example: 10000000 smallest units -> 0.1 TOKEN
  static double fromSmallestUnit(BigInt smallestUnits) {
    return smallestUnits.toDouble() / conversionFactor.toInt();
  }
}
