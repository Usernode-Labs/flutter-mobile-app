import 'dart:convert';

class AppConfig {
  final String environment;
  final bool verboseLogging;

  const AppConfig._({
    required this.environment,
    required this.verboseLogging,
  });

  static const String _env =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const bool _verbose =
      bool.fromEnvironment('VERBOSE_LOGGING', defaultValue: false);

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
  final String secretKeyHex;
  final String publicKeyHex;
  final String publicKeyHashBech32m;
  final int amount;
  final String tier;

  DemoAccount({
    required this.secretKeyHex,
    required this.publicKeyHex,
    required this.publicKeyHashBech32m,
    required this.amount,
    required this.tier,
  });

  factory DemoAccount.fromJson(Map<String, dynamic> json) {
    return DemoAccount(
      secretKeyHex: json['secret_key_hex'] as String,
      publicKeyHex: json['public_key_hex'] as String,
      publicKeyHashBech32m: json['public_key_hash_bech32m'] as String,
      amount: json['amount'] as int,
      tier: json['tier'] as String,
    );
  }
}
