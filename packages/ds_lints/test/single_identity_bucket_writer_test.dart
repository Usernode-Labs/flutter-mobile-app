import 'fixture_harness.dart';

const _source = '''
void f() {
  NetworkPrefs.setActiveBucket(null, guest: true);
}
''';

void main() {
  // Any file outside the allowlist is a violation.
  final outside = lintRulesFor(_source);
  if (!outside.contains('single_identity_bucket_writer')) {
    throw StateError(
        'Expected single_identity_bucket_writer outside the controller; '
        'got $outside');
  }

  // The SessionController (the single writer) is exempt.
  final controller = lintRulesFor(
    _source,
    filePath: 'lib/core/identity/session_controller.dart',
  );
  if (controller.contains('single_identity_bucket_writer')) {
    throw StateError('SessionController should be exempt.');
  }

  // The declaring file's own doc-comment references are exempt.
  final declaration = lintRulesFor(
    _source,
    filePath: 'lib/core/utils/network_prefs.dart',
  );
  if (declaration.contains('single_identity_bucket_writer')) {
    throw StateError('network_prefs.dart should be exempt.');
  }

  print('single_identity_bucket_writer fixture passed');
}
