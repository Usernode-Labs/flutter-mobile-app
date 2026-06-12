import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppOpacity extends ThemeExtension<AppOpacity> {
  const AppOpacity({
    required this.subtle,
    required this.medium,
    required this.strong,
    required this.disabled,
    required this.secondary,
  });

  factory AppOpacity.standard() => const AppOpacity(
        subtle: 0.08,
        medium: 0.12,
        strong: 0.20,
        disabled: 0.38,
        secondary: 0.40,
      );

  final double subtle;
  final double medium;
  final double strong;
  final double disabled;
  final double secondary;

  @override
  AppOpacity copyWith({
    double? subtle,
    double? medium,
    double? strong,
    double? disabled,
    double? secondary,
  }) {
    return AppOpacity(
      subtle: subtle ?? this.subtle,
      medium: medium ?? this.medium,
      strong: strong ?? this.strong,
      disabled: disabled ?? this.disabled,
      secondary: secondary ?? this.secondary,
    );
  }

  @override
  AppOpacity lerp(AppOpacity? other, double t) {
    if (other is! AppOpacity) return this;
    return AppOpacity(
      subtle: lerpDouble(subtle, other.subtle, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      strong: lerpDouble(strong, other.strong, t)!,
      disabled: lerpDouble(disabled, other.disabled, t)!,
      secondary: lerpDouble(secondary, other.secondary, t)!,
    );
  }
}
