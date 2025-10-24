import 'package:flutter/material.dart';

class EarnYieldHeroCard extends StatelessWidget {
  final double? width;
  final VoidCallback? onLockTap;
  final VoidCallback? onSettingsTap;

  const EarnYieldHeroCard({
    super.key,
    this.width,
    this.onLockTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive sizing based on card width
    final cardWidth = width ?? 320;
    final isSmall = cardWidth < 300;
    final isLarge = cardWidth > 400;

    // Scale font sizes
    final titleSize = isSmall ? 16.0 : (isLarge ? 20.0 : 18.0);
    final badgeSize = isSmall ? 9.0 : 10.0;
    final descriptionSize = isSmall ? 11.0 : 12.0;
    final buttonSize = isSmall ? 11.0 : 12.0;
    final pointsSize = isSmall ? 11.0 : 12.0;
    final iconSize = isSmall ? 13.0 : 14.0;

    // Scale padding
    final cardPadding = isSmall ? 12.0 : (isLarge ? 18.0 : 16.0);
    final verticalSpacing = isSmall ? 8.0 : 10.0;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1), // Indigo-500
            Color(0xFF7C3AED), // Purple-600
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with "Coming later" badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Earn Yield & Points',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Coming later',
                    style: TextStyle(
                      color: Colors.black.withAlpha(1000),
                      fontSize: badgeSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: verticalSpacing),

            // Description text
            Text(
              'Lock your USDC to earn stable yield. You\'ll also get bonus points to boost your tier.',
              style: TextStyle(
                color: Colors.white,
                fontSize: descriptionSize,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: verticalSpacing + 2),

            // Bottom row with button and points
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Lock USDC button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onLockTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lock USDC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: buttonSize,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: iconSize,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Points indicator
                Row(
                  children: [
                    Text(
                      '+100 tier points',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: pointsSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: onSettingsTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.hotel_class,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
