import 'package:crypto_mobile_app/features/activity/data/models/activity_models.dart';
import 'package:crypto_mobile_app/features/activity/data/models/activity_errors.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_api_client.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_session_store.dart';
import 'package:crypto_mobile_app/features/activity/domain/activity_assertion_provider.dart';

class ActivityRepository {
  ActivityRepository({
    required ActivityApiClient apiClient,
    required ActivitySessionStore sessionStore,
  })  : _apiClient = apiClient,
        _sessionStore = sessionStore;

  final ActivityApiClient _apiClient;
  final ActivitySessionStore _sessionStore;

  ActivitySession? _session;
  int _sessionGeneration = 0;

  Future<bool> restoreSession() async {
    final generation = _sessionGeneration;
    final restored = await _sessionStore.load();
    if (generation != _sessionGeneration) return _session != null;
    _replaceSession(restored);
    return restored != null;
  }

  Future<ActivitySession> establishSession(
    ActivityAssertionProvider assertionProvider,
  ) async {
    // Each call acquires a fresh assertion. The API client never retries an
    // ambiguous exchange because the one-time assertion may have been used.
    final assertion = await assertionProvider.acquireAssertion();
    final session = await _apiClient.exchangeAssertion(assertion);
    await _sessionStore.save(session);
    _replaceSession(session);
    return session;
  }

  Future<ActivityFeedPage> getFeed({
    String? before,
    int limit = 100,
  }) {
    return _withSession(
      (token) => _apiClient.getFeed(
        accessToken: token,
        before: before,
        limit: limit,
      ),
    );
  }

  Future<ActivitySyncPage> sync({
    String? after,
    int limit = 100,
  }) {
    return _withSession(
      (token) => _apiClient.sync(
        accessToken: token,
        after: after,
        limit: limit,
      ),
    );
  }

  Future<void> markRead(String inboxSequence) {
    return _withSession(
      (token) => _apiClient.markRead(
        accessToken: token,
        inboxSequence: inboxSequence,
      ),
    );
  }

  Future<ActivityUnreadCount> getUnreadCount() {
    return _withSession(
      (token) => _apiClient.getUnreadCount(accessToken: token),
    );
  }

  Future<void> clearSession() async {
    _replaceSession(null);
    await _sessionStore.clear();
  }

  Future<T> _withSession<T>(
    Future<T> Function(String accessToken) operation,
  ) async {
    var session = _session;
    if (session == null) {
      final generation = _sessionGeneration;
      final restored = await _sessionStore.load();
      if (generation == _sessionGeneration) {
        _replaceSession(restored);
        session = restored;
      } else {
        session = _session;
      }
    }
    if (session == null) {
      await clearSession();
      throw const ActivitySessionRequiredException();
    }

    final generation = _sessionGeneration;
    try {
      final result = await operation(session.accessToken);
      if (generation != _sessionGeneration || !identical(session, _session)) {
        throw const ActivitySessionChangedException();
      }
      return result;
    } on ActivityApiException catch (error) {
      if (error.statusCode == 401 &&
          error.code == ActivityApiErrorCode.unauthorizedConsumer) {
        if (generation != _sessionGeneration || !identical(session, _session)) {
          throw const ActivitySessionChangedException();
        }
        await clearSession();
      }
      rethrow;
    }
  }

  void _replaceSession(ActivitySession? session) {
    _session = session;
    _sessionGeneration++;
  }
}
