/// Marionette MCP configuration for design system widget hooks.
///
/// Registers custom DS widgets as interactive elements and enables
/// text-based matching for AI agent interactions.
library;

import 'package:flutter/widgets.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/src/challenge_card.dart';
import 'package:crypto_mobile_app/design_system/src/dapp_card.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_chain.dart';
import 'package:crypto_mobile_app/design_system/src/dropdown_chip.dart';
import 'package:crypto_mobile_app/design_system/src/score_header.dart';
import 'package:crypto_mobile_app/design_system/src/top_app_bar.dart';

/// Widget types that should be discoverable by Marionette's
/// `get_interactive_elements` tool.
const _interactiveTypes = <Type>{
  Button,
  DropdownChain,
  DropdownChip,
  ChallengeCard,
  DappCard,
};

/// Configuration passed to [MarionetteBinding.ensureInitialized].
final marionetteConfiguration = MarionetteConfiguration(
  isInteractiveWidget: (type) => _interactiveTypes.contains(type),
  extractText: _extractText,
);

/// Extract meaningful text from DS widgets for text-based matching.
///
/// Enables AI agents to tap widgets by content, e.g.:
///   `tap(text: "Run a Full Node")`
String? _extractText(Widget widget) {
  if (widget is ChallengeCard) return widget.title;
  if (widget is DappCard) return widget.name;
  if (widget is ScoreHeader) return widget.score;
  if (widget is TopAppBar) return widget.title;
  if (widget is Button) return widget.label;
  if (widget is DropdownChip) return widget.label;

  return null;
}
