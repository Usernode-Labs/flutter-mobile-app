class AppConfig {
  final String environment;
  final String apiBaseUrl;
  final bool verboseLogging;

  const AppConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.verboseLogging,
  });

  static const String _env =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const String _api =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const bool _verbose =
      bool.fromEnvironment('VERBOSE_LOGGING', defaultValue: false);

  static AppConfig get instance => AppConfig._(
        environment: _env,
        apiBaseUrl: _api,
        verboseLogging: _verbose,
      );

  // GitHub configuration
  static const String githubToken =
      String.fromEnvironment('GITHUB_TOKEN', defaultValue: '');
  static const String githubOwner = 'Usernode-Labs';
  static const String githubRepo = 'flutter-mobile-app';
}
