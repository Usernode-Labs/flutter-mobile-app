import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppElevation extends ThemeExtension<AppElevation> {
  const AppElevation({
    required this.none,
    required this.low,
    required this.medium,
    required this.high,
    required this.max,
  });

  factory AppElevation.standard() => const AppElevation(
        none: 0.0,
        low: 1.0,
        medium: 2.0,
        high: 4.0,
        max: 8.0,
      );

  final double none;
  final double low;
  final double medium;
  final double high;
  final double max;

  @override
  AppElevation copyWith({
    double? none,
    double? low,
    double? medium,
    double? high,
    double? max,
  }) {
    return AppElevation(
      none: none ?? this.none,
      low: low ?? this.low,
      medium: medium ?? this.medium,
      high: high ?? this.high,
      max: max ?? this.max,
    );
  }

  @override
  AppElevation lerp(AppElevation? other, double t) {
    if (other is! AppElevation) return this;
    return AppElevation(
      none: lerpDouble(none, other.none, t)!,
      low: lerpDouble(low, other.low, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      high: lerpDouble(high, other.high, t)!,
      max: lerpDouble(max, other.max, t)!,
    );
  }
}
