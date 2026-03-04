import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppBorders extends ThemeExtension<AppBorders> {
  const AppBorders({
    required this.width,
    required this.opacity,
  });

  factory AppBorders.standard() => const AppBorders(width: 1.0, opacity: 0.08);

  final double width;
  final double opacity;

  @override
  AppBorders copyWith({
    double? width,
    double? opacity,
  }) {
    return AppBorders(
      width: width ?? this.width,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  AppBorders lerp(AppBorders? other, double t) {
    if (other is! AppBorders) return this;
    return AppBorders(
      width: lerpDouble(width, other.width, t)!,
      opacity: lerpDouble(opacity, other.opacity, t)!,
    );
  }
}
