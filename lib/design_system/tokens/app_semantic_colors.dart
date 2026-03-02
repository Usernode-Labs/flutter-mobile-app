import 'package:flutter/material.dart';

@immutable
class SemanticColorGroup {
  const SemanticColorGroup({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;

  SemanticColorGroup copyWith({
    Color? color,
    Color? onColor,
    Color? colorContainer,
    Color? onColorContainer,
  }) {
    return SemanticColorGroup(
      color: color ?? this.color,
      onColor: onColor ?? this.onColor,
      colorContainer: colorContainer ?? this.colorContainer,
      onColorContainer: onColorContainer ?? this.onColorContainer,
    );
  }

  static SemanticColorGroup lerp(
    SemanticColorGroup a,
    SemanticColorGroup b,
    double t,
  ) {
    return SemanticColorGroup(
      color: Color.lerp(a.color, b.color, t)!,
      onColor: Color.lerp(a.onColor, b.onColor, t)!,
      colorContainer: Color.lerp(a.colorContainer, b.colorContainer, t)!,
      onColorContainer: Color.lerp(a.onColorContainer, b.onColorContainer, t)!,
    );
  }
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.technical,
    required this.flash,
    required this.community,
    required this.success,
    required this.warning,
  });

  final SemanticColorGroup technical;
  final SemanticColorGroup flash;
  final SemanticColorGroup community;
  final SemanticColorGroup success;

  /// General-purpose warning status (syncing, permissions needed, etc.).
  /// Distinct from [flash] which is challenge-category specific.
  final SemanticColorGroup warning;

  // ---------------------------------------------------------------------------
  // Factory constructors — values from material-theme.json extendedColors
  // ---------------------------------------------------------------------------

  factory AppSemanticColors.light() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF0055D9),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFD3D9FF),
          onColorContainer: Color(0xFF0040BD),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF875300),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFD87B),
          onColorContainer: Color(0xFF774500),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF146D32),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFB6F0BE),
          onColorContainer: Color(0xFF05652B),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF1A6D23),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFBAF1B4),
          onColorContainer: Color(0xFF12681E),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF9C5700),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFDDB3),
          onColorContainer: Color(0xFF874900),
        ),
      );

  factory AppSemanticColors.lightMediumContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF003EBA),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF486DED),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF6C3C00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFA36C00),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF00541D),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF3C864D),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF00540C),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF408640),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF7A4100),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFB87200),
          onColorContainer: Color(0xFFFFFFFF),
        ),
      );

  factory AppSemanticColors.lightHighContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF002A8F),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF003EBA),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF502700),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF6C3C00),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF003B0D),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF00541D),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF003B00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF00540C),
          onColorContainer: Color(0xFFFFFFFF),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF5C2E00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF7A4100),
          onColorContainer: Color(0xFFFFFFFF),
        ),
      );

  factory AppSemanticColors.dark() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFAEBCFF),
          onColor: Color(0xFF002A8F),
          colorContainer: Color(0xFF003EBA),
          onColorContainer: Color(0xFFCBD1FF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFBBB4B),
          onColor: Color(0xFF502700),
          colorContainer: Color(0xFF6C3C00),
          onColorContainer: Color(0xFFFFCA69),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF92D69C),
          onColor: Color(0xFF003B0D),
          colorContainer: Color(0xFF00541D),
          onColorContainer: Color(0xFFA2E0AB),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF95D690),
          onColor: Color(0xFF003B00),
          colorContainer: Color(0xFF00540C),
          onColorContainer: Color(0xFFA5E0A0),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFB95D),
          onColor: Color(0xFF5C2E00),
          colorContainer: Color(0xFF7A4100),
          onColorContainer: Color(0xFFFFD5A0),
        ),
      );

  factory AppSemanticColors.darkMediumContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFD3D9FF),
          onColor: Color(0xFF002076),
          colorContainer: Color(0xFF6286FF),
          onColorContainer: Color(0xFF000000),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFFD87B),
          onColor: Color(0xFF431D00),
          colorContainer: Color(0xFFC38400),
          onColorContainer: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFFB6F0BE),
          onColor: Color(0xFF002E05),
          colorContainer: Color(0xFF50A162),
          onColorContainer: Color(0xFF000000),
        ),
        success: SemanticColorGroup(
          color: Color(0xFFBAF1B4),
          onColor: Color(0xFF002E00),
          colorContainer: Color(0xFF54A153),
          onColorContainer: Color(0xFF000000),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFDDB3),
          onColor: Color(0xFF4A2200),
          colorContainer: Color(0xFFD49200),
          onColorContainer: Color(0xFF000000),
        ),
      );

  factory AppSemanticColors.darkHighContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFEEEDFF),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFAEBCFF),
          onColorContainer: Color(0xFF100F1F),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFFEDC9),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFFBBB4B),
          onColorContainer: Color(0xFF1B0F00),
        ),
        community: SemanticColorGroup(
          color: Color(0xFFE0F6E2),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFF92D69C),
          onColorContainer: Color(0xFF081409),
        ),
        success: SemanticColorGroup(
          color: Color(0xFFE2F7DE),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFF95D690),
          onColorContainer: Color(0xFF091406),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFEEDA),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFFFB95D),
          onColorContainer: Color(0xFF1E0F00),
        ),
      );

  @override
  AppSemanticColors copyWith({
    SemanticColorGroup? technical,
    SemanticColorGroup? flash,
    SemanticColorGroup? community,
    SemanticColorGroup? success,
    SemanticColorGroup? warning,
  }) {
    return AppSemanticColors(
      technical: technical ?? this.technical,
      flash: flash ?? this.flash,
      community: community ?? this.community,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      technical: SemanticColorGroup.lerp(technical, other.technical, t),
      flash: SemanticColorGroup.lerp(flash, other.flash, t),
      community: SemanticColorGroup.lerp(community, other.community, t),
      success: SemanticColorGroup.lerp(success, other.success, t),
      warning: SemanticColorGroup.lerp(warning, other.warning, t),
    );
  }
}
