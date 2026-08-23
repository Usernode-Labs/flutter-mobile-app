import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production credential leases are constructed only by the gateway', () {
    final identity = File(
      'lib/core/identity/identity.dart',
    ).readAsStringSync();
    final gateway = File(
      'lib/core/identity/session_authority_gateway.dart',
    ).readAsStringSync();

    expect(identity, isNot(contains('class AuthCredentialLease')));
    expect(gateway, contains('class AuthCredentialLease'));
    expect(gateway, contains('AuthCredentialLease._('));

    final directConstruction = RegExp(r'AuthCredentialLease\s*\(');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('session_authority_gateway.dart')) continue;
      if (directConstruction.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty);
  });
}
