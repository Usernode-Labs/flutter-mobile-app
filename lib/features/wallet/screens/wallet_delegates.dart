import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/core/utils/utils.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:crypto_mobile_app/design_system/src/parallax_surface_layout.dart';

/// Address bar content height — matches [kChipHeight] in challenges_delegates.
const kAddressBarHeight = 32.0;

// ---------------------------------------------------------------------------
// AddressBarDelegate — pinned address bar with lerping background
// ---------------------------------------------------------------------------

class AddressBarDelegate extends SliverPersistentHeaderDelegate {
  AddressBarDelegate({
    required this.topPadding,
    required this.spacing,
    required this.scrollFractionNotifier,
    required this.address,
    required this.onCopy,
  });

  final double topPadding;
  final AppSpacing spacing;
  final ValueNotifier<double> scrollFractionNotifier;
  final String address;
  final VoidCallback onCopy;

  @override
  double get maxExtent =>
      topPadding + spacing.space8 + kAddressBarHeight + spacing.space8;

  @override
  double get minExtent => maxExtent;

  /// Computes the total pinned height for a given [topPadding] and [spacing].
  ///
  /// Use this when passing [pinnedHeaderHeight] to [ParallaxSurfaceLayout]
  /// so the formula lives in one place.
  static double computeHeight(double topPadding, AppSpacing spacing) =>
      topPadding + spacing.space8 + kAddressBarHeight + spacing.space8;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: scrollFractionNotifier,
      builder: (context, scrollFraction, child) {
        final bgColor = Color.lerp(
          colorScheme.surface,
          colorScheme.surfaceContainerLowest,
          scrollFraction,
        )!;

        return ColoredBox(
          color: bgColor,
          child: Padding(
            padding: EdgeInsets.only(
              top: topPadding + spacing.space8,
              left: spacing.space16,
              right: spacing.space16,
              bottom: spacing.space8,
            ),
            child: _AddressBarContent(
              address: address,
              onCopy: onCopy,
            ),
          ),
        );
      },
    );
  }

  @override
  bool shouldRebuild(AddressBarDelegate oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// _AddressBarContent — tappable address row with copy icon
// ---------------------------------------------------------------------------

class _AddressBarContent extends StatelessWidget {
  const _AddressBarContent({
    required this.address,
    required this.onCopy,
  });

  final String address;
  final VoidCallback onCopy;

  String get _displayAddress => Utils.shortenID(address, head: 8, tail: 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final radii = theme.extension<AppRadii>()!;
    final sizing = theme.extension<AppSizing>()!;

    return GestureDetector(
      onTap: onCopy,
      child: Container(
        height: kAddressBarHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: radii.borderRadiusSmall,
        ),
        padding: EdgeInsets.only(
          left: spacing.space16,
          right: spacing.space8,
        ),
        child: Row(
          children: [
            Text(
              AppLocalizations.of(context).walletMyAddress,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: spacing.space8),
            Expanded(
              child: Text(
                _displayAddress,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: kMonoFontFamily,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: spacing.space8),
            Icon(
              Symbols.content_copy_sharp,
              size: sizing.iconSmall,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
