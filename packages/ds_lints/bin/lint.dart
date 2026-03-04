import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'package:ds_lints/src/lint_visitor.dart';
import 'package:ds_lints/src/utils.dart';

void main(List<String> args) {
  // Usage:
  //   dart run bin/lint.dart <rootDir>           — scan all lib/ files
  //   dart run bin/lint.dart --file <filePath>   — scan a single file (fast)
  if (args.length >= 2 && args[0] == '--file') {
    _lintSingleFile(args[1]);
  } else {
    _lintAll(args.isNotEmpty ? args[0] : '.');
  }
}

/// Lint a single file. Used by PostToolUse hooks for fast feedback.
void _lintSingleFile(String filePath) {
  final absPath = p.canonicalize(filePath);
  if (!File(absPath).existsSync()) return;
  if (isExcludedPath(absPath)) return;

  final result = parseFile(
    path: absPath,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );

  final visitor = DsLintVisitor(filePath: filePath);
  result.unit.visitChildren(visitor);

  for (final finding in visitor.findings) {
    final severity = finding.severity == 'WARNING' ? 'warning' : 'info';
    stdout.writeln(
      '  $severity - ${finding.filePath}:${finding.line}:${finding.column} - '
      '${finding.message} - ${finding.ruleName}',
    );
  }

  if (visitor.findings.any((f) => f.severity == 'WARNING')) {
    exit(1);
  }
}

/// Lint all Dart files under lib/.
void _lintAll(String rootDir) {
  final absRoot = p.canonicalize(rootDir);

  // Scan lib/ for Dart files, excluding widgetbook/ and test/.
  final dartFiles = Glob('lib/**.dart').listSync(root: absRoot);

  final allFindings = <LintFinding>[];
  var filesScanned = 0;

  for (final entity in dartFiles) {
    if (entity is! File) continue;
    final filePath = entity.path;

    if (isExcludedPath(filePath)) continue;

    filesScanned++;

    final result = parseFile(
      path: filePath,
      featureSet: FeatureSet.latestLanguageVersion(),
      throwIfDiagnostics: false,
    );

    final visitor =
        DsLintVisitor(filePath: p.relative(filePath, from: absRoot));
    result.unit.visitChildren(visitor);
    allFindings.addAll(visitor.findings);
  }

  // Print results.
  if (allFindings.isEmpty) {
    stdout.writeln('No design system lint violations found '
        '($filesScanned files scanned).');
    return;
  }

  // Group by severity for summary.
  final warnings = allFindings.where((f) => f.severity == 'WARNING').toList();
  final infos = allFindings.where((f) => f.severity == 'INFO').toList();

  // Sort by file, then line.
  allFindings.sort((a, b) {
    final cmp = a.filePath.compareTo(b.filePath);
    return cmp != 0 ? cmp : a.line.compareTo(b.line);
  });

  for (final finding in allFindings) {
    final severity = finding.severity == 'WARNING' ? 'warning' : 'info';
    stdout.writeln(
      '  $severity - ${finding.filePath}:${finding.line}:${finding.column} - '
      '${finding.message} - ${finding.ruleName}',
    );
  }

  stdout.writeln('');
  stdout.writeln('${allFindings.length} issues found '
      '(${warnings.length} warnings, ${infos.length} info) '
      'in $filesScanned files.');

  // Exit with error code if any warnings.
  if (warnings.isNotEmpty) {
    exit(1);
  }
}
