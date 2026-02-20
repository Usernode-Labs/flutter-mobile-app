import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({
    required this.small,
    required this.medium,
    required this.large,
    required this.xLarge,
    required this.full,
  });

  factory AppRadii.standard() => const AppRadii(
        small: 8.0,
        medium: 12.0,
        large: 16.0,
        xLarge: 24.0,
        full: 999.0,
      );

  final double small;
  final double medium;
  final double large;
  final double xLarge;
  final double full;

  // Convenience getters for BorderRadius
  BorderRadius get borderRadiusSmall =>
      BorderRadius.all(Radius.circular(small));
  BorderRadius get borderRadiusMedium =>
      BorderRadius.all(Radius.circular(medium));
  BorderRadius get borderRadiusLarge =>
      BorderRadius.all(Radius.circular(large));
  BorderRadius get borderRadiusXLarge =>
      BorderRadius.all(Radius.circular(xLarge));
  BorderRadius get borderRadiusFull => BorderRadius.all(Radius.circular(full));

  // Top-only variants (for bottom sheets, modals)
  BorderRadius get borderRadiusTopLarge =>
      BorderRadius.vertical(top: Radius.circular(large));
  BorderRadius get borderRadiusTopXLarge =>
      BorderRadius.vertical(top: Radius.circular(xLarge));

  @override
  AppRadii copyWith({
    double? small,
    double? medium,
    double? large,
    double? xLarge,
    double? full,
  }) {
    return AppRadii(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      xLarge: xLarge ?? this.xLarge,
      full: full ?? this.full,
    );
  }

  @override
  AppRadii lerp(AppRadii? other, double t) {
    if (other is! AppRadii) return this;
    return AppRadii(
      small: lerpDouble(small, other.small, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      large: lerpDouble(large, other.large, t)!,
      xLarge: lerpDouble(xLarge, other.xLarge, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}
