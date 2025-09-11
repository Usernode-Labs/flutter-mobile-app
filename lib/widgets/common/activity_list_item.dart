import 'package:flutter/material.dart';

class ActivityListItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String trailing;

  const ActivityListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? scheme.primary).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? scheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            trailing,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: iconColor ?? scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
