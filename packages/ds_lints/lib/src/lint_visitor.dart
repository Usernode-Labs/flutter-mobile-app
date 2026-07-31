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
    final targetName = _invocationTargetName(node);
    final methodName = node.methodName.name;

    _checkIdentityBucketWriter(node, targetName, methodName);
    _checkIdentitySnapshotWriter(node, targetName, methodName);
    _checkWalletEffectGateway(node, targetName, methodName);
    _checkAmbientWalletAccountInvocation(node, targetName, methodName);

    String? typeName;
    String? constructorName;

    if (target is SimpleIdentifier) {
      // Named constructor: EdgeInsets.all(16), BorderRadius.circular(12)
      typeName = target.name;
      constructorName = methodName;
    } else if (target == null) {
      // Default constructor: SizedBox(height: 16), Icon(Icons.star)
      final name = methodName;
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
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _checkAmbientWalletAccountProperty(
      node,
      node.prefix.name,
      node.identifier.name,
    );
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _checkAmbientWalletAccountProperty(
      node,
      _terminalTargetName(node.target),
      node.propertyName.name,
    );
    super.visitPropertyAccess(node);
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

  /// Files allowed to mutate the active per-identity storage bucket. The
  /// SessionController is the single writer (serialized transitions); the
  /// declaration itself lives in network_prefs.dart.
  static const _identityBucketWriterAllowlist = [
    'core/identity/session_controller.dart',
    'core/utils/network_prefs.dart',
  ];

  /// Files allowed to publish the process-wide identity mirror. The identity
  /// declaration initializes the mirror; SessionController is its only runtime
  /// writer.
  static const _identitySnapshotWriterAllowlist = [
    'core/identity/identity.dart',
    'core/identity/session_controller.dart',
  ];

  /// The node facade is the only place allowed to call the raw Rust wallet
  /// send APIs. UI and bridge code must cross its identity-aware effect gate.
  static const _walletEffectGatewayAllowlist = [
    'features/node/node_service.dart',
  ];

  /// Account-sensitive areas where ambient account/bucket lookup is unsafe.
  /// These paths must receive an explicit AccountStorageScope or wallet lease.
  static const _ambientWalletAccountPathMarkers = [
    '/features/wallet/',
    '/features/dapps/',
    '/core/providers/wallet_provider.dart',
    '/core/providers/mempool_provider.dart',
    '/core/providers/recipient_history_provider.dart',
    '/core/services/explorer_service.dart',
  ];

  static const _accountRepositoryTargetNames = {
    'accountRepo',
    'accounts',
    'repo',
    'repository',
    'accountRepository',
    'accountsRepository',
  };

  /// Temporary, file-specific exceptions for legacy stores which cannot yet
  /// accept an explicit scope. Keep this list narrow: new files must not be
  /// added merely to silence the rule.
  static const _ambientWalletAccountAllowlist = <String>[];

  /// `NetworkPrefs.setActiveBucket` outside the SessionController breaks the
  /// single-writer invariant the identity lifecycle depends on (see
  /// docs/identity-lifecycle-invariants.md): a second writer can flip the
  /// bucket mid-transition and leak one identity's data into another's.
  void _checkIdentityBucketWriter(
    AstNode node,
    String? typeName,
    String methodName,
  ) {
    if (typeName != 'NetworkPrefs' || methodName != 'setActiveBucket') return;
    if (_isAllowlisted(_identityBucketWriterAllowlist)) return;
    _report(
      node,
      'single_identity_bucket_writer',
      'NetworkPrefs.setActiveBucket called outside SessionController. '
          'The active identity bucket has exactly one writer '
          '(core/identity/session_controller.dart); route identity '
          'transitions through the SessionController instead.',
      'WARNING',
    );
  }

  /// `IdentitySnapshots.publish` outside SessionController creates a second
  /// identity writer and lets the ambient mirror diverge from Riverpod state.
  void _checkIdentitySnapshotWriter(
    AstNode node,
    String? typeName,
    String methodName,
  ) {
    if (typeName != 'IdentitySnapshots' || methodName != 'publish') return;
    if (_isAllowlisted(_identitySnapshotWriterAllowlist)) return;
    _report(
      node,
      'single_identity_snapshot_writer',
      'IdentitySnapshots.publish called outside SessionController. '
          'The ambient identity mirror has exactly one runtime writer '
          '(core/identity/session_controller.dart); route identity '
          'transitions through that controller instead.',
      'WARNING',
    );
  }

  /// Raw Rust wallet sends bypass the facade's final identity/runtime check.
  void _checkWalletEffectGateway(
    AstNode node,
    String? targetName,
    String methodName,
  ) {
    if (targetName != 'wallet' ||
        (methodName != 'txSend' && methodName != 'txSendResult')) {
      return;
    }
    if (_isAllowlisted(_walletEffectGatewayAllowlist)) return;
    _report(
      node,
      'wallet_effect_gateway_only',
      'Raw wallet.$methodName call outside node_service.dart. Route wallet '
          'effects through RustBackendService so the exact wallet lease and '
          'runtime authority are checked immediately before the RPC begins.',
      'WARNING',
    );
  }

  void _checkAmbientWalletAccountInvocation(
    AstNode node,
    String? typeName,
    String methodName,
  ) {
    if (!_isAmbientWalletAccountPath ||
        _isAllowlisted(_ambientWalletAccountAllowlist)) {
      return;
    }

    final isActiveAccountRead = methodName == 'getActive' &&
        _accountRepositoryTargetNames.contains(typeName);
    final isAmbientAccountKey =
        typeName == 'NetworkPrefs' && methodName == 'prefixAccountKey';
    if (!isActiveAccountRead && !isAmbientAccountKey) return;

    _reportAmbientWalletAccount(
        node,
        isActiveAccountRead
            ? 'AccountsRepository.getActive()'
            : 'NetworkPrefs.prefixAccountKey()');
  }

  void _checkAmbientWalletAccountProperty(
    AstNode node,
    String? typeName,
    String propertyName,
  ) {
    if (!_isAmbientWalletAccountPath ||
        _isAllowlisted(_ambientWalletAccountAllowlist) ||
        typeName != 'NetworkPrefs' ||
        propertyName != 'activeBucket') {
      return;
    }
    _reportAmbientWalletAccount(node, 'NetworkPrefs.activeBucket');
  }

  void _reportAmbientWalletAccount(AstNode node, String expression) {
    _report(
      node,
      'no_ambient_wallet_account',
      '$expression used in an account-sensitive wallet path. Capture an '
          'AccountStorageScope or wallet identity lease at the operation '
          'boundary and pass it through explicitly instead of consulting '
          'mutable ambient account state after an await.',
      'WARNING',
    );
  }

  String get _normalizedPath => filePath.replaceAll('\\', '/');

  bool _isAllowlisted(List<String> allowlist) =>
      allowlist.any(_normalizedPath.endsWith);

  bool get _isAmbientWalletAccountPath {
    final path = '/$_normalizedPath';
    return _ambientWalletAccountPathMarkers.any(path.contains);
  }

  /// Returns the final name in a syntactic target such as
  /// `IdentitySnapshots`, `alias.IdentitySnapshots`, or
  /// `alias.api.IdentitySnapshots`. No element resolution is required.
  String? _terminalTargetName(Expression? target) {
    if (target is SimpleIdentifier) return target.name;
    if (target is PrefixedIdentifier) return target.identifier.name;
    if (target is PropertyAccess) return target.propertyName.name;
    if (target is MethodInvocation) return target.methodName.name;
    return null;
  }

  /// Resolves the direct receiver, or the enclosing cascade target for calls
  /// such as `wallet..txSendResult()` and `repo..getActive()`.
  String? _invocationTargetName(MethodInvocation node) {
    final direct = _terminalTargetName(node.target);
    if (direct != null || !node.isCascaded) return direct;
    AstNode? ancestor = node.parent;
    while (ancestor != null) {
      if (ancestor is CascadeExpression) {
        return _terminalTargetName(ancestor.target);
      }
      ancestor = ancestor.parent;
    }
    return null;
  }

  /// Types that use default (unnamed) constructors we care about.
  static const _defaultConstructorTypes = {
    'SizedBox',
    'Icon',
    'Padding',
    'Card',
    'ListTile',
    'SwitchListTile',
    'CheckboxListTile',
    'RadioListTile',
    'AppCard',
    'FilledButton',
    'OutlinedButton',
    'TextButton',
    'ElevatedButton',
  };

  void _dispatch(
    AstNode node,
    String typeName,
    String? constructorName,
    ArgumentList args,
  ) {
    switch (typeName) {
      case 'EdgeInsets':
      case 'EdgeInsetsDirectional':
        _checkEdgeInsets(node, typeName, constructorName, args);
        _checkMatryoshka(node, constructorName, args);
      case 'BorderRadius':
      case 'Radius':
        _checkBorderRadius(node, typeName, constructorName, args);
      case 'SizedBox':
        _checkSizedBoxSpacing(node, args);
      case 'Icon':
        _checkIconSize(node, args);
      case 'Padding':
        _checkPaddingAroundTile(node, args);
      case 'ListTile':
      case 'SwitchListTile':
      case 'CheckboxListTile':
      case 'RadioListTile':
        _checkListTileLayoutOverrides(node, typeName, args);
      case 'Card':
        _checkCardMargin(node, args);
      case 'AppCard':
        _checkTileCardVerticalInset(node, args);
      case 'FilledButton':
      case 'OutlinedButton':
      case 'TextButton':
      case 'ElevatedButton':
        _checkPreferDsButton(node, typeName);
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

      // space24 is dual-purpose: vertical section gap AND the canonical
      // PSL body keyline inset (horizontal). SliverPadding, Card margin,
      // ListView padding, etc. all legitimately use symmetric(horizontal:
      // space24) to align with the pinned bar title. No horizontal check
      // here — matryoshka_zone_violation still guards space32/space48.
    }
  }

  // ── Rule 6: avoid_padding_around_tiles ──────────────────────────────

  static const _tileWidgetNames = {
    'ListTile',
    'SwitchListTile',
    'CheckboxListTile',
    'RadioListTile',
    'ExpansionTile',
  };

  void _checkPaddingAroundTile(AstNode node, ArgumentList args) {
    // Check if this Padding has horizontal insets.
    if (!_hasHorizontalPadding(args)) return;

    // Find the child: argument.
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        if (_containsTileWidget(arg.expression)) {
          _report(
            node,
            'avoid_padding_around_tiles',
            'Padding with horizontal insets wraps a ListTile-family widget. '
                'ListTile/SwitchListTile/ExpansionTile get contentPadding '
                'from the theme — remove the outer horizontal Padding to '
                'avoid double-indenting.',
            'WARNING',
          );
        }
        return;
      }
    }
  }

  /// Returns true if the Padding's `padding:` argument has a horizontal
  /// component. Only checks syntactic patterns (EdgeInsets constructors).
  bool _hasHorizontalPadding(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is! NamedExpression || arg.name.label.name != 'padding') continue;
      final expr = arg.expression;

      // Match EdgeInsets.symmetric(horizontal: ...)
      if (expr is MethodInvocation) {
        final target = expr.target;
        final methodName = expr.methodName.name;
        if (target is SimpleIdentifier && target.name == 'EdgeInsets') {
          return _edgeInsetsHasHorizontal(methodName, expr.argumentList);
        }
      }
      if (expr is InstanceCreationExpression) {
        final typeName = expr.constructorName.type.name2.lexeme;
        final ctorName = expr.constructorName.name?.name;
        if (typeName == 'EdgeInsets' && ctorName != null) {
          return _edgeInsetsHasHorizontal(ctorName, expr.argumentList);
        }
      }
    }
    return false;
  }

  /// Checks if a specific EdgeInsets constructor has a horizontal component.
  bool _edgeInsetsHasHorizontal(String ctorName, ArgumentList args) {
    switch (ctorName) {
      case 'all':
        // EdgeInsets.all() always has horizontal padding.
        return args.arguments.isNotEmpty;
      case 'symmetric':
        return args.arguments.any(
          (a) => a is NamedExpression && a.name.label.name == 'horizontal',
        );
      case 'only':
        return args.arguments.any(
          (a) =>
              a is NamedExpression &&
              (a.name.label.name == 'left' || a.name.label.name == 'right'),
        );
      case 'fromLTRB':
        // Positional: left=0, right=2. Check if they're non-zero.
        final positional =
            args.arguments.where((a) => a is! NamedExpression).toList();
        if (positional.isEmpty) return false;
        // left (index 0)
        if (positional.isNotEmpty) {
          final v = numericLiteralValue(positional[0]);
          if (v != null && v != 0) return true;
        }
        // right (index 2)
        if (positional.length > 2) {
          final v = numericLiteralValue(positional[2]);
          if (v != null && v != 0) return true;
        }
        // Non-literal args — can't tell, assume horizontal.
        if (positional.isNotEmpty &&
            numericLiteralValue(positional[0]) == null) {
          return true;
        }
        if (positional.length > 2 &&
            numericLiteralValue(positional[2]) == null) {
          return true;
        }
        return false;
      default:
        return false;
    }
  }

  /// Recursively checks if the AST subtree contains a tile-family widget.
  bool _containsTileWidget(Expression expr) {
    // Check InstanceCreationExpression: const ListTile(...), new SwitchListTile(...)
    if (expr is InstanceCreationExpression) {
      final typeName = expr.constructorName.type.name2.lexeme;
      if (_tileWidgetNames.contains(typeName)) return true;
      return _searchArgumentsForTile(expr.argumentList);
    }

    // Check MethodInvocation: unprefixed ListTile(...)
    if (expr is MethodInvocation) {
      final target = expr.target;
      if (target == null && _tileWidgetNames.contains(expr.methodName.name)) {
        return true;
      }
      return _searchArgumentsForTile(expr.argumentList);
    }

    // Check list literals: [ListTile(...), SwitchListTile(...)]
    if (expr is ListLiteral) {
      for (final element in expr.elements) {
        if (element is Expression && _containsTileWidget(element)) return true;
        if (element is IfElement) {
          if (element.thenElement is Expression &&
              _containsTileWidget(element.thenElement as Expression)) {
            return true;
          }
          if (element.elseElement is Expression &&
              _containsTileWidget(element.elseElement as Expression)) {
            return true;
          }
        }
        if (element is SpreadElement &&
            _containsTileWidget(element.expression)) {
          return true;
        }
        if (element is ForElement) {
          final body = element.body;
          if (body is Expression && _containsTileWidget(body)) return true;
          if (body is IfElement) {
            if (body.thenElement is Expression &&
                _containsTileWidget(body.thenElement as Expression)) {
              return true;
            }
            if (body.elseElement is Expression &&
                _containsTileWidget(body.elseElement as Expression)) {
              return true;
            }
          }
          if (body is SpreadElement && _containsTileWidget(body.expression)) {
            return true;
          }
        }
      }
    }

    // Check conditional: condition ? ListTile() : SizedBox()
    if (expr is ConditionalExpression) {
      if (_containsTileWidget(expr.thenExpression)) return true;
      if (_containsTileWidget(expr.elseExpression)) return true;
    }

    return false;
  }

  /// Searches argument list values for tile widgets.
  bool _searchArgumentsForTile(ArgumentList args) {
    for (final arg in args.arguments) {
      final Expression value;
      if (arg is NamedExpression) {
        value = arg.expression;
      } else {
        value = arg;
      }
      if (_containsTileWidget(value)) return true;
    }
    return false;
  }

  // ── Rule 10: avoid_card_margin ─────────────────────────────────────

  void _checkCardMargin(AstNode node, ArgumentList args) {
    if (isExcludedPath(filePath)) return;

    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'margin') {
        _report(
          node,
          'avoid_card_margin',
          'Card margin is zeroed by CardThemeData. '
              'Use a parent Padding or SizedBox for spacing '
              'instead of Card(margin:).',
          'WARNING',
        );
        return;
      }
    }
  }

  // ── Rule 9: require_tile_card_vertical_inset ────────────────────────

  void _checkTileCardVerticalInset(AstNode node, ArgumentList args) {
    // Find padding: named argument.
    Expression? paddingExpr;
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'padding') {
        paddingExpr = arg.expression;
        break;
      }
    }
    if (paddingExpr == null) return;

    // Check if padding is EdgeInsets.zero (PropertyAccess or PrefixedIdentifier).
    if (!_isEdgeInsetsZero(paddingExpr)) return;

    // Find child: named argument and check for tile widgets.
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'child') {
        if (_containsTileWidget(arg.expression)) {
          _report(
            node,
            'require_tile_card_vertical_inset',
            'AppCard with EdgeInsets.zero contains tile widgets. '
                'Use EdgeInsets.symmetric(vertical: spacing.space8) '
                'for list surface inset.',
            'WARNING',
          );
        }
        return;
      }
    }
  }

  /// Returns true if [expr] is `EdgeInsets.zero`.
  bool _isEdgeInsetsZero(Expression expr) {
    // PropertyAccess: EdgeInsets.zero (when parsed as property access)
    if (expr is PropertyAccess) {
      final target = expr.target;
      if (target is SimpleIdentifier &&
          target.name == 'EdgeInsets' &&
          expr.propertyName.name == 'zero') {
        return true;
      }
    }
    // PrefixedIdentifier: EdgeInsets.zero (when parsed as prefixed identifier)
    if (expr is PrefixedIdentifier) {
      if (expr.prefix.name == 'EdgeInsets' && expr.identifier.name == 'zero') {
        return true;
      }
    }
    return false;
  }

  // ── Rule 7: avoid_listtile_layout_overrides ────────────────────────

  static const _listTileLayoutProps = {
    'visualDensity',
    'minVerticalPadding',
    'minTileHeight',
    'titleAlignment',
    'contentPadding',
  };

  void _checkListTileLayoutOverrides(
    AstNode node,
    String typeName,
    ArgumentList args,
  ) {
    // Exclude widgetbook and test paths — demos need to show variants.
    if (isExcludedPath(filePath)) return;

    for (final arg in args.arguments) {
      if (arg is! NamedExpression) continue;
      final name = arg.name.label.name;
      if (_listTileLayoutProps.contains(name)) {
        _report(
          node,
          'avoid_listtile_layout_overrides',
          "$typeName layout property '$name' should be set in the theme, "
              'not per-widget. Per-widget overrides break M3\'s baseline '
              'alignment algorithm. See CONSTRAINTS.md § ListTile Layout '
              'Constraint.',
          'WARNING',
        );
        return;
      }
    }
  }

  // ── Rule 11: require_ds_button ─────────────────────────────────────

  void _checkPreferDsButton(AstNode node, String typeName) {
    if (isExcludedPath(filePath)) return;
    // DS Button itself uses FilledButton internally.
    if (filePath.contains('design_system/src/button.dart')) return;
    _report(
      node,
      'require_ds_button',
      'Raw $typeName is not allowed — use design_system Button. '
          'Button enforces tokenized sizing (small/regular/large) and '
          'consistent styling. See lib/design_system/src/button.dart.',
      'WARNING',
    );
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
