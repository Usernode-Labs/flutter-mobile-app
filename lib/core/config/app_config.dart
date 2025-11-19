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
  static const int metricsCollectionIntervalSeconds =
      int.fromEnvironment('METRICS_COLLECTION_INTERVAL_SECONDS', defaultValue: 30);
  static const int blockProductionWakeBeforeSlotSeconds =
      int.fromEnvironment('BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS', defaultValue: 60);
  static const int epochMonitorBaseIntervalSeconds =
      int.fromEnvironment('EPOCH_MONITOR_BASE_INTERVAL_SECONDS', defaultValue: 900);

  // Convert to Duration for convenience
  static Duration get metricsCollectionInterval =>
      Duration(seconds: metricsCollectionIntervalSeconds);
  static Duration get blockProductionWakeBeforeSlot =>
      Duration(seconds: blockProductionWakeBeforeSlotSeconds);
  static Duration get epochMonitorBaseInterval =>
      Duration(seconds: epochMonitorBaseIntervalSeconds);

  // Debug method to verify metrics configuration at runtime
  static void debugPrintMetrics() {
    print('=== METRICS CONFIG DEBUG ===');
    print('METRICS_ENABLED: $metricsEnabled');
    print('METRICS_ENDPOINT: $metricsEndpoint');
    print('METRICS_INTERVAL: $metricsInterval');
    print('METRICS_HEALTH_ENDPOINT: $metricsHealthEndpoint');
    print('===========================');
  }
}
