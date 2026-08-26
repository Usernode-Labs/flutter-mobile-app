import 'package:crypto_mobile_app/core/config/app_router.dart';
import 'package:crypto_mobile_app/features/dapps/dapp_webview_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted SV chrome can open the retained ZK identity detail route', () {
    expect(
      trustedNativeScreenRoutes['zkIdentity'],
      AppRoutes.zkIdentityDetail,
    );
    expect(zkIdentityFlowCapability, 'zkIdentityFlow');
  });

  test('native screen registry stays restricted to explicit targets', () {
    expect(trustedNativeScreenRoutes, {
      'diagnostics': AppRoutes.diagnostics,
      'benchmark': AppRoutes.deviceBenchmark,
      'httpLogs': AppRoutes.httpDebugLogs,
      'zkIdentity': AppRoutes.zkIdentityDetail,
    });
  });
}
