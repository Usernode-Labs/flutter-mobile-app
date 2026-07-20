import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crypto_mobile_app/core/config/app_config.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_api_client.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_repository.dart';
import 'package:crypto_mobile_app/features/activity/data/repositories/activity_session_store.dart';

final activityApiBaseUrlProvider = Provider<String>(
  (ref) => AppConfig.activityApiBaseUrl.trim(),
);

final activityConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(activityApiBaseUrlProvider).isNotEmpty,
);

final activityWritesEnabledProvider = Provider<bool>(
  (ref) => !AppConfig.viewOnly,
);

final activityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final activityApiClientProvider = Provider<ActivityApiClient?>((ref) {
  final baseUrl = ref.watch(activityApiBaseUrlProvider);
  if (baseUrl.isEmpty) return null;

  final client = ActivityApiClient(
    baseUrl: baseUrl,
    writesEnabled: ref.watch(activityWritesEnabledProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});

final activitySessionStoreProvider = Provider<ActivitySessionStore?>((ref) {
  final baseUrl = ref.watch(activityApiBaseUrlProvider);
  if (baseUrl.isEmpty) return null;
  return ActivitySessionStore(
    baseUrl: baseUrl,
  );
});

final activityRepositoryProvider = Provider<ActivityRepository?>((ref) {
  final client = ref.watch(activityApiClientProvider);
  final store = ref.watch(activitySessionStoreProvider);
  if (client == null || store == null) return null;
  return ActivityRepository(
    apiClient: client,
    sessionStore: store,
  );
});
