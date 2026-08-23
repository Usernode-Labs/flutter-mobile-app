import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('webview session/realm authority is opaque at production boundaries',
      () {
    final gateway = File(
      'lib/core/identity/session_authority_gateway.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/features/dapps/privileged_bridge_policy.dart',
    ).readAsStringSync();

    expect(gateway, contains('WebViewRealmLease._('));
    expect(gateway, isNot(contains('const WebViewRealmLease({')));
    expect(policy, contains('PrivilegedBridgeLease._('));
    expect(policy, isNot(contains('const PrivilegedBridgeLease({')));
  });
}
