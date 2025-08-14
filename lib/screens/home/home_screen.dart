import 'package:flutter/material.dart';
import '../../gen_l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/activity_card.dart';
import '../../widgets/common/multiplier_card.dart';
import '../../widgets/common/horizontal_card_scroll.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.home)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Activity section (with i18n)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.yourMultiplier,
                style: AppTheme.activityTitleStyle,
              ),
            ),
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
