import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({
    required this.xSmall,
    required this.small,
    required this.medium,
    required this.large,
    required this.largeIncreased,
    required this.xLarge,
    required this.xxLarge,
    required this.full,
  });

  factory AppRadii.standard() => const AppRadii(
        xSmall: 4.0,
        small: 8.0,
        medium: 12.0,
        large: 16.0,
        largeIncreased: 20.0,
        xLarge: 24.0,
        xxLarge: 28.0,
        full: 999.0,
      );

  final double xSmall;
  final double small;
  final double medium;
  final double large;
  final double largeIncreased;
  final double xLarge;
  final double xxLarge;
  final double full;

  // Convenience getters for BorderRadius
  BorderRadius get borderRadiusXSmall =>
      BorderRadius.all(Radius.circular(xSmall));
  BorderRadius get borderRadiusSmall =>
      BorderRadius.all(Radius.circular(small));
  BorderRadius get borderRadiusMedium =>
      BorderRadius.all(Radius.circular(medium));
  BorderRadius get borderRadiusLarge =>
      BorderRadius.all(Radius.circular(large));
  BorderRadius get borderRadiusLargeIncreased =>
      BorderRadius.all(Radius.circular(largeIncreased));
  BorderRadius get borderRadiusXLarge =>
      BorderRadius.all(Radius.circular(xLarge));
  BorderRadius get borderRadiusXXLarge =>
      BorderRadius.all(Radius.circular(xxLarge));
  BorderRadius get borderRadiusFull => BorderRadius.all(Radius.circular(full));

  // Top-only variants (for bottom sheets, modals, split cards)
  BorderRadius get borderRadiusTopSmall =>
      BorderRadius.vertical(top: Radius.circular(small));
  BorderRadius get borderRadiusTopLarge =>
      BorderRadius.vertical(top: Radius.circular(large));
  BorderRadius get borderRadiusTopLargeIncreased =>
      BorderRadius.vertical(top: Radius.circular(largeIncreased));
  BorderRadius get borderRadiusTopXLarge =>
      BorderRadius.vertical(top: Radius.circular(xLarge));
  BorderRadius get borderRadiusTopXXLarge =>
      BorderRadius.vertical(top: Radius.circular(xxLarge));

  // Bottom-only variants (for split cards)
  BorderRadius get borderRadiusBottomLargeIncreased =>
      BorderRadius.vertical(bottom: Radius.circular(largeIncreased));

  @override
  AppRadii copyWith({
    double? xSmall,
    double? small,
    double? medium,
    double? large,
    double? largeIncreased,
    double? xLarge,
    double? xxLarge,
    double? full,
  }) {
    return AppRadii(
      xSmall: xSmall ?? this.xSmall,
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      largeIncreased: largeIncreased ?? this.largeIncreased,
      xLarge: xLarge ?? this.xLarge,
      xxLarge: xxLarge ?? this.xxLarge,
      full: full ?? this.full,
    );
  }

  @override
  AppRadii lerp(AppRadii? other, double t) {
    if (other is! AppRadii) return this;
    return AppRadii(
      xSmall: lerpDouble(xSmall, other.xSmall, t)!,
      small: lerpDouble(small, other.small, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      large: lerpDouble(large, other.large, t)!,
      largeIncreased: lerpDouble(largeIncreased, other.largeIncreased, t)!,
      xLarge: lerpDouble(xLarge, other.xLarge, t)!,
      xxLarge: lerpDouble(xxLarge, other.xxLarge, t)!,
      full: lerpDouble(full, other.full, t)!,
    );
  }
}
