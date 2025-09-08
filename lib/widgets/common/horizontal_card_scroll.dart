import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'liquidity_bridge_card.dart';
import 'package:crypto_mobile_app/config/feature_flags.dart';

class HorizontalCardScroll extends StatelessWidget {
  const HorizontalCardScroll({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _getCards(l10n).length,
        itemBuilder: (context, index) {
          return Container(
            width: 320,
            margin: const EdgeInsets.only(right: 12),
            child: _getCards(l10n)[index],
          );
        },
      ),
    );
  }

  List<Widget> _getCards(AppLocalizations l10n) {
    final cards = <Widget>[];
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
          backgroundColor: const Color(0xFFE8F5E8),
          buttonColor: AppTheme.successCheckColor,
          bonusColor: AppTheme.successCheckColor,
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
          backgroundColor: const Color(0xFFFFF3E0),
          buttonColor: const Color(0xFFFF9800),
          bonusColor: const Color(0xFFFF9800),
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
  final Color backgroundColor;
  final Color buttonColor;
  final Color bonusColor;
  final IconData icon;
  final VoidCallback? onPressed; // This field was declared but not initialized

  const _PromoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.bonusText,
    required this.backgroundColor,
    required this.buttonColor,
    required this.bonusColor,
    required this.icon,
    this.onPressed, // ✅ Added this parameter to the constructor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
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
                Chip(
                  avatar: Icon(icon, size: 14, color: bonusColor),
                  label: Text(
                    bonusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bonusColor,
                    ),
                  ),
                  backgroundColor: bonusColor.withOpacity(0.1),
                  side: BorderSide(color: bonusColor.withOpacity(0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
