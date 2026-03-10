import 'package:analyzer/dart/ast/ast.dart';

/// Grid-aligned spacing values from AppSpacing tokens.
final Set<double> gridValues = {4, 8, 12, 16, 24, 32, 48};

/// Value → token name maps for actionable lint messages.
final Map<double, String> iconSizeTokens = {
  16: 'iconXSmall',
  20: 'iconSmall',
  24: 'iconRegular',
  28: 'iconLarge',
  32: 'iconXLarge',
  48: 'iconDisplay',
  64: 'iconDisplayLarge',
};

final Map<double, String> radiiTokens = {
  4: 'xSmall',
  8: 'small',
  12: 'medium',
  16: 'large',
  20: 'largeIncreased',
  24: 'xLarge',
  999: 'full',
};

final Map<double, String> spacingTokens = {
  4: 'space4',
  8: 'space8',
  12: 'space12',
  16: 'space16',
  24: 'space24',
  32: 'space32',
  48: 'space48',
};

/// Macro-tier tokens (space32, space48) — too large for padding.
const Set<String> macroTokens = {'space32', 'space48'};


/// Paths excluded from lint enforcement.
const List<String> excludedPathSegments = ['/widgetbook/', '/test/'];

/// Returns true if [path] should be excluded from lint checks.
bool isExcludedPath(String path) {
  for (final segment in excludedPathSegments) {
    if (path.contains(segment)) return true;
  }
  return false;
}

/// Extracts the numeric value from an [Expression] if it is a numeric literal.
/// Returns null for non-literal expressions.
double? numericLiteralValue(Expression expr) {
  if (expr is IntegerLiteral) return expr.value?.toDouble();
  if (expr is DoubleLiteral) return expr.value;
  return null;
}

/// Returns the token name from a property access like `spacing.space16`.
/// Handles both `PropertyAccess` (`a.b`) and `PrefixedIdentifier` (`a.b`).
String? spacingTokenName(Expression expr) {
  if (expr is PropertyAccess) {
    return expr.propertyName.name;
  }
  if (expr is PrefixedIdentifier) {
    return expr.identifier.name;
  }
  return null;
}

/// A lint finding reported by a rule.
class LintFinding {
  LintFinding({
    required this.filePath,
    required this.line,
    required this.column,
    required this.ruleName,
    required this.message,
    required this.severity,
  });

  final String filePath;
  final int line;
  final int column;
  final String ruleName;
  final String message;
  final String severity; // WARNING or INFO
}
