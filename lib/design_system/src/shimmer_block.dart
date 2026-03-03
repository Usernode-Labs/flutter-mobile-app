import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';

/// Provides a single shared [AnimationController] to descendant [ShimmerBlock]
/// widgets, eliminating redundant controllers when multiple blocks appear in
/// the same subtree (e.g. a wallet loading screen with 4 [ShimmerListTile]s).
///
/// Wrap the shimmer region once:
/// ```dart
/// ShimmerHost(
///   child: Column(children: List.generate(4, (_) => ShimmerListTile())),
/// )
/// ```
class ShimmerHost extends StatefulWidget {
  const ShimmerHost({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerHost> createState() => _ShimmerHostState();
}

class _ShimmerHostState extends State<ShimmerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.controller, required super.child});

  final AnimationController controller;

  static AnimationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_ShimmerScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      controller != oldWidget.controller;
}

/// A rounded rectangle with a continuous gradient-sweep animation.
///
/// The core shimmer primitive for content-first loading. Compose multiple
/// [ShimmerBlock]s to build skeleton placeholders that match real layout
/// structure, giving users immediate spatial context during data loading.
///
/// When placed inside a [ShimmerHost], shares a single animation controller
/// with all sibling blocks. Otherwise creates its own controller.
///
/// Colors are derived from [ColorScheme] surface container tones:
/// - **base** = `surfaceContainerHighest`
/// - **highlight** = `Color.lerp(base, surfaceContainerLowest, t)`
///   where *t* = 0.45 in light mode, −0.45 in dark mode (negative lerp
///   extrapolates away from the darker anchor, producing a symmetric lift).
///
/// Respects [MediaQueryData.disableAnimations] — renders a static block
/// when reduced motion is preferred.
class ShimmerBlock extends StatefulWidget {
  const ShimmerBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  /// Width of the placeholder rectangle.
  final double width;

  /// Height of the placeholder rectangle.
  final double height;

  /// Corner rounding. Defaults to [AppRadii.borderRadiusSmall].
  final BorderRadius? borderRadius;

  @override
  State<ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<ShimmerBlock>
    with SingleTickerProviderStateMixin {
  AnimationController? _ownController;

  AnimationController _resolveController() {
    final host = _ShimmerScope.maybeOf(context);
    if (host != null) return host;
    return _ownController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radii = Theme.of(context).extension<AppRadii>()!;
    final colors = Theme.of(context).colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final borderRadius = widget.borderRadius ?? radii.borderRadiusSmall;
    final baseColor = colors.surfaceContainerHighest;

    if (reduceMotion) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: borderRadius,
          ),
        ),
      );
    }

    final controller = _resolveController();

    final highlightColor = Color.lerp(
      baseColor,
      colors.surfaceContainerLowest,
      colors.brightness == Brightness.light ? 0.45 : -0.45,
    )!;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final slide = controller.value * 2 - 0.5;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: [
                  (slide - 0.2).clamp(0.0, 1.0),
                  slide.clamp(0.0, 1.0),
                  (slide + 0.2).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            child: child,
          ),
        );
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
