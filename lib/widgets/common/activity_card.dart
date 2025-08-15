import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final VoidCallback? onTap;

  const ActivityCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.iconColor,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 🔥 NEW: Get theme from context

    return Card(
      color: Colors.white,
      surfaceTintColor:
          Colors.transparent, // 🔥 ADD THIS - removes Material 3 tint
      margin: const EdgeInsets.symmetric(vertical: 4), // 🔥 REDUCED: Margin
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.nodeIconColor).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? AppTheme.nodeIconColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium, // 🔥 CHANGED: Using theme
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium, // 🔥 CHANGED: Using theme
        ),
        trailing: trailing ??
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.nodeIconColor,
            ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
