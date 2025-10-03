import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/account_switcher.dart';

/// dApps Screen - App Store for decentralized applications
///
/// This screen will display:
/// - Featured dApps carousel
/// - Category filters (DeFi, NFT, Gaming, DAO, etc.)
/// - First-party dApps (Staking, Liquidity, Bridge, etc.)
/// - Third-party dApps from lib/dapps/
class DAppsScreen extends StatelessWidget {
  const DAppsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('dApps'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: AccountSwitcher(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apps_outlined,
                size: 80,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'dApps Coming Soon',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Discover and launch decentralized applications.\nStake, swap, provide liquidity, and more.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 32),
              // Preview of future categories
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _CategoryChip(
                    icon: Icons.account_balance,
                    label: 'DeFi',
                    colorScheme: colorScheme,
                  ),
                  _CategoryChip(
                    icon: Icons.palette,
                    label: 'NFT',
                    colorScheme: colorScheme,
                  ),
                  _CategoryChip(
                    icon: Icons.videogame_asset,
                    label: 'Gaming',
                    colorScheme: colorScheme,
                  ),
                  _CategoryChip(
                    icon: Icons.how_to_vote,
                    label: 'DAO',
                    colorScheme: colorScheme,
                  ),
                  _CategoryChip(
                    icon: Icons.analytics,
                    label: 'Analytics',
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
    );
  }
}
