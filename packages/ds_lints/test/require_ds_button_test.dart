import 'fixture_harness.dart';

void _expectRequireDsButton(String constructor) {
  final rules = lintRulesFor('''
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

  final dsButtonRules = lintRulesFor(
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
