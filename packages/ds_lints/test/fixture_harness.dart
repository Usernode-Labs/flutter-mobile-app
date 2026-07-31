import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:ds_lints/src/lint_visitor.dart';

List<String> lintRulesFor(
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
