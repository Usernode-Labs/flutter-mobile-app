import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:crypto_mobile_app/core/utils/logger.dart';

final _log = LoggingService.instance.withTag(LogTag.node);

/// Service for loading network configuration (seedlist, genesis) from URLs
/// with exponential backoff retry logic.
class NetworkConfigService {
  NetworkConfigService._();
  static final NetworkConfigService instance = NetworkConfigService._();

  http.Client? _httpClient;

  /// Fetch content from URL with exponential backoff retry.
  /// Retries indefinitely until success.
  ///
  /// [url] The URL to fetch from
  /// [resourceName] Human-readable name for logging (e.g., 'genesis', 'seedlist')
  /// [initialDelayMs] Initial retry delay in milliseconds (default: 1000)
  /// [maxDelayMs] Maximum retry delay in milliseconds (default: 30000)
  Future<String> fetchWithRetry({
    required String url,
    required String resourceName,
    int initialDelayMs = 1000,
    int maxDelayMs = 30000,
  }) async {
    _httpClient ??= http.Client();
    int delayMs = initialDelayMs;
    int retryCount = 0;

    while (true) {
      try {
        _log.trace(
          'Fetching $resourceName (attempt ${retryCount + 1})',
          context: {'url': url},
        );

        final response = await _httpClient!
            .get(
              Uri.parse(url),
              headers: {'Accept': 'application/json'},
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _log.info(
            '$resourceName fetched successfully',
            context: {'url': url, 'attempts': retryCount + 1},
          );
          return response.body;
        }

        throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      } catch (e) {
        retryCount++;
        _log.warn(
          'Failed to fetch $resourceName (attempt $retryCount): $e',
          context: {'url': url, 'nextDelayMs': delayMs},
        );

        await Future<void>.delayed(Duration(milliseconds: delayMs));

        // Exponential backoff with cap
        delayMs = (delayMs * 2).clamp(0, maxDelayMs);
      }
    }
  }

  void dispose() {
    _httpClient?.close();
    _httpClient = null;
  }
}
