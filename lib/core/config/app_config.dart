import 'dart:convert';

class AppConfig {
  final String environment;
  final bool verboseLogging;

  const AppConfig._({
    required this.environment,
    required this.verboseLogging,
  });

  // === App Information ===
  static const String appName = 'Usernode';
  static const String appTagline =
      'A New Layer 1. Operated & Secured by You. From Your Phone';

  // === Animation Durations ===
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 500);
  static const Duration longAnimation = Duration(seconds: 1);

  // === Currency Constants ===
  static const String defaultTokenSymbol = 'TKN';
  static const String defaultFiatCurrency = 'USD';

  static const String _env =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const bool _verbose =
      bool.fromEnvironment('VERBOSE_LOGGING', defaultValue: false);

  // Logging configuration
  // Global log level (trace, debug, info, warning, error)
  static const String logLevel =
      String.fromEnvironment('LOG_LEVEL', defaultValue: 'warning');

  // Per-tag log level overrides (format: tag:level,tag:level)
  static const String logTagLevels =
      String.fromEnvironment('LOG_TAG_LEVELS', defaultValue: '');

  // Rust-side log level (trace, debug, info, warn, error)
  // Default to warn level for production readiness
  static const String rustLogLevel =
      String.fromEnvironment('RUST_LOG_LEVEL', defaultValue: 'warn');

  static AppConfig get instance => AppConfig._(
        environment: _env,
        verboseLogging: _verbose,
      );

  // Registration API
  static const String registrationEndpoint = String.fromEnvironment(
    'REGISTRATION_ENDPOINT',
    defaultValue: 'https://api.topo.usernodelabs.org/api/v1/register',
  );

  // GitHub configuration
  static const String githubToken =
      String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
  static const String githubOwner = 'Usernode-Labs';
  static const String githubRepo = 'flutter-mobile-app';

  // Default URLs (used as fallbacks when env vars are empty)
  static const String _defaultTestnetSeedlistUrl =
      'https://static.usernodelabs.org/testnet/seedlist.txt';
  static const String _defaultTestnetGenesisUrl =
      'https://static.usernodelabs.org/testnet/genesis.json';
  static const String _defaultInternalSeedlistUrl =
      'https://static.usernodelabs.org/catdog9000/seedlist.txt';
  static const String _defaultInternalGenesisUrl =
      'https://static.usernodelabs.org/catdog9000/genesis.json';
  static const String _defaultCustomSeedlistUrl =
      'https://static.usernodelabs.org/custom/seedlist.txt';
  static const String _defaultCustomGenesisUrl =
      'https://static.usernodelabs.org/custom/genesis.json';
  static const String _defaultNetworkSwitcherCode = '2107';
  static const int _defaultLoadGenesisNbRetries = 3;

  // Raw environment values (may be empty)
  static const String _rawSeedlistUrl = String.fromEnvironment('SEEDLIST_URL');
  static const String _rawGenesisUrl = String.fromEnvironment('GENESIS_URL');
  static const String _rawCustomSeedlistUrl =
      String.fromEnvironment('CUSTOM_SEEDLIST_URL');
  static const String _rawCustomGenesisUrl =
      String.fromEnvironment('CUSTOM_GENESIS_URL');
  static const String _rawTestnetSeedlistUrl =
      String.fromEnvironment('TESTNET_SEEDLIST_URL');
  static const String _rawTestnetGenesisUrl =
      String.fromEnvironment('TESTNET_GENESIS_URL');
  static const String _rawInternalSeedlistUrl =
      String.fromEnvironment('INTERNAL_SEEDLIST_URL');
  static const String _rawInternalGenesisUrl =
      String.fromEnvironment('INTERNAL_GENESIS_URL');
  static const String _rawNetworkSwitcherCode =
      String.fromEnvironment('NETWORK_SWITCHER_CODE');
  static const int _rawLoadGenesisNbRetries =
      int.fromEnvironment('LOAD_GENESIS_NB_RETRIES');

  // Number of retries when fetching genesis/seedlist URLs
  // Falls back to 3 if 0 or not set
  static int get loadGenesisNbRetries => _rawLoadGenesisNbRetries > 0
      ? _rawLoadGenesisNbRetries
      : _defaultLoadGenesisNbRetries;

  // Network switcher configuration
  // Testnet URLs (default network) - falls back to defaults if empty
  static String get testnetSeedlistUrl => _rawTestnetSeedlistUrl.isNotEmpty
      ? _rawTestnetSeedlistUrl
      : _defaultTestnetSeedlistUrl;
  static String get testnetGenesisUrl => _rawTestnetGenesisUrl.isNotEmpty
      ? _rawTestnetGenesisUrl
      : _defaultTestnetGenesisUrl;

  // Internal network URLs - falls back to defaults if empty
  static String get internalSeedlistUrl => _rawInternalSeedlistUrl.isNotEmpty
      ? _rawInternalSeedlistUrl
      : _defaultInternalSeedlistUrl;
  static String get internalGenesisUrl => _rawInternalGenesisUrl.isNotEmpty
      ? _rawInternalGenesisUrl
      : _defaultInternalGenesisUrl;

  // Custom test network URLs - falls back to defaults if empty
  static String get customSeedlistUrl => _rawCustomSeedlistUrl.isNotEmpty
      ? _rawCustomSeedlistUrl
      : _rawSeedlistUrl.isNotEmpty
          ? _rawSeedlistUrl
          : _defaultCustomSeedlistUrl;
  static String get customGenesisUrl => _rawCustomGenesisUrl.isNotEmpty
      ? _rawCustomGenesisUrl
      : _rawGenesisUrl.isNotEmpty
          ? _rawGenesisUrl
          : _defaultCustomGenesisUrl;

  // Secret code for network switcher access - falls back to default if empty
  static String get networkSwitcherCode => _rawNetworkSwitcherCode.isNotEmpty
      ? _rawNetworkSwitcherCode
      : _defaultNetworkSwitcherCode;
  // Metrics configuration (compile-time)
  static const bool metricsEnabled =
      bool.fromEnvironment('METRICS_ENABLED', defaultValue: false);
  static const String metricsEndpoint =
      String.fromEnvironment('METRICS_ENDPOINT', defaultValue: '');
  static const int metricsInterval =
      int.fromEnvironment('METRICS_INTERVAL', defaultValue: 30);
  static const String metricsHealthEndpoint =
      String.fromEnvironment('METRICS_HEALTH_ENDPOINT', defaultValue: '');

  // Block Production configuration (all in seconds)
  static const int metricsCollectionIntervalSeconds = int.fromEnvironment(
      'METRICS_COLLECTION_INTERVAL_SECONDS',
      defaultValue: 30);
  static const int blockProductionWakeBeforeSlotSeconds = int.fromEnvironment(
      'BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS',
      defaultValue: 60);
  static const int epochMonitorBaseIntervalSeconds = int.fromEnvironment(
      'EPOCH_MONITOR_BASE_INTERVAL_SECONDS',
      defaultValue: 900);

  // Convert to Duration for convenience
  static Duration get metricsCollectionInterval =>
      Duration(seconds: metricsCollectionIntervalSeconds);
  static Duration get blockProductionWakeBeforeSlot =>
      Duration(seconds: blockProductionWakeBeforeSlotSeconds);
  static Duration get epochMonitorBaseInterval =>
      Duration(seconds: epochMonitorBaseIntervalSeconds);

  // Version check configuration
  // If empty, version checking is disabled
  static const String versionCheckApiUrl =
      String.fromEnvironment('VERSION_CHECK_API_URL', defaultValue: '');
  static const int versionCheckIntervalSeconds =
      int.fromEnvironment('VERSION_CHECK_INTERVAL_SECONDS', defaultValue: 7200);

  static Duration get versionCheckInterval =>
      Duration(seconds: versionCheckIntervalSeconds);
  static bool get versionCheckEnabled => versionCheckApiUrl.isNotEmpty;

  // Demo accounts configuration (JSON object with account metadata)
  static const String _demoAccountsJson = String.fromEnvironment(
      'DEMO_ACCOUNTS_JSON',
      defaultValue: '{"accounts":[]}');

  static List<DemoAccount> get demoAccounts {
    try {
      final decoded = jsonDecode(_demoAccountsJson);
      if (decoded is Map && decoded['accounts'] is List) {
        final accounts = decoded['accounts'] as List;
        return accounts
            .map((acc) => DemoAccount.fromJson(acc as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Demo account model with metadata
class DemoAccount {
  final String secretKey;
  final String publicKey;
  final String address;
  final int amount;
  final String tier;

  DemoAccount({
    required this.secretKey,
    required this.publicKey,
    required this.address,
    required this.amount,
    required this.tier,
  });

  factory DemoAccount.fromJson(Map<String, dynamic> json) {
    String requiredString(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) return value;
      }
      throw FormatException('Missing required field: ${keys.join(' or ')}');
    }

    return DemoAccount(
      secretKey: requiredString(['secret_key', 'secret_key_hex']),
      publicKey: requiredString(['public_key', 'public_key_hex']),
      address: requiredString([
        'address',
        'public_key_hash_bech32m',
        'public_key_hash',
      ]),
      amount: json['amount'] as int,
      tier: json['tier'] as String,
    );
  }
}
