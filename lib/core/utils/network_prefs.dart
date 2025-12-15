import 'package:shared_preferences/shared_preferences.dart';

/// Utility for network-aware SharedPreferences access.
/// All keys are prefixed with the current network name to achieve
/// complete data isolation between networks (testnet/internal/custom).
class NetworkPrefs {
  static const networkKey = 'network:type';
  static const _globalKeys = {networkKey, 'app:theme_mode'};

  static String? _cachedNetwork;

  static const _allowedNetworks = {'testnet', 'internal', 'custom'};

  static String _normalizeNetwork(String? network) {
    if (network == null || network.isEmpty) return 'testnet';
    return _allowedNetworks.contains(network) ? network : 'testnet';
  }

  /// Get the current network type synchronously (after initialization).
  static String get currentNetwork => _cachedNetwork ?? 'testnet';

  /// Initialize the network cache. Call this early in app startup.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedNetwork = _normalizeNetwork(prefs.getString(networkKey));
  }

  /// Get the current network type from storage.
  static Future<String> getNetwork() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedNetwork = _normalizeNetwork(prefs.getString(networkKey));
    return _cachedNetwork!;
  }

  /// Prefix a key with the current network name.
  /// Global keys (network:type, app:theme_mode) are not prefixed.
  static String prefixKey(String key) {
    if (_globalKeys.contains(key)) return key;
    return '$currentNetwork:$key';
  }

  /// Prefix a key with a specific network name.
  static String prefixKeyWith(String key, String network) {
    if (_globalKeys.contains(key)) return key;
    return '$network:$key';
  }
}
