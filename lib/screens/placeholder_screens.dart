import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';
import '../widgets/common/activity_card.dart';
import '../widgets/common/multiplier_card.dart';
import '../widgets/common/horizontal_card_scroll.dart';

class WalletPlaceholder extends StatelessWidget {
  const WalletPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.home)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),

            // Node status card (with i18n)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ActivityCard(
                icon: Icons.hub,
                title: l10n.nodeStatusSynced('1.32s'),
                subtitle: l10n.totalNodes('231,641'),
                iconColor: AppTheme.nodeIconColor,
              ),
            ),

            SizedBox(height: 16),

            // Horizontal scrolling cards
            HorizontalCardScroll(),

            SizedBox(height: 16),

            // Multiplier card (with i18n)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: MultiplierCard(
                multiplier: '2.5x',
                subtitle: l10n.tokensExpected('100', '14'),
                progress: 0.7,
              ),
            ),

            SizedBox(height: 24),

            // Activity section (with i18n)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.activity,
                style: AppTheme.activityTitleStyle,
              ),
            ),
            SizedBox(height: 12),

            // Activity items (with i18n)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ActivityCard(
                    icon: Icons.schedule,
                    title: l10n.upcomingBlock('3h 2m'),
                    subtitle: l10n.scheduledBackground,
                    iconColor: AppTheme.pendingIconColor,
                  ),
                  ActivityCard(
                    icon: Icons.check_circle,
                    title: l10n.identityProven,
                    subtitle: '10/14/2025 at 2:30pm',
                    iconColor: AppTheme.successCheckColor,
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successCheckColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+1.5x',
                        style: TextStyle(
                          color: AppTheme.successCheckColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  ActivityCard(
                    icon: Icons.check_circle,
                    title: l10n.depositSuccessful,
                    subtitle: '10/14/2025 at 1:30pm',
                    iconColor: AppTheme.successCheckColor,
                    trailing: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successCheckColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+10,000 USN',
                        style: TextStyle(
                          color: AppTheme.successCheckColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class IdentityPlaceholder extends StatelessWidget {
  const IdentityPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildSimplePlaceholder(
      context,
      title: l10n.wallet,
      icon: Icons.account_balance_wallet,
      screenName: l10n.walletManagement,
    );
  }
}

class BridgePlaceholder extends StatelessWidget {
  const BridgePlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _buildSimplePlaceholder(
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
    return _buildSimplePlaceholder(
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
    final l10n = AppLocalizations.of(context)!;
    return _buildSimplePlaceholder(
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
    return _buildSimplePlaceholder(
      context,
      title: 'Rewards', // 🔥 TODO: Add to l10n files
      icon: Icons.card_giftcard,
      screenName: 'Rewards & Achievements', // 🔥 TODO: Add to l10n files
    );
  }
}

Widget _buildSimplePlaceholder(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String screenName,
}) {
  final l10n = AppLocalizations.of(context)!;

  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: AppConstants.placeholderIconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(height: 16),
          Text(
            screenName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: 8),
          Text(
            l10n.comingSoon, // 🔥 USING: l10n variable
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
