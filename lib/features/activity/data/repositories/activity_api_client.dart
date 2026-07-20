import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';

final _consumerTokenPattern = RegExp(r'^act1_[A-Za-z0-9_-]{43}$');

class ActivityApiClient {
  ActivityApiClient({
    required String baseUrl,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
    bool? writesEnabled,
  })  : baseUrl = normalizeBaseUrl(baseUrl),
        _http = httpClient ?? http.Client(),
        _timeout = timeout,
        _writesEnabled = writesEnabled ?? !AppConfig.viewOnly;

  /// This client deliberately uses a plain client instead of the app's HTTP
  /// debug recorder. Exchange bodies contain credentials, and Activity feed
  /// bodies contain private account data.
  final http.Client _http;
  final Duration _timeout;
  final bool _writesEnabled;
  final String baseUrl;

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme == 'http' && !_isLocalDevelopmentHost(uri.host))) {
      throw ArgumentError.value(value, 'baseUrl', 'Invalid Activity API URL');
    }
    return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
  }

  Future<ActivitySession> exchangeAssertion(String assertion) async {
    _requireWritesEnabled();
    if (assertion.isEmpty) {
      throw ArgumentError.value(assertion, 'assertion', 'Must not be empty');
    }
    final response = await _http
        .post(
          _uri('/v1/auth/exchanges'),
          headers: const {
            'accept': 'application/json',
            'content-type': 'application/json',
          },
          body: jsonEncode({'assertion': assertion}),
        )
        .timeout(_timeout);
    _requireStatus(response, 200);
    _requirePrivateNoStore(response);
    return _decode(
      response,
      ActivitySession.fromJson,
      description: 'authentication exchange',
    );
  }

  Future<ActivityFeedPage> getFeed({
    required String accessToken,
    String? before,
    int limit = 100,
  }) async {
    _validateLimit(limit);
    final response = await _http
        .get(
          _uri(
            '/v1/me/activity',
            query: {
              if (before != null) 'before': before,
              'limit': '$limit',
            },
          ),
          headers: _consumerHeaders(accessToken),
        )
        .timeout(_timeout);
    _requireStatus(response, 200, consumerEndpoint: true);
    _requirePrivateNoStore(response);
    return _decode(
      response,
      ActivityFeedPage.fromJson,
      description: 'activity feed',
    );
  }

  Future<ActivitySyncPage> sync({
    required String accessToken,
    String? after,
    int limit = 100,
  }) async {
    _validateLimit(limit);
    final response = await _http
        .get(
          _uri(
            '/v1/me/activity/sync',
            query: {
              if (after != null) 'after': after,
              'limit': '$limit',
            },
          ),
          headers: _consumerHeaders(accessToken),
        )
        .timeout(_timeout);
    _requireStatus(response, 200, consumerEndpoint: true);
    _requirePrivateNoStore(response);
    return _decode(
      response,
      ActivitySyncPage.fromJson,
      description: 'activity synchronization',
    );
  }

  Future<void> markRead({
    required String accessToken,
    required String inboxSequence,
  }) async {
    _requireWritesEnabled();
    // Reuse the authoritative sequence decoder before placing the value on
    // the wire. This keeps numbers as strings and rejects leading zeros.
    requiredActivitySequence(
      {'inboxSequence': inboxSequence},
      'inboxSequence',
    );
    final response = await _http
        .post(
          _uri('/v1/me/activity/read'),
          headers: {
            ..._consumerHeaders(accessToken),
            'content-type': 'application/json',
          },
          body: jsonEncode({'inboxSequence': inboxSequence}),
        )
        .timeout(_timeout);
    _requireStatus(response, 204, consumerEndpoint: true);
    if (response.bodyBytes.isNotEmpty) {
      throw const ActivityProtocolException(
        'Activity read response must not contain a body',
      );
    }
  }

  Future<ActivityUnreadCount> getUnreadCount({
    required String accessToken,
  }) async {
    final response = await _http
        .get(
          _uri('/v1/me/unread-count'),
          headers: _consumerHeaders(accessToken),
        )
        .timeout(_timeout);
    _requireStatus(response, 200, consumerEndpoint: true);
    _requirePrivateNoStore(response);
    return _decode(
      response,
      ActivityUnreadCount.fromJson,
      description: 'activity unread count',
    );
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _consumerHeaders(String accessToken) {
    if (!_consumerTokenPattern.hasMatch(accessToken)) {
      throw const ActivityProtocolException('Invalid stored consumer token');
    }
    return {
      'accept': 'application/json',
      'authorization': 'Bearer $accessToken',
    };
  }

  T _decode<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parser, {
    required String description,
  }) {
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return parser(value);
    } catch (error) {
      if (error is ActivityProtocolException) rethrow;
      throw ActivityProtocolException(
        'Invalid $description response',
        error,
      );
    }
  }

  void _requireStatus(
    http.Response response,
    int expected, {
    bool consumerEndpoint = false,
  }) {
    if (response.statusCode == expected) return;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected an API error object');
      }
      expectActivityJsonKeys(decoded, const {'error'});
      final rawCode = requiredActivityString(decoded, 'error');
      final code = ActivityApiErrorCode.tryParse(rawCode);
      if (code == null) throw const FormatException('Unknown API error code');
      final isUnauthorized = code == ActivityApiErrorCode.unauthorizedConsumer;
      if ((response.statusCode == 401) !=
          (consumerEndpoint && isUnauthorized)) {
        throw const FormatException('Invalid API error status and code');
      }
      throw ActivityApiException(
        statusCode: response.statusCode,
        code: code,
      );
    } on ActivityApiException {
      rethrow;
    } catch (error) {
      throw ActivityProtocolException('Invalid Activity API error', error);
    }
  }

  void _requirePrivateNoStore(http.Response response) {
    if (response.headers['cache-control'] != 'private, no-store') {
      throw const ActivityProtocolException(
        'Activity response must be private and non-cacheable',
      );
    }
  }

  void _requireWritesEnabled() {
    if (!_writesEnabled) throw const ActivityWriteDisabledException();
  }

  void _validateLimit(int limit) {
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }
  }

  void dispose() => _http.close();
}

bool _isLocalDevelopmentHost(String host) {
  return host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '::1' ||
      host == '10.0.2.2' ||
      host == '10.0.3.2';
}
