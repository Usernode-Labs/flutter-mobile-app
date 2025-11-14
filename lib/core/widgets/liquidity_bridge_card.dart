import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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

    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primary.withValues(alpha: 0.1),
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
                    backgroundColor: scheme.primary,
                  ),
                  child: Text(buttonText ??
                      l10n.bridge), // 🔥 NEW: Use i18n with fallback
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: Icon(Icons.star, size: 14, color: scheme.secondary),
                  label: Text(
                    bonusText, // This remains dynamic
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.secondary,
                    ),
                  ),
                  backgroundColor: scheme.secondary.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: scheme.secondary.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
