import 'dart:convert';
import 'package:crypto_mobile_app/core/utils/logger.dart';
import 'package:crypto_mobile_app/core/utils/log_tag.dart';
import 'package:crypto_mobile_app/features/metrics/data/models/metrics_payload.dart';
import 'package:http/http.dart' as http;

final _log = LoggingService.instance.withTag(LogTag.metrics);

/// Repository for sending metrics to the centralized API
class MetricsRepository {
  MetricsRepository({
    required String apiMetricsEndpoint,
    String? apiHealthEndpoint,
    http.Client? httpClient,
  })  : _apiMetricsEndpoint = apiMetricsEndpoint,
        _apiHealthEndpoint = apiHealthEndpoint,
        _httpClient = httpClient ?? http.Client();

  final String _apiMetricsEndpoint;
  final String? _apiHealthEndpoint;
  final http.Client _httpClient;

  /// Send metrics payload to the centralized API
  ///
  /// Returns true if metrics were sent successfully, false otherwise
  /// Failed metrics are logged and dropped (no retry logic)
  Future<bool> sendMetrics(MetricsPayload payload) async {
    try {
      final url = Uri.parse(_apiMetricsEndpoint);

      final jsonPayload = payload.toJson();

      _log.trace(
        'Sending metrics to API',
        context: {
          'url': url.toString(),
          'peer_id': payload.node.identity.peerId,
          'node_state': payload.node.status?.nodeState ?? 'unknown',
        },
      );

      final response = await _httpClient
          .post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(jsonPayload),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Metrics request timed out');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _log.trace(
          'Metrics sent successfully',
          context: {'status_code': response.statusCode},
        );
        return true;
      } else {
        _log.warn(
          'Failed to send metrics',
          context: {
            'status_code': response.statusCode,
            'response_body': response.body,
          },
        );
        // Drop failed metrics (per user requirement)
        return false;
      }
    } catch (e) {
      // Log at debug level - network failures are expected and non-critical
      _log.debug('Metrics send failed: $e');
      return false;
    }
  }

  /// Test the API connection using health check endpoint
  ///
  /// Returns true if the health endpoint is reachable and returns healthy status
  /// If no health endpoint is configured, returns true (skip check)
  Future<bool> testConnection() async {
    // Skip health check if no endpoint configured
    if (_apiHealthEndpoint == null || _apiHealthEndpoint.isEmpty) {
      return true;
    }

    try {
      final url = Uri.parse(_apiHealthEndpoint);

      final response = await _httpClient.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Health check request timed out');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Optionally parse and validate response
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['status'] == 'healthy') {
            return true;
          }
        } catch (_) {
          // If parsing fails, just check status code
          return true;
        }
      }

      return false;
    } catch (e) {
      _log.warn(
        'API connection test failed: $e',
      );
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    _httpClient.close();
  }
}
