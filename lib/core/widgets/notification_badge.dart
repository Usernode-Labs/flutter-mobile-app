import 'package:flutter/material.dart';

/// A badge widget that displays a count indicator on top of a child widget
class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;
  final bool showBadge;
  final Color? badgeColor;
  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
    this.showBadge = true,
    this.badgeColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayBadge = showBadge && count > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (displayBadge)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: EdgeInsets.all(count > 9 ? 4 : 5),
              decoration: BoxDecoration(
                color: badgeColor ?? colorScheme.error,
                shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: count > 9 ? BorderRadius.circular(10) : null,
                border: Border.all(
                  color: colorScheme.surface,
                  width: 1.5,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: count > 9 ? 18 : 16,
                minHeight: 16,
              ),
              child: count > 9
                  ? Text(
                      count > 99 ? '99+' : count.toString(),
                      style: TextStyle(
                        color: textColor ?? colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
