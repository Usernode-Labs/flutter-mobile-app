import 'package:crypto_mobile_app/core/session/session_operation_runner.dart';

abstract class MobileContextSnapshotCollector {
  Future<Map<String, dynamic>> collectStaticMobileContextSnapshot({
    required SessionIdentityProjection identity,
    Map<String, dynamic>? eventData,
  });

  Future<Map<String, dynamic>> collectRuntimeMobileContextSnapshot({
    required SessionIdentityProjection identity,
    Map<String, dynamic>? eventData,
  });

  Future<Map<String, dynamic>> collectPowerNetworkServiceContextSnapshot({
    required SessionIdentityProjection identity,
    Map<String, dynamic>? eventData,
  });
}
