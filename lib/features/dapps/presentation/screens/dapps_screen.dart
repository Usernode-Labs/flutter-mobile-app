import 'package:flutter/material.dart';
import 'package:crypto_mobile_app/core/widgets/app_bar.dart';
import 'package:crypto_mobile_app/core/widgets/app_drawer.dart';
import 'package:crypto_mobile_app/features/dapps/presentation/widgets/dapp_card.dart';

/// dApps Screen - App Store for decentralized applications
///
/// This screen will display:
/// - Featured dApps carousel
/// - Category filters (DeFi, NFT, Gaming, DAO, etc.)
/// - First-party dApps (Staking, Liquidity, Bridge, etc.)
/// - Third-party dApps from lib/dapps/
class DAppsScreen extends StatefulWidget {
  const DAppsScreen({super.key});

  @override
  State<DAppsScreen> createState() => _DAppsScreenState();
}

class _DAppsScreenState extends State<DAppsScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'DeFi',
    'NFT',
    'Gaming',
    'DAO',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: const AppAppBar(
        title: 'dApps',
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category filters
            SizedBox(
              height: 56,
              child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: colorScheme.primaryContainer,
                    checkmarkColor: colorScheme.onPrimaryContainer,
                  ),
                );
              },
            ),
          ),

          // dApps list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First-party dApps section
                  Text(
                    'First-Party dApps',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  DAppCard(
                    name: 'Staking',
                    description: 'Lock tokens to earn rewards and boost your tier',
                    icon: Icons.lock,
                    color: colorScheme.tertiary,
                    badge: 'New',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Staking coming soon')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  DAppCard(
                    name: 'Swap',
                    description: 'Exchange tokens instantly at best rates',
                    icon: Icons.swap_horiz,
                    color: colorScheme.secondary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Swap coming soon')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  DAppCard(
                    name: 'Bridge',
                    description: 'Transfer assets across different blockchains',
                    icon: Icons.account_balance,
                    color: colorScheme.primary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bridge coming soon')),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  DAppCard(
                    name: 'Liquidity Pool',
                    description: 'Provide liquidity and earn trading fees',
                    icon: Icons.water_drop,
                    color: colorScheme.tertiary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Liquidity Pool coming soon')),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Third-party dApps section (placeholder)
                  Text(
                    'Third-Party dApps',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.apps_outlined,
                            size: 64,
                            color: colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No third-party dApps yet',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Developers can add their dApps to lib/dapps/',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
