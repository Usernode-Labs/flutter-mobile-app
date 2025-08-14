import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'liquidity_bridge_card.dart';

class HorizontalCardScroll extends StatelessWidget {
  const HorizontalCardScroll({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: _getCards(l10n).length,
        itemBuilder: (context, index) {
          return Container(
            width: 300,
            margin: EdgeInsets.only(right: 12),
            child: _getCards(l10n)[index],
          );
        },
      ),
    );
  }

  List<Widget> _getCards(AppLocalizations l10n) {
    return [
      // First card - Bring your own liquidity (using default i18n)
      LiquidityBridgeCard(
        bonusText: '+1.5x', // 🔥 SIMPLIFIED: Only pass dynamic values
        onBridgePressed: () {
          // Handle bridge action
        },
      ),

      // Second card - Complete verification (with custom text)
      _PromoCard(
        title: l10n.completeVerification,
        subtitle: l10n.verificationDescription,
        buttonText: l10n.verify,
        bonusText: '+2.0x',
        backgroundColor: Color(0xFFE8F5E8),
        buttonColor: AppTheme.successCheckColor,
        bonusColor: AppTheme.successCheckColor,
        icon: Icons.verified_user,
      ),

      // Third card - Stake tokens (with custom text)
      _PromoCard(
        title: l10n.stakeTokens,
        subtitle: l10n.stakingDescription,
        buttonText: l10n.stake,
        bonusText: '+3.0x',
        backgroundColor: Color(0xFFFFF3E0),
        buttonColor: Color(0xFFFF9800),
        bonusColor: Color(0xFFFF9800),
        icon: Icons.lock,
      ),
    ];
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
  final VoidCallback? onPressed;

  const _PromoCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.bonusText,
    required this.backgroundColor,
    required this.buttonColor,
    required this.bonusColor,
    required this.icon,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: buttonColor,
                  ),
                  child: Text(buttonText),
                ),
                SizedBox(width: 12),
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
