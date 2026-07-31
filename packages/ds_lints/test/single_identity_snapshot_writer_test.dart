import 'fixture_harness.dart';

const _source = '''
void replaceIdentity(Identity next) {
  IdentitySnapshots.publish(next);
}
''';

void main() {
  final outside = lintRulesFor(_source);
  if (!outside.contains('single_identity_snapshot_writer')) {
    throw StateError(
      'Expected single_identity_snapshot_writer outside the controller; '
      'got $outside',
    );
  }

  final prefixed = lintRulesFor('''
void replaceIdentity(Identity next) {
  identity.IdentitySnapshots.publish(next);
}
''');
  if (!prefixed.contains('single_identity_snapshot_writer')) {
    throw StateError('Expected prefixed IdentitySnapshots call to be caught.');
  }

  for (final allowedPath in [
    'lib/core/identity/session_controller.dart',
    'lib/core/identity/identity.dart',
  ]) {
    final rules = lintRulesFor(_source, filePath: allowedPath);
    if (rules.contains('single_identity_snapshot_writer')) {
      throw StateError('$allowedPath should be exempt.');
    }
  }

  print('single_identity_snapshot_writer fixture passed');
}
