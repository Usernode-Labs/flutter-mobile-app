import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../screens/scaffold_builder.dart';

class NodeStatusScreen extends StatelessWidget {
  const NodeStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return buildScaffold(
      context,
      title: l10n.bridge,
      icon: Icons.swap_horiz,
      screenName: l10n.crossChainBridge,
    );
  }
}

class SwapPlaceholder extends StatelessWidget {
  const SwapPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 REMOVED: Unused l10n variable since we don't have swap strings yet
    return buildScaffold(
      context,
      title: 'Swap', // 🔥 TODO: Add to l10n files
      icon: Icons.currency_exchange,
      screenName: 'Token Swap', // 🔥 TODO: Add to l10n files
    );
  }
}

class StatusPlaceholder extends StatelessWidget {
  const StatusPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return buildScaffold(
      context,
      title: l10n.node,
      icon: Icons.hub,
      screenName: l10n.nodeStatus,
    );
  }
}

class RewardsPlaceholder extends StatelessWidget {
  const RewardsPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔥 REMOVED: Unused l10n variable since we don't have rewards strings yet
    return buildScaffold(
      context,
      title: 'Rewards', // 🔥 TODO: Add to l10n files
      icon: Icons.card_giftcard,
      screenName: 'Rewards & Achievements', // 🔥 TODO: Add to l10n files
    );
  }
}
