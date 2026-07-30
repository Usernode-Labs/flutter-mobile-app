import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:ds_lints/src/lint_visitor.dart';

List<String> _rulesFor(
  String source, {
  String filePath = 'lib/features/example.dart',
}) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = DsLintVisitor(filePath: filePath);
  result.unit.visitChildren(visitor);
  return visitor.findings.map((finding) => finding.ruleName).toList();
}

const _source = '''
void f() {
  NetworkPrefs.setActiveBucket(null, guest: true);
}
''';

void main() {
  // Any file outside the allowlist is a violation.
  final outside = _rulesFor(_source);
  if (!outside.contains('single_identity_bucket_writer')) {
    throw StateError(
        'Expected single_identity_bucket_writer outside the controller; '
        'got $outside');
  }

  // The SessionController (the single writer) is exempt.
  final controller = _rulesFor(
    _source,
    filePath: 'lib/core/identity/session_controller.dart',
  );
  if (controller.contains('single_identity_bucket_writer')) {
    throw StateError('SessionController should be exempt.');
  }

  // The declaring file's own doc-comment references are exempt.
  final declaration = _rulesFor(
    _source,
    filePath: 'lib/core/utils/network_prefs.dart',
  );
  if (declaration.contains('single_identity_bucket_writer')) {
    throw StateError('network_prefs.dart should be exempt.');
  }

  print('single_identity_bucket_writer fixture passed');
}
