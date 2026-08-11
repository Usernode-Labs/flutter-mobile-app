import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold-boot eligibility is read after backend initialization', () async {
    final source = await File(
      'lib/core/bootstrap/app_bootstrap.dart',
    ).readAsString();
    final backendBootstrap = source.substring(
      source.indexOf('static Future<void> _bootstrapBackendAsync'),
      source.indexOf('static Future<void> _runStartupAlarmAudit'),
    );

    expect(
      source.substring(
        source.indexOf('final backendBootstrap = _bootstrapBackendAsync'),
        source.indexOf('return AppBootstrapResult'),
      ),
      isNot(contains('producerEligible:')),
    );
    expect(backendBootstrap, isNot(contains('required bool producerEligible')));
    final rustInitialization = backendBootstrap.indexOf(
      'await RustBackendService.instance.init()',
    );
    final existingRuntimeReporting = backendBootstrap.indexOf(
      'await ObservabilityReportingService.instance.reportNodeInitialized',
    );
    final identityRead = backendBootstrap.indexOf(
      'final currentIdentity = container.read(identityProvider)',
    );
    expect(rustInitialization, greaterThanOrEqualTo(0));
    expect(existingRuntimeReporting, greaterThanOrEqualTo(0));
    expect(identityRead, greaterThan(rustInitialization));
    expect(identityRead, greaterThan(existingRuntimeReporting));
    expect(backendBootstrap, contains('hasAccount: producerEligible'));
  });
}
