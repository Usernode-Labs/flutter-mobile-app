import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'utils.dart';

/// AST visitor that collects all design system lint violations.
///
/// Handles both `InstanceCreationExpression` (const/new prefixed) and
/// `MethodInvocation` (unprefixed constructor calls), since `parseFile()`
/// does syntactic-only parsing and treats unprefixed constructors as
/// method invocations.
class DsLintVisitor extends RecursiveAstVisitor<void> {
  DsLintVisitor({required this.filePath});

  final String filePath;
  final List<LintFinding> findings = [];

  // ── FRB import patterns ────────────────────────────────────────────────

  static const _frbImportPatterns = [
    'flutter_rust_bridge',
    'frb_generated',
  ];

  // ── Entry points ──────────────────────────────────────────────────────

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final typeName = node.constructorName.type.name2.lexeme;
    final constructorName = node.constructorName.name?.name;
    _dispatch(node, typeName, constructorName, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;
    String? typeName;
    String? constructorName;

    if (target is SimpleIdentifier) {
      // Named constructor: EdgeInsets.all(16), BorderRadius.circular(12)
      typeName = target.name;
      constructorName = node.methodName.name;
    } else if (target == null) {
      // Default constructor: SizedBox(height: 16), Icon(Icons.star)
      final name = node.methodName.name;
      if (_defaultConstructorTypes.contains(name)) {
        typeName = name;
        constructorName = null;
      }
    }

    if (typeName != null) {
      _dispatch(node, typeName, constructorName, node.argumentList);
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    if (!filePath.contains('design_system')) {
      super.visitImportDirective(node);
      return;
    }
    final uri = node.uri.stringValue;
    if (uri != null) {
      for (final pattern in _frbImportPatterns) {
        if (uri.contains(pattern)) {
          _report(
            node,
            'avoid_frb_imports',
            'FRB import "$uri" in design system widget. '
                'FRB types transitively import native FFI, breaking '
                'Widgetbook web builds. Pass data via constructor params '
                'from lib/features/ instead.',
            'WARNING',
          );
          super.visitImportDirective(node);
          return;
        }
      }
    }
    super.visitImportDirective(node);
  }

  /// Types that use default (unnamed) constructors we care about.
  static const _defaultConstructorTypes = {'SizedBox', 'Icon'};

  void _dispatch(
    AstNode node,
    String typeName,
    String? constructorName,
    ArgumentList args,
  ) {
    switch (typeName) {
      case 'EdgeInsets':
        _checkEdgeInsets(node, typeName, constructorName, args);
        _checkMatryoshka(node, constructorName, args);
      case 'BorderRadius':
      case 'Radius':
        _checkBorderRadius(node, typeName, constructorName, args);
      case 'SizedBox':
        _checkSizedBoxSpacing(node, args);
      case 'Icon':
        _checkIconSize(node, args);
    }
  }

  // ── Rule 1: avoid_hardcoded_edge_insets ──────────────────────────────

  static const _edgeInsetsConstructors = {
    'EdgeInsets.all',
    'EdgeInsets.only',
    'EdgeInsets.symmetric',
    'EdgeInsets.fromLTRB',
  };

  void _checkEdgeInsets(
    AstNode node,
    String typeName,
    String? constructorName,
    ArgumentList args,
  ) {
    final fullName =
        constructorName != null ? '$typeName.$constructorName' : typeName;
    if (!_edgeInsetsConstructors.contains(fullName)) return;

    for (final arg in args.arguments) {
      final valueExpr = arg is NamedExpression ? arg.expression : arg;
      final value = numericLiteralValue(valueExpr);
      if (value != null && value != 0) {
        final token = spacingTokens[value];
        final msg = token != null
            ? 'Use spacing.$token (${value.toInt()}dp) instead of '
                'hardcoded EdgeInsets value.'
            : 'Hardcoded EdgeInsets value ${value.toInt()}. '
                'No matching AppSpacing token — consider adding one '
                'or verify this is intentional.';
        _report(node, 'avoid_hardcoded_edge_insets', msg, 'WARNING');
        return;
      }
    }
  }

  // ── Rule 2: avoid_hardcoded_border_radius ────────────────────────────

  static const _borderRadiusTargets = {
    'BorderRadius.circular',
    'BorderRadius.all',
    'BorderRadius.only',
    'BorderRadius.vertical',
    'BorderRadius.horizontal',
    'Radius.circular',
  };

  void _checkBorderRadius(
    AstNode node,
    String typeName,
    String? constructorName,
    ArgumentList args,
  ) {
    final fullName =
        constructorName != null ? '$typeName.$constructorName' : typeName;
    if (!_borderRadiusTargets.contains(fullName)) return;

    for (final arg in args.arguments) {
      final valueExpr = arg is NamedExpression ? arg.expression : arg;

      // Recurse into nested Radius.circular() — could be either node type.
      if (_isRadiusExpression(valueExpr)) {
        final innerArgs = _argumentsOf(valueExpr);
        if (innerArgs != null) {
          for (final innerArg in innerArgs) {
            final inner =
                innerArg is NamedExpression ? innerArg.expression : innerArg;
            final value = numericLiteralValue(inner);
            if (value != null && value != 0) {
              _report(
                node,
                'avoid_hardcoded_border_radius',
                _borderRadiusMessage(value),
                'WARNING',
              );
              return;
            }
          }
        }
        continue;
      }

      final value = numericLiteralValue(valueExpr);
      if (value != null && value != 0) {
        _report(
          node,
          'avoid_hardcoded_border_radius',
          _borderRadiusMessage(value),
          'WARNING',
        );
        return;
      }
    }
  }

  String _borderRadiusMessage(double value) {
    final token = radiiTokens[value];
    return token != null
        ? 'Use radii.$token (${value.toInt()}dp) instead of '
            'hardcoded BorderRadius values.'
        : 'Hardcoded BorderRadius value ${value.toInt()}. '
            'No matching AppRadii token — consider adding one '
            'or verify this is intentional.';
  }

  /// Returns true if [expr] is a `Radius(...)` or `Radius.circular(...)` call.
  bool _isRadiusExpression(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return expr.constructorName.type.name2.lexeme == 'Radius';
    }
    if (expr is MethodInvocation) {
      final target = expr.target;
      if (target is SimpleIdentifier && target.name == 'Radius') return true;
      if (target == null && expr.methodName.name == 'Radius') return true;
    }
    return false;
  }

  /// Extracts the argument list from either node type.
  NodeList<Expression>? _argumentsOf(Expression expr) {
    if (expr is InstanceCreationExpression) {
      return expr.argumentList.arguments;
    }
    if (expr is MethodInvocation) {
      return expr.argumentList.arguments;
    }
    return null;
  }

  // ── Rule 3: avoid_hardcoded_sized_box_spacing ────────────────────────

  void _checkSizedBoxSpacing(AstNode node, ArgumentList args) {
    // Only flag childless SizedBox (spacers).
    final hasChild = args.arguments.any(
      (a) => a is NamedExpression && a.name.label.name == 'child',
    );
    if (hasChild) return;

    for (final arg in args.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      if (name != 'height' && name != 'width') continue;

      final value = numericLiteralValue(arg.expression);
      if (value != null && gridValues.contains(value)) {
        _report(
          node,
          'avoid_hardcoded_sized_box_spacing',
          'Use AppSpacing tokens or Column/Row spacing: parameter '
              'instead of hardcoded SizedBox spacers.',
          'INFO',
        );
        return;
      }
    }
  }

  // ── Rule 4: avoid_hardcoded_icon_size ────────────────────────────────

  void _checkIconSize(AstNode node, ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != 'size') continue;

      final value = numericLiteralValue(arg.expression);
      if (value != null) {
        final token = iconSizeTokens[value];
        final msg = token != null
            ? 'Use sizing.$token (${value.toInt()}dp) instead of '
                'hardcoded Icon size.'
            : 'Hardcoded Icon size ${value.toInt()}. '
                'Consider adding an AppSizing token or using an existing one.';
        _report(node, 'avoid_hardcoded_icon_size', msg, 'INFO');
        return;
      }
    }
  }

  // ── Rule 5: matryoshka_zone_violation ────────────────────────────────

  void _checkMatryoshka(
    AstNode node,
    String? constructorName,
    ArgumentList args,
  ) {
    for (final arg in args.arguments) {
      final Expression valueExpr;
      final String? paramName;

      if (arg is NamedExpression) {
        valueExpr = arg.expression;
        paramName = arg.name.label.name;
      } else {
        valueExpr = arg;
        paramName = null;
      }

      final token = spacingTokenName(valueExpr);
      if (token == null) continue;

      // Macro tokens (space32/space48) in EdgeInsets.
      if (macroTokens.contains(token)) {
        // Exception: macro tokens in vertical-only positions
        // (centering, scroll breathing room, section gaps).
        if (constructorName == 'only' &&
            (paramName == 'top' || paramName == 'bottom')) {
          continue;
        }
        if (constructorName == 'symmetric' && paramName == 'vertical') {
          continue;
        }
        // fromLTRB: index 1 = top, index 3 = bottom.
        if (constructorName == 'fromLTRB') {
          final index = args.arguments.indexOf(arg);
          if (index == 1 || index == 3) continue;
        }
        _report(
          node,
          'matryoshka_zone_violation',
          'Macro-tier token ($token) used as padding. '
              'Macro tokens belong in scroll padding or section gaps, '
              'not EdgeInsets padding.',
          'WARNING',
        );
        return;
      }

      // Section-gap token (space24) in horizontal positions.
      if (token == sectionGapToken) {
        if (_isHorizontalParam(
            paramName, constructorName, arg, args.arguments)) {
          _report(
            node,
            'matryoshka_section_gap_horizontal',
            'Section-gap token (space24) used in horizontal EdgeInsets. '
                'space24 is a vertical section gap — use space16 for '
                'horizontal margins.',
            'WARNING',
          );
          return;
        }
      }
    }
  }

  bool _isHorizontalParam(
    String? paramName,
    String? constructorName,
    Expression arg,
    NodeList<Expression> args,
  ) {
    // Only flag the purely-horizontal case.
    // `all()`, `only(left/right)`, and `fromLTRB` mix axes — space24 is
    // legitimate for K₂ keyline alignment and balanced padding.
    if (constructorName == 'symmetric') {
      return paramName == 'horizontal';
    }
    return false;
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  void _report(
    AstNode node,
    String ruleName,
    String message,
    String severity,
  ) {
    final unit = node.thisOrAncestorOfType<CompilationUnit>();
    final lineInfo = unit?.lineInfo;
    final offset = node.offset;

    int line = 0;
    int column = 0;
    if (lineInfo != null) {
      final location = lineInfo.getLocation(offset);
      line = location.lineNumber;
      column = location.columnNumber;
    }

    findings.add(LintFinding(
      filePath: filePath,
      line: line,
      column: column,
      ruleName: ruleName,
      message: message,
      severity: severity,
    ));
  }
}
