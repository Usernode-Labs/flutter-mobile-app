import 'package:flutter/material.dart';

@immutable
class SemanticColorGroup {
  const SemanticColorGroup({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
    required this.colorSurface,
    required this.onColorSurface,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;

  /// Large-area semantic surface.
  /// Most groups use a near-surface tint. Premium intentionally uses a
  /// saturated spotlight surface for featured rewards cards.
  final Color colorSurface;

  /// Text/icon color on [colorSurface].
  /// Usually chromatic to reinforce a subtle surface; premium uses black on
  /// yellow for a deliberate spotlight.
  final Color onColorSurface;

  SemanticColorGroup copyWith({
    Color? color,
    Color? onColor,
    Color? colorContainer,
    Color? onColorContainer,
    Color? colorSurface,
    Color? onColorSurface,
  }) {
    return SemanticColorGroup(
      color: color ?? this.color,
      onColor: onColor ?? this.onColor,
      colorContainer: colorContainer ?? this.colorContainer,
      onColorContainer: onColorContainer ?? this.onColorContainer,
      colorSurface: colorSurface ?? this.colorSurface,
      onColorSurface: onColorSurface ?? this.onColorSurface,
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
      colorSurface: Color.lerp(a.colorSurface, b.colorSurface, t)!,
      onColorSurface: Color.lerp(a.onColorSurface, b.onColorSurface, t)!,
    );
  }
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.technical,
    required this.flash,
    required this.premium,
    required this.community,
    required this.success,
    required this.warning,
    required this.internalNetwork,
  });

  final SemanticColorGroup technical;
  final SemanticColorGroup flash;

  /// Premium spotlight color for featured, high-value rewards surfaces.
  /// Distinct from [flash], which means time-limited energy or challenge type.
  final SemanticColorGroup premium;

  final SemanticColorGroup community;
  final SemanticColorGroup success;

  /// General-purpose warning status (syncing, permissions needed, etc.).
  /// Distinct from [flash] which is challenge-category specific.
  final SemanticColorGroup warning;

  /// Warm amber chrome marking a build pointed at a non-production (internal)
  /// network. Used for persistent app-shell affordances such as the bottom-nav
  /// backdrop, so an internal build is recognisable at a glance.
  ///
  /// [colorContainer] is the backdrop and [color] the hairline border. Unlike
  /// the other groups, [colorContainer] holds the same hex across contrast
  /// modes — the tint is an identity marker, so it must stay recognisable
  /// rather than shift with contrast; only the foregrounds and border harden.
  ///
  /// Distinct from [warning], which flags a recoverable user-facing state.
  final SemanticColorGroup internalNetwork;

  // ---------------------------------------------------------------------------
  // Factory constructors — values from material-theme.json extendedColors
  // ---------------------------------------------------------------------------

  factory AppSemanticColors.light() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF0055D9),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFD3D9FF),
          onColorContainer: Color(0xFF0040BD),
          colorSurface: Color(0xFFE1E8F3),
          onColorSurface: Color(0xFF0055D9),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF875300),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFD87B),
          onColorContainer: Color(0xFF774500),
          colorSurface: Color(0xFFECE8E1),
          onColorSurface: Color(0xFF875300),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF146D32),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFB6F0BE),
          onColorContainer: Color(0xFF05652B),
          colorSurface: Color(0xFFE3EAE5),
          onColorSurface: Color(0xFF146D32),
        ),
        success: SemanticColorGroup(
          // #2E7D32 (Material Green 800): clearly reads as green at small
          // icon sizes on a light surface, while still passing WCAG AA
          // contrast (~5:1 on white). Was #1A6D23, which read almost olive.
          color: Color(0xFF2E7D32),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFBAF1B4),
          onColorContainer: Color(0xFF12681E),
          colorSurface: Color(0xFFE3EAE4),
          onColorSurface: Color(0xFF2E7D32),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF9C5700),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFDDB3),
          onColorContainer: Color(0xFF874900),
          colorSurface: Color(0xFFEEE8E1),
          onColorSurface: Color(0xFF9C5700),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFFE5C878),
          onColor: Color(0xFF3D2914),
          colorContainer: Color(0xFFFFF4E6),
          onColorContainer: Color(0xFF874900),
          colorSurface: Color(0xFFEEE8E1),
          onColorSurface: Color(0xFF874900),
        ),
      );

  factory AppSemanticColors.lightMediumContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF003EBA),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF486DED),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFD8DFEE),
          onColorSurface: Color(0xFF003EBA),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF6C3C00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFA36C00),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFE5DFD8),
          onColorSurface: Color(0xFF6C3C00),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF00541D),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF3C864D),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFD8E2DB),
          onColorSurface: Color(0xFF00541D),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF00540C),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF408640),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFD8E2D9),
          onColorSurface: Color(0xFF00540C),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF7A4100),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFB87200),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFE6DFD8),
          onColorSurface: Color(0xFF7A4100),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFFA8853A),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFF4E6),
          onColorContainer: Color(0xFF6B3900),
          colorSurface: Color(0xFFE6DFD8),
          onColorSurface: Color(0xFF6B3900),
        ),
      );

  factory AppSemanticColors.lightHighContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFF002A8F),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF003EBA),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFC9D0E3),
          onColorSurface: Color(0xFF002A8F),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFF502700),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF6C3C00),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFD7D0C9),
          onColorSurface: Color(0xFF502700),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF003B0D),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF00541D),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFC9D4CB),
          onColorSurface: Color(0xFF003B0D),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF003B00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF00540C),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFC9D4C9),
          onColorSurface: Color(0xFF003B00),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFF5C2E00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFF7A4100),
          onColorContainer: Color(0xFFFFFFFF),
          colorSurface: Color(0xFFD9D1C9),
          onColorSurface: Color(0xFF5C2E00),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFF6B4A00),
          onColor: Color(0xFFFFFFFF),
          colorContainer: Color(0xFFFFF4E6),
          onColorContainer: Color(0xFF3D2914),
          colorSurface: Color(0xFFD9D1C9),
          onColorSurface: Color(0xFF3D2914),
        ),
      );

  factory AppSemanticColors.dark() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFAEBCFF),
          onColor: Color(0xFF002A8F),
          colorContainer: Color(0xFF003EBA),
          onColorContainer: Color(0xFFCBD1FF),
          colorSurface: Color(0xFF27282D),
          onColorSurface: Color(0xFFAEBCFF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFBBB4B),
          onColor: Color(0xFF502700),
          colorContainer: Color(0xFF6C3C00),
          onColorContainer: Color(0xFFFFCA69),
          colorSurface: Color(0xFF2D281F),
          onColorSurface: Color(0xFFFBBB4B),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFF92D69C),
          onColor: Color(0xFF003B0D),
          colorContainer: Color(0xFF00541D),
          onColorContainer: Color(0xFFA2E0AB),
          colorSurface: Color(0xFF252A25),
          onColorSurface: Color(0xFF92D69C),
        ),
        success: SemanticColorGroup(
          color: Color(0xFF95D690),
          onColor: Color(0xFF003B00),
          colorContainer: Color(0xFF00540C),
          onColorContainer: Color(0xFFA5E0A0),
          colorSurface: Color(0xFF252A24),
          onColorSurface: Color(0xFF95D690),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFB95D),
          onColor: Color(0xFF5C2E00),
          colorContainer: Color(0xFF7A4100),
          onColorContainer: Color(0xFFFFD5A0),
          colorSurface: Color(0xFF2D2820),
          onColorSurface: Color(0xFFFFB95D),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFF8B7355),
          onColor: Color(0xFFFFF4E6),
          colorContainer: Color(0xFF3D2914),
          onColorContainer: Color(0xFFE5C878),
          colorSurface: Color(0xFF2D2820),
          onColorSurface: Color(0xFFE5C878),
        ),
      );

  factory AppSemanticColors.darkMediumContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFD3D9FF),
          onColor: Color(0xFF002076),
          colorContainer: Color(0xFF6286FF),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFF313236),
          onColorSurface: Color(0xFFD3D9FF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFFD87B),
          onColor: Color(0xFF431D00),
          colorContainer: Color(0xFFC38400),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFF363227),
          onColorSurface: Color(0xFFFFD87B),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFFB6F0BE),
          onColor: Color(0xFF002E05),
          colorContainer: Color(0xFF50A162),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFF2E352F),
          onColorSurface: Color(0xFFB6F0BE),
        ),
        success: SemanticColorGroup(
          color: Color(0xFFBAF1B4),
          onColor: Color(0xFF002E00),
          colorContainer: Color(0xFF54A153),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFF2E352D),
          onColorSurface: Color(0xFFBAF1B4),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFDDB3),
          onColor: Color(0xFF4A2200),
          colorContainer: Color(0xFFD49200),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFF36322D),
          onColorSurface: Color(0xFFFFDDB3),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFFB39A78),
          onColor: Color(0xFF2A1A08),
          colorContainer: Color(0xFF3D2914),
          onColorContainer: Color(0xFFF5DFA8),
          colorSurface: Color(0xFF36322D),
          onColorSurface: Color(0xFFF5DFA8),
        ),
      );

  factory AppSemanticColors.darkHighContrast() => const AppSemanticColors(
        technical: SemanticColorGroup(
          color: Color(0xFFEEEDFF),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFAEBCFF),
          onColorContainer: Color(0xFF100F1F),
          colorSurface: Color(0xFF414144),
          onColorSurface: Color(0xFFEEEDFF),
        ),
        flash: SemanticColorGroup(
          color: Color(0xFFFFEDC9),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFFBBB4B),
          onColorContainer: Color(0xFF1B0F00),
          colorSurface: Color(0xFF44413A),
          onColorSurface: Color(0xFFFFEDC9),
        ),
        premium: SemanticColorGroup(
          color: Color(0xFF000000),
          onColor: Color(0xFFFFC900),
          colorContainer: Color(0xFFFFF3D2),
          onColorContainer: Color(0xFF000000),
          colorSurface: Color(0xFFFFC900),
          onColorSurface: Color(0xFF000000),
        ),
        community: SemanticColorGroup(
          color: Color(0xFFE0F6E2),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFF92D69C),
          onColorContainer: Color(0xFF081409),
          colorSurface: Color(0xFF3E423F),
          onColorSurface: Color(0xFFE0F6E2),
        ),
        success: SemanticColorGroup(
          color: Color(0xFFE2F7DE),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFF95D690),
          onColorContainer: Color(0xFF091406),
          colorSurface: Color(0xFF3F433E),
          onColorSurface: Color(0xFFE2F7DE),
        ),
        warning: SemanticColorGroup(
          color: Color(0xFFFFEEDA),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFFFFB95D),
          onColorContainer: Color(0xFF1E0F00),
          colorSurface: Color(0xFF44413D),
          onColorSurface: Color(0xFFFFEEDA),
        ),
        internalNetwork: SemanticColorGroup(
          color: Color(0xFFFFEEDA),
          onColor: Color(0xFF000000),
          colorContainer: Color(0xFF3D2914),
          onColorContainer: Color(0xFFFFF4E6),
          colorSurface: Color(0xFF44413D),
          onColorSurface: Color(0xFFFFEEDA),
        ),
      );

  @override
  AppSemanticColors copyWith({
    SemanticColorGroup? technical,
    SemanticColorGroup? flash,
    SemanticColorGroup? premium,
    SemanticColorGroup? community,
    SemanticColorGroup? success,
    SemanticColorGroup? warning,
    SemanticColorGroup? internalNetwork,
  }) {
    return AppSemanticColors(
      technical: technical ?? this.technical,
      flash: flash ?? this.flash,
      premium: premium ?? this.premium,
      community: community ?? this.community,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      internalNetwork: internalNetwork ?? this.internalNetwork,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      technical: SemanticColorGroup.lerp(technical, other.technical, t),
      flash: SemanticColorGroup.lerp(flash, other.flash, t),
      premium: SemanticColorGroup.lerp(premium, other.premium, t),
      community: SemanticColorGroup.lerp(community, other.community, t),
      success: SemanticColorGroup.lerp(success, other.success, t),
      warning: SemanticColorGroup.lerp(warning, other.warning, t),
      internalNetwork: SemanticColorGroup.lerp(
        internalNetwork,
        other.internalNetwork,
        t,
      ),
    );
  }
}
