import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto_mobile_app/features/profile/domain/entities/user_tier.dart';

class AccountTierHeroCard extends StatelessWidget {
  final String accountName;
  final String address;
  final TierLevel currentTierLevel;
  final TierLevel nextEpochTierLevel;
  final int currentPoints;
  final int nextEpochPoints;
  final double? width;
  final VoidCallback? onTap;

  const AccountTierHeroCard({
    super.key,
    required this.accountName,
    required this.address,
    required this.currentTierLevel,
    required this.nextEpochTierLevel,
    required this.currentPoints,
    required this.nextEpochPoints,
    this.width,
    this.onTap,
  });

  String _shortAddr(String addr) {
    if (addr.length <= 12) return addr;
    final start = addr.substring(0, 6);
    final end = addr.substring(addr.length - 4);
    return '$start…$end';
  }

  IconData _getTierIcon(TierLevel tier) {
    return switch (tier) {
      TierLevel.basic => Icons.star_outline,
      TierLevel.bronze => Icons.emoji_events,
      TierLevel.silver => Icons.military_tech,
      TierLevel.gold => Icons.star,
      TierLevel.platinum => Icons.diamond,
    };
  }

  Color _getTierIconColor(TierLevel tier) {
    return switch (tier) {
      TierLevel.basic => const Color(0xFF4FC3F7),
      TierLevel.bronze => const Color(0xFFFFB74D),
      TierLevel.silver => const Color(0xFFB0BEC5),
      TierLevel.gold => const Color(0xFFFFD54F),
      TierLevel.platinum => const Color(0xFF9575CD),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Responsive sizing based on card width
    final cardWidth = width ?? 320;
    final isSmall = cardWidth < 300;
    final isLarge = cardWidth > 400;

    // Scale font sizes
    final titleSize = isSmall ? 16.0 : (isLarge ? 20.0 : 18.0);
    final addressSize = isSmall ? 11.0 : 12.0;
    final labelSize = isSmall ? 10.0 : 11.0;
    final valueSize = isSmall ? 13.0 : 14.0;
    final iconSize = isSmall ? 13.0 : 14.0;

    // Scale padding
    final cardPadding = isSmall ? 12.0 : (isLarge ? 18.0 : 16.0);
    final verticalSpacing = isSmall ? 8.0 : 10.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(bottom: 16),
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
              // Account name
              Text(
                accountName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: verticalSpacing / 2),

              // Address with copy
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: address));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Address copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _shortAddr(address),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: addressSize,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.copy,
                      size: iconSize,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),

              SizedBox(height: verticalSpacing + 4),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

              SizedBox(height: verticalSpacing + 4),

              // Tier information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Current tier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Tier',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: labelSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getTierIcon(currentTierLevel),
                                color: _getTierIconColor(currentTierLevel),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${currentTierLevel.name} Tier',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: valueSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Points badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$currentPoints pts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: verticalSpacing + 2),

              // Next epoch projection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Epoch Projection',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: labelSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getTierIcon(nextEpochTierLevel),
                              color: _getTierIconColor(nextEpochTierLevel),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${nextEpochTierLevel.name} Tier',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: valueSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Next epoch points
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '~$nextEpochPoints pts',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: labelSize - 1,
                            fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
