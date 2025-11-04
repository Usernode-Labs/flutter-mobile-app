import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
 
import 'liquidity_bridge_card.dart';
import 'package:crypto_mobile_app/core/feature_flags.dart';

class HorizontalCardScroll extends StatelessWidget {
  const HorizontalCardScroll({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 208,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 8),
        itemCount: _getCards(context, l10n).length,
        itemBuilder: (context, index) {
          return Container(
            width: 370,
            margin: const EdgeInsets.only(right: 12),
            child: _getCards(context, l10n)[index],
          );
        },
      ),
    );
  }

  List<Widget> _getCards(BuildContext context, AppLocalizations l10n) {
    final cards = <Widget>[];
    final scheme = Theme.of(context).colorScheme;

    // Add the boost card as the first item
    cards.add(
      _BoostTierCard(
        onPressed: () {},
      ),
    );

    if (FeatureFlags.on('home.bridgeCard')) {
      cards.add(
        LiquidityBridgeCard(
          bonusText: '+1.5x',
          onBridgePressed: () {},
        ),
      );
    }
    if (FeatureFlags.on('home.verifyCard')) {
      cards.add(
        _PromoCard(
          title: l10n.completeVerification,
          subtitle: l10n.verificationDescription,
          buttonText: l10n.verify,
          bonusText: '+2.0x',
          buttonColor: scheme.secondary,
          bonusColor: scheme.secondary,
          icon: Icons.verified_user,
          onPressed: () {},
        ),
      );
    }
    if (FeatureFlags.on('home.stakeCard')) {
      cards.add(
        _PromoCard(
          title: l10n.stakeTokens,
          subtitle: l10n.stakingDescription,
          buttonText: l10n.stake,
          bonusText: '+3.0x',
          buttonColor: scheme.tertiary,
          bonusColor: scheme.tertiary,
          icon: Icons.lock,
          onPressed: () {},
        ),
      );
    }
    return cards;
  }
}

class _PromoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final String bonusText;
  final Color buttonColor;
  final Color bonusColor;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PromoCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.bonusText,
    required this.buttonColor,
    required this.bonusColor,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Theme-aware tinted background that works in dark mode as well
    final bg =
        Color.alphaBlend(buttonColor.withValues(alpha: 0.10), colorScheme.surface);

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onPressed, // This now works properly
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                  ),
                  child: Text(buttonText),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        bonusColor.withValues(alpha: 0.12), colorScheme.surface),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bonusColor.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: bonusColor),
                      const SizedBox(width: 6),
                      Text(
                        bonusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: bonusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostTierCard extends StatelessWidget {
  final VoidCallback? onPressed;

  const _BoostTierCard({
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bg = Color.alphaBlend(
        theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
        colorScheme.surface);

    return Card(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Boost your tier',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                'Complete on-chain tasks to earn points and unlock higher reward tiers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      'Prove you\'re human',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+20 tier points',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.settings,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
