import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class MultiplierCard extends StatelessWidget {
  final String multiplier;
  final String subtitle;
  final double progress;

  const MultiplierCard({
    Key? key,
    required this.multiplier,
    required this.subtitle,
    required this.progress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 🔥 NEW: Get theme from context

    return Card(
      // 🔥 CHANGED: Using Material 3 Card
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.multiplierColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings,
                    color: AppTheme.multiplierColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  multiplier,
                  style: theme.textTheme.displayMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE8EAED),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.multiplierColor),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium, // 🔥 CHANGED: Using theme
            ),
          ],
        ),
      ),
    );
  }
}
