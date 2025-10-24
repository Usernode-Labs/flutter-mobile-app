import 'package:flutter/material.dart';

class BoostTierHeroCard extends StatelessWidget {
  final double? width;
  final VoidCallback? onVerifyTap;
  final VoidCallback? onInfoTap;

  const BoostTierHeroCard({
    super.key,
    this.width,
    this.onVerifyTap,
    this.onInfoTap,
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
    final bonusSize = isSmall ? 11.0 : 12.0;
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
            // Title row with badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Boost Your Tier',
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
                    'Verify now',
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
              'Verify your identity to unlock Block Producer and boost node earnings.',
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

            // Bottom row with button and bonus
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Verify button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onVerifyTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Verify Identity',
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

                // Bonus indicator
                Row(
                  children: [
                    Text(
                      '+1x multiplier',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: bonusSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: onInfoTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.verified_user,
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
