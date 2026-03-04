import 'dart:ui';

import 'package:flutter/material.dart';

@immutable
class AppSizing extends ThemeExtension<AppSizing> {
  const AppSizing({
    required this.iconContainerSmall,
    required this.iconContainerRegular,
    required this.iconContainerLarge,
    required this.iconContainerXLarge,
    required this.iconXSmall,
    required this.iconSmall,
    required this.iconRegular,
    required this.iconLarge,
    required this.iconXLarge,
    required this.iconDisplay,
    required this.iconDisplayLarge,
    required this.buttonHeightSmall,
    required this.buttonHeightRegular,
    required this.buttonHeightLarge,
  });

  factory AppSizing.standard() => const AppSizing(
        iconContainerSmall: 40.0,
        iconContainerRegular: 48.0,
        iconContainerLarge: 56.0,
        iconContainerXLarge: 64.0,
        iconXSmall: 16.0,
        iconSmall: 20.0,
        iconRegular: 24.0,
        iconLarge: 28.0,
        iconXLarge: 32.0,
        iconDisplay: 48.0,
        iconDisplayLarge: 64.0,
        buttonHeightSmall: 40.0,
        buttonHeightRegular: 48.0,
        buttonHeightLarge: 56.0,
      );

  /// 40px - Small icon container
  final double iconContainerSmall;

  /// 48px - Regular tap target (minimum for accessibility)
  final double iconContainerRegular;

  /// 56px - Large tap target (prominent actions)
  final double iconContainerLarge;

  /// 64px - Extra large tap target (FAB, primary actions)
  final double iconContainerXLarge;

  /// 16px - Extra small icon
  final double iconXSmall;

  /// 20px - Small icon
  final double iconSmall;

  /// 24px - Regular icon
  final double iconRegular;

  /// 28px - Large icon
  final double iconLarge;

  /// 32px - Extra large icon
  final double iconXLarge;

  /// 48px - Display icon (hero/empty-state icons)
  final double iconDisplay;

  /// 64px - Large display icon (result/empty-state icons)
  final double iconDisplayLarge;

  /// 40px - Small button
  final double buttonHeightSmall;

  /// 48px - Regular button
  final double buttonHeightRegular;

  /// 56px - Large button
  final double buttonHeightLarge;

  @override
  AppSizing copyWith({
    double? iconContainerSmall,
    double? iconContainerRegular,
    double? iconContainerLarge,
    double? iconContainerXLarge,
    double? iconXSmall,
    double? iconSmall,
    double? iconRegular,
    double? iconLarge,
    double? iconXLarge,
    double? iconDisplay,
    double? iconDisplayLarge,
    double? buttonHeightSmall,
    double? buttonHeightRegular,
    double? buttonHeightLarge,
  }) {
    return AppSizing(
      iconContainerSmall: iconContainerSmall ?? this.iconContainerSmall,
      iconContainerRegular: iconContainerRegular ?? this.iconContainerRegular,
      iconContainerLarge: iconContainerLarge ?? this.iconContainerLarge,
      iconContainerXLarge: iconContainerXLarge ?? this.iconContainerXLarge,
      iconXSmall: iconXSmall ?? this.iconXSmall,
      iconSmall: iconSmall ?? this.iconSmall,
      iconRegular: iconRegular ?? this.iconRegular,
      iconLarge: iconLarge ?? this.iconLarge,
      iconXLarge: iconXLarge ?? this.iconXLarge,
      iconDisplay: iconDisplay ?? this.iconDisplay,
      iconDisplayLarge: iconDisplayLarge ?? this.iconDisplayLarge,
      buttonHeightSmall: buttonHeightSmall ?? this.buttonHeightSmall,
      buttonHeightRegular: buttonHeightRegular ?? this.buttonHeightRegular,
      buttonHeightLarge: buttonHeightLarge ?? this.buttonHeightLarge,
    );
  }

  @override
  AppSizing lerp(AppSizing? other, double t) {
    if (other is! AppSizing) return this;
    return AppSizing(
      iconContainerSmall:
          lerpDouble(iconContainerSmall, other.iconContainerSmall, t)!,
      iconContainerRegular:
          lerpDouble(iconContainerRegular, other.iconContainerRegular, t)!,
      iconContainerLarge:
          lerpDouble(iconContainerLarge, other.iconContainerLarge, t)!,
      iconContainerXLarge:
          lerpDouble(iconContainerXLarge, other.iconContainerXLarge, t)!,
      iconXSmall: lerpDouble(iconXSmall, other.iconXSmall, t)!,
      iconSmall: lerpDouble(iconSmall, other.iconSmall, t)!,
      iconRegular: lerpDouble(iconRegular, other.iconRegular, t)!,
      iconLarge: lerpDouble(iconLarge, other.iconLarge, t)!,
      iconXLarge: lerpDouble(iconXLarge, other.iconXLarge, t)!,
      iconDisplay: lerpDouble(iconDisplay, other.iconDisplay, t)!,
      iconDisplayLarge:
          lerpDouble(iconDisplayLarge, other.iconDisplayLarge, t)!,
      buttonHeightSmall:
          lerpDouble(buttonHeightSmall, other.buttonHeightSmall, t)!,
      buttonHeightRegular:
          lerpDouble(buttonHeightRegular, other.buttonHeightRegular, t)!,
      buttonHeightLarge:
          lerpDouble(buttonHeightLarge, other.buttonHeightLarge, t)!,
    );
  }
}
