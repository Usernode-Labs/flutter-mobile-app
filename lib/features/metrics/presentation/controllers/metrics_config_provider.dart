import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'metrics_config_provider.freezed.dart';

/// Configuration for metrics collection and reporting
/// Loaded from compile-time environment variables
@freezed
class MetricsConfig with _$MetricsConfig {
  const factory MetricsConfig({
    /// Whether metrics collection is enabled
    required bool enabled,

    /// Direct metrics endpoint URL (e.g., https://api.example.com/v1/metrics)
    required String apiMetricsEndpoint,

    /// Reporting interval in seconds
    required int intervalSeconds,
  }) = _MetricsConfig;

  const MetricsConfig._();

  /// Whether the configuration is valid for sending metrics
  bool get isValid => enabled && apiMetricsEndpoint.isNotEmpty;

  /// Duration for the reporting interval
  Duration get intervalDuration => Duration(seconds: intervalSeconds);
}

/// Provider for metrics configuration (reads from compile-time constants)
final metricsConfigProvider = Provider<MetricsConfig>((ref) {
  return MetricsConfig(
    enabled: AppConfig.metricsEnabled,
    apiMetricsEndpoint: AppConfig.metricsEndpoint,
    intervalSeconds: AppConfig.metricsInterval.clamp(1, 3600),
  );
});
