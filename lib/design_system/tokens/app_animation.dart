import 'package:flutter/material.dart';

@immutable
class AppAnimation extends ThemeExtension<AppAnimation> {
  const AppAnimation({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.complex,
  });

  factory AppAnimation.standard() => const AppAnimation(
        fast: Duration(milliseconds: 100),
        normal: Duration(milliseconds: 150),
        slow: Duration(milliseconds: 200),
        complex: Duration(milliseconds: 300),
      );

  /// 100ms - Quick transitions (micro-interactions)
  final Duration fast;

  /// 150ms - Standard transitions (most UI changes)
  final Duration normal;

  /// 200ms - Slower transitions (complex animations)
  final Duration slow;

  /// 300ms - Complex animations (page transitions)
  final Duration complex;

  @override
  AppAnimation copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Duration? complex,
  }) {
    return AppAnimation(
      fast: fast ?? this.fast,
      normal: normal ?? this.normal,
      slow: slow ?? this.slow,
      complex: complex ?? this.complex,
    );
  }

  @override
  AppAnimation lerp(AppAnimation? other, double t) {
    if (other is! AppAnimation) return this;
    // Durations don't lerp smoothly — snap at midpoint
    return AppAnimation(
      fast: t < 0.5 ? fast : other.fast,
      normal: t < 0.5 ? normal : other.normal,
      slow: t < 0.5 ? slow : other.slow,
      complex: t < 0.5 ? complex : other.complex,
    );
  }
}
