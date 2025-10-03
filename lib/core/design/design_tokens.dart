import 'package:flutter/widgets.dart';

/// Design tokens for consistent spacing, sizing, and styling across the app
/// Following 8pt grid system and Material Design 3 principles

// ============================================================================
// SPACING (8pt grid system)
// ============================================================================

/// 4px - Extra small spacing (tight gaps, icon margins)
const double kSpace4 = 4.0;

/// 8px - Small spacing (compact layouts, list item gaps)
const double kSpace8 = 8.0;

/// 12px - Medium spacing (form field gaps, card content)
const double kSpace12 = 12.0;

/// 16px - Regular spacing (default padding, section gaps)
const double kSpace16 = 16.0;

/// 24px - Large spacing (section separators, major gaps)
const double kSpace24 = 24.0;

/// 32px - Extra large spacing (major sections, screen padding)
const double kSpace32 = 32.0;

/// 48px - XXL spacing (major section breaks)
const double kSpace48 = 48.0;

// ============================================================================
// BORDER RADIUS
// ============================================================================

/// 8px - Small radius (chips, small buttons)
const double kRadiusSmall = 8.0;

/// 12px - Medium radius (input fields, compact cards)
const double kRadiusMedium = 12.0;

/// 16px - Large radius (cards, containers)
const double kRadiusLarge = 16.0;

/// 24px - Extra large radius (modal sheets, large cards)
const double kRadiusXLarge = 24.0;

/// 999px - Full radius (fully rounded buttons, pills)
const double kRadiusFull = 999.0;

// ============================================================================
// ELEVATION
// ============================================================================

/// 0dp - No elevation (flat surfaces)
const double kElevationNone = 0.0;

/// 1dp - Low elevation (cards, subtle depth)
const double kElevationLow = 1.0;

/// 2dp - Medium elevation (raised buttons, active states)
const double kElevationMedium = 2.0;

/// 4dp - High elevation (modals, dialogs, bottom sheets)
const double kElevationHigh = 4.0;

/// 8dp - Maximum elevation (floating action buttons)
const double kElevationMax = 8.0;

// ============================================================================
// OPACITY/ALPHA VALUES
// ============================================================================

/// 0.08 - Subtle transparency (hover states)
const double kAlphaSubtle = 0.08;

/// 0.12 - Medium transparency (inactive icons, backgrounds)
const double kAlphaMedium = 0.12;

/// 0.20 - Strong transparency (overlays, scrim)
const double kAlphaStrong = 0.20;

/// 0.30 - Disabled state
const double kAlphaDisabled = 0.30;

/// 0.40 - Secondary content
const double kAlphaSecondary = 0.40;

// ============================================================================
// SIZING
// ============================================================================

/// 40px - Small icon container
const double kIconSizeSmall = 40.0;

/// 48px - Regular tap target (minimum for accessibility)
const double kIconSizeRegular = 48.0;

/// 56px - Large tap target (prominent actions)
const double kIconSizeLarge = 56.0;

/// 64px - Extra large tap target (FAB, primary actions)
const double kIconSizeXLarge = 64.0;

/// 20px - Small icon
const double kIconSmall = 20.0;

/// 24px - Regular icon
const double kIconRegular = 24.0;

/// 28px - Large icon
const double kIconLarge = 28.0;

/// 32px - Extra large icon
const double kIconXLarge = 32.0;

// ============================================================================
// ANIMATION DURATIONS
// ============================================================================

/// 100ms - Quick transitions (micro-interactions)
const Duration kAnimationFast = Duration(milliseconds: 100);

/// 150ms - Standard transitions (most UI changes)
const Duration kAnimationNormal = Duration(milliseconds: 150);

/// 200ms - Slower transitions (complex animations)
const Duration kAnimationSlow = Duration(milliseconds: 200);

/// 300ms - Complex animations (page transitions)
const Duration kAnimationComplex = Duration(milliseconds: 300);

// ============================================================================
// BUTTON HEIGHTS
// ============================================================================

/// 40px - Small button
const double kButtonHeightSmall = 40.0;

/// 48px - Regular button
const double kButtonHeightRegular = 48.0;

/// 56px - Large button
const double kButtonHeightLarge = 56.0;

// ============================================================================
// COMMON BORDER RADIUS CONFIGURATIONS
// ============================================================================

/// Small radius for all corners
const BorderRadius kBorderRadiusSmall = BorderRadius.all(Radius.circular(kRadiusSmall));

/// Medium radius for all corners
const BorderRadius kBorderRadiusMedium = BorderRadius.all(Radius.circular(kRadiusMedium));

/// Large radius for all corners
const BorderRadius kBorderRadiusLarge = BorderRadius.all(Radius.circular(kRadiusLarge));

/// XLarge radius for all corners
const BorderRadius kBorderRadiusXLarge = BorderRadius.all(Radius.circular(kRadiusXLarge));

/// Full radius for all corners (pill shape)
const BorderRadius kBorderRadiusFull = BorderRadius.all(Radius.circular(kRadiusFull));

/// Top-only large radius (for bottom sheets, modals)
const BorderRadius kBorderRadiusTopLarge = BorderRadius.vertical(
  top: Radius.circular(kRadiusLarge),
);

/// Top-only XLarge radius (for bottom sheets, modals)
const BorderRadius kBorderRadiusTopXLarge = BorderRadius.vertical(
  top: Radius.circular(kRadiusXLarge),
);
