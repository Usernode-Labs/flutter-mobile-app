import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies ThemeExtension token values match the existing const tokens
/// in lib/core/config/design_tokens.dart. Catches drift between the two.
void main() {
  group('AppSpacing parity', () {
    final spacing = AppSpacing.standard();

    test('space4 matches kSpace4', () => expect(spacing.space4, 4.0));
    test('space8 matches kSpace8', () => expect(spacing.space8, 8.0));
    test('space12 matches kSpace12', () => expect(spacing.space12, 12.0));
    test('space16 matches kSpace16', () => expect(spacing.space16, 16.0));
    test('space24 matches kSpace24', () => expect(spacing.space24, 24.0));
    test('space32 matches kSpace32', () => expect(spacing.space32, 32.0));
    test('space48 matches kSpace48', () => expect(spacing.space48, 48.0));
  });

  group('AppRadii parity', () {
    final radii = AppRadii.standard();

    test('small matches kRadiusSmall', () => expect(radii.small, 8.0));
    test('medium matches kRadiusMedium', () => expect(radii.medium, 12.0));
    test('large matches kRadiusLarge', () => expect(radii.large, 16.0));
    test('xLarge matches kRadiusXLarge', () => expect(radii.xLarge, 24.0));
    test('full matches kRadiusFull', () => expect(radii.full, 999.0));
  });

  group('AppElevation parity', () {
    final elevation = AppElevation.standard();

    test('none matches kElevationNone', () => expect(elevation.none, 0.0));
    test('low matches kElevationLow', () => expect(elevation.low, 1.0));
    test(
        'medium matches kElevationMedium', () => expect(elevation.medium, 2.0));
    test('high matches kElevationHigh', () => expect(elevation.high, 4.0));
    test('max matches kElevationMax', () => expect(elevation.max, 8.0));
  });

  group('AppOpacity parity', () {
    final opacity = AppOpacity.standard();

    test('subtle matches kAlphaSubtle', () => expect(opacity.subtle, 0.08));
    test('medium matches kAlphaMedium', () => expect(opacity.medium, 0.12));
    test('strong matches kAlphaStrong', () => expect(opacity.strong, 0.20));
    test('disabled matches kAlphaDisabled',
        () => expect(opacity.disabled, 0.30));
    test('secondary matches kAlphaSecondary',
        () => expect(opacity.secondary, 0.40));
  });

  group('AppSizing parity', () {
    final sizing = AppSizing.standard();

    test('iconContainerSmall matches kIconSizeSmall',
        () => expect(sizing.iconContainerSmall, 40.0));
    test('iconContainerRegular matches kIconSizeRegular',
        () => expect(sizing.iconContainerRegular, 48.0));
    test('iconContainerLarge matches kIconSizeLarge',
        () => expect(sizing.iconContainerLarge, 56.0));
    test('iconContainerXLarge matches kIconSizeXLarge',
        () => expect(sizing.iconContainerXLarge, 64.0));
    test('iconSmall matches kIconSmall', () => expect(sizing.iconSmall, 20.0));
    test('iconRegular matches kIconRegular',
        () => expect(sizing.iconRegular, 24.0));
    test('iconLarge matches kIconLarge', () => expect(sizing.iconLarge, 28.0));
    test('iconXLarge matches kIconXLarge',
        () => expect(sizing.iconXLarge, 32.0));
    test('buttonHeightSmall matches kButtonHeightSmall',
        () => expect(sizing.buttonHeightSmall, 40.0));
    test('buttonHeightRegular matches kButtonHeightRegular',
        () => expect(sizing.buttonHeightRegular, 48.0));
    test('buttonHeightLarge matches kButtonHeightLarge',
        () => expect(sizing.buttonHeightLarge, 56.0));
  });

  group('AppAnimation parity', () {
    final animation = AppAnimation.standard();

    test('fast matches kAnimationFast',
        () => expect(animation.fast, const Duration(milliseconds: 100)));
    test('normal matches kAnimationNormal',
        () => expect(animation.normal, const Duration(milliseconds: 150)));
    test('slow matches kAnimationSlow',
        () => expect(animation.slow, const Duration(milliseconds: 200)));
    test('complex matches kAnimationComplex',
        () => expect(animation.complex, const Duration(milliseconds: 300)));
  });

  group('copyWith', () {
    test('AppSpacing.copyWith preserves unset values', () {
      final spacing = AppSpacing.standard();
      final modified = spacing.copyWith(space16: 20.0);
      expect(modified.space16, 20.0);
      expect(modified.space8, 8.0);
    });

    test('AppRadii.copyWith preserves unset values', () {
      final radii = AppRadii.standard();
      final modified = radii.copyWith(large: 20.0);
      expect(modified.large, 20.0);
      expect(modified.small, 8.0);
    });

    test('AppElevation.copyWith preserves unset values', () {
      final elevation = AppElevation.standard();
      final modified = elevation.copyWith(high: 6.0);
      expect(modified.high, 6.0);
      expect(modified.low, 1.0);
    });

    test('AppOpacity.copyWith preserves unset values', () {
      final opacity = AppOpacity.standard();
      final modified = opacity.copyWith(strong: 0.25);
      expect(modified.strong, 0.25);
      expect(modified.subtle, 0.08);
    });

    test('AppSizing.copyWith preserves unset values', () {
      final sizing = AppSizing.standard();
      final modified = sizing.copyWith(iconRegular: 28.0);
      expect(modified.iconRegular, 28.0);
      expect(modified.iconSmall, 20.0);
    });

    test('AppAnimation.copyWith preserves unset values', () {
      final animation = AppAnimation.standard();
      final modified =
          animation.copyWith(fast: const Duration(milliseconds: 50));
      expect(modified.fast, const Duration(milliseconds: 50));
      expect(modified.normal, const Duration(milliseconds: 150));
    });
  });

  group('lerp', () {
    test('AppSpacing.lerp interpolates at midpoint', () {
      final a = AppSpacing.standard();
      final b = a.copyWith(space16: 32.0);
      final result = a.lerp(b, 0.5);
      expect(result.space16, 24.0);
    });

    test('AppRadii.lerp interpolates at midpoint', () {
      final a = AppRadii.standard();
      final b = a.copyWith(large: 32.0);
      final result = a.lerp(b, 0.5);
      expect(result.large, 24.0);
    });

    test('AppAnimation.lerp snaps at midpoint', () {
      final a = AppAnimation.standard();
      final b = a.copyWith(fast: const Duration(milliseconds: 200));
      expect(a.lerp(b, 0.4).fast, const Duration(milliseconds: 100));
      expect(a.lerp(b, 0.6).fast, const Duration(milliseconds: 200));
    });
  });
}
