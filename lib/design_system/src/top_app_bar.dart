import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';
import 'hero_shuttle_builders.dart';

/// The size variant of a [TopAppBar].
enum TopAppBarSize {
  /// Standard 56px M3 top app bar.
  small,

  /// Expanded header with image + subtitle that collapses to small on scroll.
  large,
}

/// A sliver-based top app bar with two size variants.
///
/// **Small**: standard 56px M3 top app bar with leading, title, and trailing
/// actions.
///
/// **Large**: expanded header with optional image, display title, and subtitle
/// that collapses to the small layout on scroll. The expanded content fades out
/// and the title transitions from [TextTheme.displaySmall] to
/// [TextTheme.titleLarge].
///
/// Must be placed inside a [CustomScrollView] or [NestedScrollView].
/// Does not implement [PreferredSizeWidget].
class TopAppBar extends StatelessWidget {
  /// Creates a top app bar.
  const TopAppBar({
    super.key,
    required this.title,
    this.size = TopAppBarSize.small,
    this.leading,
    this.onLeadingTap,
    this.actions,
    this.image,
    this.subtitle,
    this.titleHeroTag,
    this.imageHeroTag,
  });

  /// Primary title text.
  final String title;

  /// Bar size variant.
  final TopAppBarSize size;

  /// Leading widget. Defaults to a back arrow [IconButton].
  final Widget? leading;

  /// Callback for the default back arrow. Ignored if [leading] is provided.
  final VoidCallback? onLeadingTap;

  /// Trailing action widgets (icon buttons, chips, etc.).
  final List<Widget>? actions;

  /// Large variant only — 64px content area (challenge icon, avatar, etc.).
  final Widget? image;

  /// Large variant only — secondary text line below the title.
  final String? subtitle;

  /// When non-null, wraps the expanded title [Text] in a [Hero] with this tag.
  final String? titleHeroTag;

  /// When non-null, wraps the image in a [Hero] with this tag.
  final String? imageHeroTag;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TopAppBarSize.small => _buildSmall(context),
      TopAppBarSize.large => _buildLarge(context),
    };
  }

  Widget _buildLeading(BuildContext context) {
    if (leading != null) return leading!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    return IconButton(
      onPressed: onLeadingTap,
      icon: Icon(Icons.arrow_back, size: sizing.iconRegular),
    );
  }

  Widget _buildSmall(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SliverAppBar(
      pinned: true,
      backgroundColor: colors.surface,
      scrolledUnderElevation: 0,
      leading: _buildLeading(context),
      titleSpacing: 0,
      title: Text(
        title,
        style: textTheme.titleLarge?.copyWith(color: colors.onSurface),
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
    );
  }

  Widget _buildLarge(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight(context),
      forceMaterialTransparency: true,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight,
      titleSpacing: 0,
      flexibleSpace: _LargeFlexibleContent(
        title: title,
        subtitle: subtitle,
        image: image,
        leading: _buildLeading(context),
        actions: actions,
        titleHeroTag: titleHeroTag,
        imageHeroTag: imageHeroTag,
      ),
    );
  }

  double _expandedHeight(BuildContext context) {
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    double height = kToolbarHeight;
    if (image != null) {
      height += sizing.iconContainerXLarge;
      height += spacing.space16;
    }
    // Text heights vary across platforms and text scalers. Generous estimates
    // prevent overflow; extra space becomes bottom whitespace.
    height += 72; // displaySmall: ~44px nominal + cross-platform buffer
    if (subtitle != null) {
      height += spacing.space8;
      height += 40; // titleMedium: ~24px nominal + cross-platform buffer
    }
    height += spacing.space12;
    return height;
  }
}

class _LargeFlexibleContent extends StatelessWidget {
  const _LargeFlexibleContent({
    required this.title,
    this.subtitle,
    this.image,
    this.leading,
    this.actions,
    this.titleHeroTag,
    this.imageHeroTag,
  });

  final String title;
  final String? subtitle;
  final Widget? image;
  final Widget? leading;
  final List<Widget>? actions;
  final String? titleHeroTag;
  final String? imageHeroTag;

  Widget _maybeHero({
    required String? tag,
    required Widget child,
    HeroFlightShuttleBuilder? flightShuttleBuilder,
  }) {
    if (tag == null) return child;
    return Hero(
      tag: tag,
      flightShuttleBuilder: flightShuttleBuilder,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    if (settings == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;

    final deltaExtent = settings.maxExtent - settings.minExtent;
    final t = deltaExtent > 0
        ? (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent)
            .clamp(0.0, 1.0)
        : 1.0;
    // t: 0.0 = fully expanded, 1.0 = fully collapsed.

    final topPadding = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: colors.surface,
      child: Stack(
        children: [
          // Toolbar row — always visible, title fades in on collapse.
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: kToolbarHeight,
            child: Row(
              children: [
                SizedBox(width: spacing.space4),
                if (leading != null) leading!,
                Expanded(
                  child: Opacity(
                    opacity: t,
                    child: Text(
                      title,
                      style: textTheme.titleLarge
                          ?.copyWith(color: colors.onSurface),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
                SizedBox(width: spacing.space4),
              ],
            ),
          ),
          // Expanded content — fades out on collapse.
          if (t < 1.0)
            Positioned(
              top: topPadding + kToolbarHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: Opacity(
                  opacity: 1.0 - t,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: spacing.space16,
                      right: spacing.space16,
                      bottom: spacing.space12,
                    ),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (image != null) ...[
                            _maybeHero(
                              tag: imageHeroTag,
                              child: ClipRRect(
                                borderRadius: radii.borderRadiusSmall,
                                child: SizedBox(
                                  width: sizing.iconContainerXLarge,
                                  height: sizing.iconContainerXLarge,
                                  child: image!,
                                ),
                              ),
                            ),
                            SizedBox(height: spacing.space16),
                          ],
                          _maybeHero(
                            tag: titleHeroTag,
                            flightShuttleBuilder: titleFlightShuttleBuilder,
                            child: Text(
                              title,
                              style: textTheme.displaySmall
                                  ?.copyWith(color: colors.onSurface),
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: spacing.space8),
                            Text(
                              subtitle!,
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
