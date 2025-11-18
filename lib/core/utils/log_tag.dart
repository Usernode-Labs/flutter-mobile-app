/// Type-safe logging tags to prevent typos and enable autocomplete.
///
/// Usage:
/// ```dart
/// LoggingService.instance.trace('Message', tag: LogTag.rust);
/// ```
///
/// Backward compatibility: String tags are still supported.
enum LogTag {
  /// Rust backend and FFI bridge operations
  rust('RUST'),

  /// Riverpod provider state management
  provider('PROVIDER'),

  /// Wallet operations (UTXOs, transactions, assets)
  wallet('WALLET'),

  /// Node sync status and blockchain operations
  sync('SYNC'),

  /// UI rendering and interactions
  ui('UI'),

  /// Navigation and routing
  navigation('NAVIGATION'),

  /// Onboarding flow
  onboarding('ONBOARDING'),

  /// User authentication and accounts
  auth('AUTH'),

  /// Notifications
  notifications('NOTIFICATIONS'),

  /// Rewards and epoch data
  rewards('REWARDS'),

  /// Node status and peers
  node('NODE'),

  /// Mempool operations
  mempool('MEMPOOL'),

  /// Blockchain data
  blockchain('BLOCKCHAIN'),

  /// UTXO management
  utxo('UTXO'),

  /// Transaction activity
  activity('ACTIVITY'),

  /// Asset management
  assets('ASSETS'),

  /// Network and RPC calls
  network('NETWORK'),

  /// Application lifecycle
  lifecycle('LIFECYCLE'),

  /// Backend lifecycle management
  backendLifecycle('BACKEND_LIFECYCLE'),

  /// Sentry and error tracking
  sentry('SENTRY'),

  /// Performance and timing
  performance('PERF'),

  /// Metrics collection and reporting
  metrics('METRICS'),

  /// General/uncategorized
  general('GENERAL');

  const LogTag(this.value);

  /// The string value of the tag for logging
  final String value;

  @override
  String toString() => value;
}
