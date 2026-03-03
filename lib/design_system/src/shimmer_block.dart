import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';

/// A rounded rectangle with a continuous gradient-sweep animation.
///
/// The core shimmer primitive for content-first loading. Compose multiple
/// [ShimmerBlock]s to build skeleton placeholders that match real layout
/// structure, giving users immediate spatial context during data loading.
///
/// Colors are derived from the theme:
/// - base: [ColorScheme.surfaceContainerHighest]
/// - highlight: [ColorScheme.surfaceContainerLowest]
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Longer than AppAnimation tokens — shimmer is ambient, not a state
    // transition (same rationale as HeartbeatAnimation).
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
    final colors = Theme.of(context).colorScheme;
    final radii = Theme.of(context).extension<AppRadii>()!;
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

    final highlightColor = colors.surfaceContainerLowest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final slide = _controller.value * 2 - 0.5;
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [baseColor, highlightColor, baseColor],
                stops: [
                  (slide - 0.3).clamp(0.0, 1.0),
                  slide.clamp(0.0, 1.0),
                  (slide + 0.3).clamp(0.0, 1.0),
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
