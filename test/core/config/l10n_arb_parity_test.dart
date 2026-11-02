import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads the ARB files as plain JSON, so it needs no app code.
const _dir = 'lib/core/config/l10n';

/// The languages Homeroom ships, as the base ARB file's locale suffix.
const _languages = [
  'id',
  'es',
  'fr',
  'pt',
  'vi',
  'tr',
  'ru',
  'ar',
  'hi',
  'zh',
  'ja',
  'ko',
];

Map<String, String> _messages(String name) {
  final json = jsonDecode(
    File('$_dir/$name').readAsStringSync(),
  ) as Map<String, dynamic>;
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// The `{placeholder}` names a message uses, sorted.
List<String> _placeholders(String message) => (RegExp(r'\{(\w+)\}')
    .allMatches(message)
    .map((m) => m.group(1)!)
    .toSet()
    .toList()
  ..sort());

void main() {
  final english = _messages('app_en.arb');

  test('every language file exists', () {
    for (final lang in _languages) {
      expect(File('$_dir/app_$lang.arb').existsSync(), isTrue, reason: lang);
    }
  });

  for (final lang in _languages) {
    group('app_$lang.arb', () {
      late final Map<String, String> messages;
      setUpAll(() => messages = _messages('app_$lang.arb'));

      test('has every key of app_en.arb and no others', () {
        expect(
          english.keys.toSet().difference(messages.keys.toSet()),
          isEmpty,
          reason: 'keys missing from $lang',
        );
        expect(
          messages.keys.toSet().difference(english.keys.toSet()),
          isEmpty,
          reason: 'keys $lang has but app_en.arb does not',
        );
      });

      test('uses exactly the placeholders of app_en.arb', () {
        for (final key in english.keys) {
          final translated = messages[key];
          if (translated == null) continue; // reported by the test above
          expect(
            _placeholders(translated),
            _placeholders(english[key]!),
            reason: '$lang / $key',
          );
        }
      });

      test('has no empty message', () {
        for (final e in messages.entries) {
          expect(e.value.trim(), isNotEmpty, reason: '$lang / ${e.key}');
        }
      });
    });
  }
}
