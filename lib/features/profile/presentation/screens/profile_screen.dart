import 'package:flutter/material.dart';

/// Profile Screen - User profile, identity, rewards, and settings
///
/// This screen will display:
/// - User info (account name, address)
/// - Identity verification status
/// - Rewards, tier, and points
/// - Account management
/// - App preferences and settings
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings screen
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Info Section
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Account 1',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0x1234...5678',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Identity & Verification Section
              _SectionCard(
                title: 'Identity & Verification',
                icon: Icons.verified_user,
                colorScheme: colorScheme,
                theme: theme,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Identity Verified',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your identity has been successfully verified',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Rewards Section
              _SectionCard(
                title: 'Rewards & Tier',
                icon: Icons.card_giftcard,
                colorScheme: colorScheme,
                theme: theme,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tier',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🏆 Basic',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Points',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '⭐ 1,234',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Multiplier: 2.5x',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Account Management Section
              _SectionCard(
                title: 'Account Management',
                icon: Icons.account_circle,
                colorScheme: colorScheme,
                theme: theme,
                child: Column(
                  children: [
                    _ListTileButton(
                      icon: Icons.key,
                      title: 'Manage Accounts',
                      onTap: () {
                        // TODO: Navigate to account management
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.file_upload,
                      title: 'Export Keys',
                      onTap: () {
                        // TODO: Export keys
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.file_download,
                      title: 'Import Account',
                      onTap: () {
                        // TODO: Import account
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Preferences Section
              _SectionCard(
                title: 'Preferences',
                icon: Icons.tune,
                colorScheme: colorScheme,
                theme: theme,
                child: Column(
                  children: [
                    _ListTileButton(
                      icon: Icons.dark_mode,
                      title: 'Theme',
                      trailing: 'System',
                      onTap: () {
                        // TODO: Theme selector
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.language,
                      title: 'Language',
                      trailing: 'English',
                      onTap: () {
                        // TODO: Language selector
                      },
                    ),
                    _ListTileButton(
                      icon: Icons.attach_money,
                      title: 'Currency',
                      trailing: 'USD',
                      onTap: () {
                        // TODO: Currency selector
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.colorScheme,
    required this.theme,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ListTileButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _ListTileButton({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      trailing: trailing != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailing!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
