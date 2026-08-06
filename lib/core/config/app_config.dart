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

  static AppConfig get instance => const AppConfig._(
        environment: _env,
        verboseLogging: _verbose,
      );

  // Token-scoped mobile API (data + auth). Default is the Social Vibecoding
  // platform's v4 mobile API, which replaced topochain's v2/v3 leaderboard
  // API after the account/leaderboard data migration. `MOBILE_API_BASE_URL`
  // overrides (e.g. a staging deployment of the same v4 API). The retired
  // topochain v3 backend is NOT supported: onboarding depends on the
  // v4-only `/wallet/provision`, so a v3-pointed build could never onboard
  // a fresh user (the old `MOBILE_API_V3_BASE_URL` define is ignored).
  static const String _rawMobileApiBaseUrl =
      String.fromEnvironment('MOBILE_API_BASE_URL', defaultValue: '');
  static const String _defaultMobileApiBaseUrl =
      'https://social-vibecoding.usernodelabs.org/api/v4/mobile';
  static String get mobileApiBaseUrl => _rawMobileApiBaseUrl.isNotEmpty
      ? _rawMobileApiBaseUrl
      : _defaultMobileApiBaseUrl;

  // Auth endpoints live under the mobile API base (v4: /auth/check-email,
  // /auth/login, /auth/otp/*, /auth/set-password, /auth/logout — same paths
  // as topochain v3).
  static String get authApiBaseUrl => '$mobileApiBaseUrl/auth';

  // Public deployment identity for Social remote notifications. Keeping both
  // values explicit makes unprovisioned/local builds fail closed without
  // accidentally registering against another Firebase project.
  static const String pushEnvironment = String.fromEnvironment(
    'PUSH_ENV',
    defaultValue: '',
  );
  static const String expectedFirebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  // Startup bootstrap for local/dev sign-in without registration.
  static const String _bootstrapSecretKey =
      String.fromEnvironment('BOOTSTRAP_SECRET_KEY', defaultValue: '');
  static const String bootstrapAccountName = String.fromEnvironment(
      'BOOTSTRAP_ACCOUNT_NAME',
      defaultValue: 'Bootstrap Account');
  static const String _bootstrapParticipantIdRaw =
      String.fromEnvironment('BOOTSTRAP_PARTICIPANT_ID', defaultValue: '');
  static const String _bootstrapSeasonIdRaw =
      String.fromEnvironment('BOOTSTRAP_SEASON_ID', defaultValue: '');
  static const String bootstrapSeasonName =
      String.fromEnvironment('BOOTSTRAP_SEASON_NAME', defaultValue: '');
  static const String _bootstrapEventIdRaw =
      String.fromEnvironment('BOOTSTRAP_EVENT_ID', defaultValue: '');
  static const String bootstrapEventName =
      String.fromEnvironment('BOOTSTRAP_EVENT_NAME', defaultValue: '');
  static const bool bootstrapCompleteOnboarding = bool.fromEnvironment(
    'BOOTSTRAP_COMPLETE_ONBOARDING',
    defaultValue: true,
  );

  static String get bootstrapSecretKey => _bootstrapSecretKey.trim();
  static bool get hasBootstrapSecretKey => bootstrapSecretKey.isNotEmpty;
  static int? get bootstrapParticipantId =>
      _parseOptionalInt(_bootstrapParticipantIdRaw);
  static int? get bootstrapSeasonId => _parseOptionalInt(_bootstrapSeasonIdRaw);
  static int? get bootstrapEventId => _parseOptionalInt(_bootstrapEventIdRaw);

  // Global gate for remote/backend mutations and producer-side node behavior.
  // Defaults to normal behavior; pass `--dart-define=VIEW_ONLY=true`
  // to disable writes and block production.
  static const bool viewOnly = bool.fromEnvironment(
    'VIEW_ONLY',
    defaultValue: false,
  );

  // URL used by the dApps tab when the user toggles it into "external
  // hub" mode by long-pressing the bottom-nav Dapps icon. The toggle is
  // off by default (so the tab opens to the original list of dapps);
  // long-press flips it on and the dapps tab re-renders as a single
  // full-bleed WebView pointing at this URL. The page still receives
  // the native Usernode JS bridge (sendTransaction, signMessage,
  // txObserved) and tx-confirmation chrome, so any dapp hub hosted
  // here behaves like a native-installed dapp.
  //
  // Set to an empty string to disable the toggle entirely (long-press
  // becomes a no-op).
  //
  // Example:
  //   flutter run --dart-define=DAPPS_TAB_URL=https://some.other.hub/
  static const String dappsTabUrl = String.fromEnvironment(
    'DAPPS_TAB_URL',
    defaultValue: 'https://social-vibecoding.usernodelabs.org/',
  );

  /// Explicit opt-in for privileged bridge access from loopback development
  /// origins. The WebView policy additionally requires a debug build, so this
  /// define cannot grant loopback privileges in a release artifact.
  static const bool enableLocalPrivilegedBridge = bool.fromEnvironment(
    'ENABLE_LOCAL_PRIVILEGED_BRIDGE',
    defaultValue: false,
  );

  // Optional display name shown in the AppBar when [dappsTabUrl] is set.
  // Falls back to the URL host when empty.
  static const String dappsTabName = String.fromEnvironment(
    'DAPPS_TAB_NAME',
    defaultValue: '',
  );

  // Observability hub intake base URL for node startup.
  // Leave empty to disable HTTP observability export from the mobile node.
  static const String observabilityHubBaseUrl = String.fromEnvironment(
    'OBSERVABILITY_HUB_BASE_URL',
    defaultValue: '',
  );

  // zkPassport session server (bridge) base URL.
  static const String zkPassportBridgeBaseUrl = String.fromEnvironment(
    'ZKPASSPORT_BRIDGE_BASE_URL',
    defaultValue: 'https://zkbridge.usernodelabs.org',
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
  // Node prover configuration
  static const bool enableRealProver =
      bool.fromEnvironment('ENABLE_REAL_PROVER', defaultValue: false);

  // Block Production configuration (all in seconds)
  // Headless produced-blocks refresh cadence: in background mode we keep
  // producedBlocksSummaryProvider warm on this interval without any UI. (Was
  // previously shared with the now-removed topochain metrics collector.)
  static const int headlessRefreshIntervalSeconds = int.fromEnvironment(
      'HEADLESS_REFRESH_INTERVAL_SECONDS',
      defaultValue: 30);
  static const int blockProductionWakeBeforeSlotSeconds = int.fromEnvironment(
      'BLOCK_PRODUCTION_WAKE_BEFORE_SLOT_SECONDS',
      defaultValue: 60);
  static const int epochMonitorBaseIntervalSeconds = int.fromEnvironment(
      'EPOCH_MONITOR_BASE_INTERVAL_SECONDS',
      defaultValue: 900);

  // Convert to Duration for convenience
  static Duration get headlessRefreshInterval =>
      const Duration(seconds: headlessRefreshIntervalSeconds);
  static Duration get blockProductionWakeBeforeSlot =>
      const Duration(seconds: blockProductionWakeBeforeSlotSeconds);
  static Duration get epochMonitorBaseInterval =>
      const Duration(seconds: epochMonitorBaseIntervalSeconds);

  // Version check configuration
  // If empty, version checking is disabled. Default is the SV platform's
  // public v4 endpoint (same POST body and {success, data} envelope as the
  // old topochain endpoint).
  static const String versionCheckApiUrl = String.fromEnvironment(
    'VERSION_CHECK_API_URL',
    defaultValue:
        'https://social-vibecoding.usernodelabs.org/api/v4/app-version/check',
  );
  static const int versionCheckIntervalSeconds =
      int.fromEnvironment('VERSION_CHECK_INTERVAL_SECONDS', defaultValue: 7200);

  static Duration get versionCheckInterval =>
      const Duration(seconds: versionCheckIntervalSeconds);
  static bool get versionCheckEnabled => versionCheckApiUrl.isNotEmpty;

  /// Host portion of [versionCheckApiUrl] for redacted logging.
  /// Returns `<unset>` if empty, `<unparsed>` if malformed.
  static String get versionCheckHost {
    if (versionCheckApiUrl.isEmpty) return '<unset>';
    return Uri.tryParse(versionCheckApiUrl)?.host ?? '<unparsed>';
  }

  // Leaderboard API v2
  static const int leaderboardApiTimeoutSeconds = int.fromEnvironment(
    'LEADERBOARD_API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
  static Duration get leaderboardApiTimeout =>
      const Duration(seconds: leaderboardApiTimeoutSeconds);

  static const String leaderboardApiBaseUrl = String.fromEnvironment(
    'LEADERBOARD_API_BASE_URL',
    defaultValue: 'https://leaderboard.usernodelabs.org/api/v2/mobile',
  );

  // Challenge point tracker configuration
  static const int challengePointMaxAgeHours = int.fromEnvironment(
    'CHALLENGE_POINT_MAX_AGE_HOURS',
    defaultValue: 48,
  );
  static const int challengePointDiffWindowHours = int.fromEnvironment(
    'CHALLENGE_POINT_DIFF_WINDOW_HOURS',
    defaultValue: 24,
  );
  static Duration get challengePointMaxAge =>
      const Duration(hours: challengePointMaxAgeHours);
  static Duration get challengePointDiffWindow =>
      const Duration(hours: challengePointDiffWindowHours);

  // Explorer API configuration. Both default to the same canonical
  // testnet explorer host; the primary/secondary split is a fallback
  // mechanism for ops to point one at a backup if/when one exists. The
  // legacy alpha1/alpha2.usernodelabs.org hosts have been retired (502
  // / 503); the path prefix moved from /explorer/api to /api in the same
  // migration.
  static const String primaryExplorerUrl = String.fromEnvironment(
    'EXPLORER_PRIMARY_URL',
    defaultValue: 'https://testnet-explorer.usernodelabs.org/api',
  );
  static const String secondaryExplorerUrl = String.fromEnvironment(
    'EXPLORER_SECONDARY_URL',
    defaultValue: 'https://testnet-explorer.usernodelabs.org/api',
  );
  static const int explorerTimeoutSeconds = int.fromEnvironment(
    'EXPLORER_TIMEOUT_SECONDS',
    defaultValue: 5,
  );
  static const int explorerCacheTtlMinutes = int.fromEnvironment(
    'EXPLORER_CACHE_TTL_MINUTES',
    defaultValue: 5,
  );

  // Convert to Duration for convenience
  static Duration get explorerTimeout =>
      const Duration(seconds: explorerTimeoutSeconds);
  static Duration get explorerCacheTtl =>
      const Duration(minutes: explorerCacheTtlMinutes);

  // === Community ===
  static const String discordInviteUrl =
      'https://discord.com/channels/1427970105521737760/1447595610877460591';

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

  static int? _parseOptionalInt(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
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
