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

void _expectRequireDsButton(String constructor) {
  final rules = _rulesFor('''
import 'package:flutter/material.dart';

Widget build() {
  return $constructor(onPressed: () {}, child: const Text('Action'));
}
''');

  if (!rules.contains('require_ds_button')) {
    throw StateError('Expected require_ds_button for $constructor; got $rules');
  }
}

void main() {
  for (final constructor in [
    'FilledButton',
    'FilledButton.icon',
    'FilledButton.tonal',
    'FilledButton.tonalIcon',
    'OutlinedButton',
    'OutlinedButton.icon',
    'TextButton',
    'TextButton.icon',
    'ElevatedButton',
    'ElevatedButton.icon',
  ]) {
    _expectRequireDsButton(constructor);
  }

  final dsButtonRules = _rulesFor(
    '''
import 'package:flutter/material.dart';

Widget build() => FilledButton(onPressed: () {}, child: const Text('Action'));
''',
    filePath: 'lib/design_system/src/button.dart',
  );

  if (dsButtonRules.contains('require_ds_button')) {
    throw StateError('DS Button implementation should be exempt.');
  }

  print('require_ds_button fixture passed');
}
