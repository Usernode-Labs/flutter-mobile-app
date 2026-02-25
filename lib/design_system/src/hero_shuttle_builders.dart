import 'package:flutter/material.dart';

/// A [Hero.flightShuttleBuilder] that smoothly interpolates the [TextStyle]
/// between source and destination using [TextStyleTween].
///
/// This avoids the default cross-fade (which overlaps two Text widgets) and
/// instead renders a single Text widget per frame with interpolated font size,
/// weight, letter spacing, etc.
///
/// The shuttle is wrapped in [Material] with [MaterialType.transparency] so the
/// text inherits no unexpected background or elevation during flight.
Widget titleFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final fromText = fromHeroContext.widget as Hero;
  final toText = toHeroContext.widget as Hero;

  // Extract the Text widget from each Hero's child tree.
  final fromTextWidget = _findTextWidget(fromText.child);
  final toTextWidget = _findTextWidget(toText.child);

  if (fromTextWidget == null || toTextWidget == null) {
    // Fallback: default cross-fade behavior.
    return toText.child;
  }

  final fromStyle = fromTextWidget.style ?? const TextStyle();
  final toStyle = toTextWidget.style ?? const TextStyle();
  final tween = TextStyleTween(begin: fromStyle, end: toStyle);

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      return Material(
        type: MaterialType.transparency,
        child: Text(
          toTextWidget.data ?? '',
          style: tween.evaluate(animation),
          overflow: toTextWidget.overflow,
          maxLines: toTextWidget.maxLines,
        ),
      );
    },
  );
}

/// Recursively searches for the first [Text] widget in the child tree.
Text? _findTextWidget(Widget widget) {
  if (widget is Text) return widget;
  if (widget is Material && widget.child != null) {
    return _findTextWidget(widget.child!);
  }
  if (widget is DefaultTextStyle) {
    return _findTextWidget(widget.child);
  }
  if (widget is Padding && widget.child != null) {
    return _findTextWidget(widget.child!);
  }
  return null;
}
