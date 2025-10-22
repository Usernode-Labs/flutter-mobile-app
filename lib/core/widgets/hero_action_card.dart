import 'package:flutter/material.dart';

class HeroActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final double? width;

  const HeroActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Responsive sizing based on card width
    final cardWidth = width ?? 220;
    final isSmall = cardWidth < 280;
    final isLarge = cardWidth > 400;

    // Scale sizes
    final iconContainerSize = isSmall ? 24.0 : 28.0;
    final iconSize = isSmall ? 14.0 : 16.0;
    final titleSize = isSmall ? 14.0 : (isLarge ? 16.0 : 15.0);
    final subtitleSize = isSmall ? 11.0 : 12.0;
    final actionSize = isSmall ? 10.0 : 11.0;
    final actionIconSize = isSmall ? 11.0 : 12.0;

    // Scale padding
    final cardPadding = isSmall ? 10.0 : (isLarge ? 14.0 : 12.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and title in same row
              Row(
                children: [
                  // Icon container
                  Container(
                    width: iconContainerSize,
                    height: iconContainerSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Title
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: subtitleSize,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Action indicator
              Row(
                children: [
                  Text(
                    'Learn more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: actionSize,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: actionIconSize,
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
