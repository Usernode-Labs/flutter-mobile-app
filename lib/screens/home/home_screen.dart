import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/activity_card.dart';
import '../../widgets/common/multiplier_card.dart';
import '../../widgets/common/horizontal_card_scroll.dart';
import 'package:crypto_mobile_app/config/feature_flags.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? AppBar(
              leading: const BackButton(),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node status card (with i18n)
            if (FeatureFlags.isEnabled(AppFeature.node))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ActivityCard(
                  icon: Icons.hub,
                  title: l10n.nodeStatusSynced('1.32s'),
                  subtitle: l10n.totalNodes('231,641'),
                  iconColor: AppTheme.nodeIconColor,
                ),
              ),

            const SizedBox(height: 16),

            // Horizontal scrolling cards
            if (FeatureFlags.on('home.cards')) const HorizontalCardScroll(),

            const SizedBox(height: 16),

            // Activity section (with i18n)
            if (FeatureFlags.on('home.multiplier')) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.yourMultiplier,
                  style: AppTheme.activityTitleStyle,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: MultiplierCard(
                  multiplier: '2.5x',
                  subtitle: l10n.tokensExpected('100', '14'),
                  progress: 0.7,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Activity section (with i18n)
            if (FeatureFlags.on('home.activity')) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.activity,
                  style: AppTheme.activityTitleStyle,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successCheckColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successCheckColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
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
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
      ),
    );
  }
}
