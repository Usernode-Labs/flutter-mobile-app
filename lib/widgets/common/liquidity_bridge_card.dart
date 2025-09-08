import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

class LiquidityBridgeCard extends StatelessWidget {
  final String? title; // 🔥 CHANGED: Made optional since we'll use i18n
  final String? subtitle; // 🔥 CHANGED: Made optional since we'll use i18n
  final String? buttonText; // 🔥 CHANGED: Made optional since we'll use i18n
  final String
      bonusText; // Keep this as parameter since it's dynamic (+1.5x, +2.0x, etc.)
  final VoidCallback? onBridgePressed;

  const LiquidityBridgeCard({
    super.key,
    this.title, // 🔥 CHANGED: Optional
    this.subtitle, // 🔥 CHANGED: Optional
    this.buttonText, // 🔥 CHANGED: Optional
    this.bonusText = '+1.5x',
    this.onBridgePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context); // 🔥 NEW: Get localizations

    return Card(
      color: AppTheme.multiplierColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? l10n.bringLiquidity, // 🔥 NEW: Use i18n with fallback
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                subtitle ??
                    l10n.bridgeAssetsDescription, // 🔥 NEW: Use i18n with fallback
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: onBridgePressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.multiplierColor,
                  ),
                  child: Text(buttonText ??
                      l10n.bridge), // 🔥 NEW: Use i18n with fallback
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: const Icon(Icons.star,
                      size: 14, color: AppTheme.successCheckColor),
                  label: Text(
                    bonusText, // This remains dynamic
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successCheckColor,
                    ),
                  ),
                  backgroundColor: AppTheme.successCheckColor.withOpacity(0.1),
                  side: BorderSide(
                      color: AppTheme.successCheckColor.withOpacity(0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
