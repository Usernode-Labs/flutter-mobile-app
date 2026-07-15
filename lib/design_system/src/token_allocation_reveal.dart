import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_borders.dart';
import '../tokens/app_opacity.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'button.dart';
import 'icon_badge.dart';

/// A season token allocation card whose amount stays hidden until revealed.
///
/// Hidden state is quiet and achromatic with an explicit "Reveal" button.
/// Pressing it spends the color budget on a premium celebration: the surface
/// tints, pulse rings emanate from the amount, and the value scales in — a
/// small win moment.
///
/// Presentation-only: [amount] arrives formatted; [onReveal] lets the
/// feature layer persist that the user has seen the allocation. Pass
/// [revealed] as true to render the settled revealed state without the
/// celebration (e.g. on revisit).
class TokenAllocationReveal extends StatefulWidget {
  const TokenAllocationReveal({
    super.key,
    required this.amount,
    this.label = 'Token Allocation',
    this.disclaimer,
    this.revealLabel = 'Reveal',
    this.icon = Symbols.redeem_sharp,
    this.revealed = false,
    this.onReveal,
  });

  /// Formatted token amount, e.g. "1,250".
  final String amount;

  /// Card title, e.g. "Token Allocation".
  final String label;

  /// Optional footnote under the card, e.g. allocation terms. Omitted when
  /// null so the card stays a plain amount reveal.
  final String? disclaimer;

  /// Label on the reveal button shown while the amount is hidden.
  final String revealLabel;

  /// Leading badge icon.
  final IconData icon;

  /// When true the card renders revealed with no celebration.
  final bool revealed;

  /// Called once when the user reveals the allocation.
  final VoidCallback? onReveal;

  @override
  State<TokenAllocationReveal> createState() => _TokenAllocationRevealState();
}

class _TokenAllocationRevealState extends State<TokenAllocationReveal>
    with SingleTickerProviderStateMixin {
  // Full celebration length. The tint settles within the first third
  // (matching AppAnimation.complex); rings and the amount pop use the rest.
  // The token scale caps at 300ms, too short for the whole sequence.
  static const _celebrationDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _celebrationDuration,
    );
    if (widget.revealed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(TokenAllocationReveal old) {
    super.didUpdateWidget(old);
    // Programmatic reveal (e.g. restored persisted state) settles without
    // replaying the celebration.
    if (widget.revealed && !old.revealed && !_controller.isAnimating) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleReveal() {
    HapticFeedback.lightImpact();
    widget.onReveal?.call();
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  /// Normalizes [t] into the [start]..[end] sub-interval of the timeline.
  double _seg(double t, double start, double end) =>
      ((t - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final premium = Theme.of(context).extension<AppSemanticColors>()!.premium;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final borders = Theme.of(context).extension<AppBorders>()!;
    final opacity = Theme.of(context).extension<AppOpacity>()!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final tint = Curves.easeOut.transform(_seg(t, 0.0, 0.33));
        final buttonOpacity = 1.0 - _seg(t, 0.0, 0.25);
        final amountOpacity = _seg(t, 0.15, 0.4);
        final amountScale =
            0.7 + 0.3 * Curves.easeOutBack.transform(_seg(t, 0.15, 0.65));

        final bg = Color.lerp(
            colors.surfaceContainerLowest, premium.colorContainer, tint)!;
        final border = colors.outlineVariant.withValues(alpha: 1.0 - tint);
        final fg =
            Color.lerp(colors.onSurface, premium.onColorContainer, tint)!;
        final fgDim = Color.lerp(colors.onSurfaceVariant,
            premium.onColorContainer.withValues(alpha: 0.8), tint)!;
        final badgeBg =
            Color.lerp(colors.secondaryContainer, premium.color, tint)!;
        final badgeFg =
            Color.lerp(colors.onSecondaryContainer, premium.onColor, tint)!;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radii.borderRadiusLargeIncreased,
            border: Border.all(color: border, width: borders.width),
          ),
          child: ClipRRect(
            borderRadius: radii.borderRadiusLargeIncreased,
            child: Stack(
              children: [
                if (t > 0.0 && t < 1.0)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RevealPulsePainter(
                        progress: t,
                        color: premium.color,
                        baseOpacity: opacity.secondary,
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.space16,
                    vertical: spacing.space12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconBadge(
                            icon: widget.icon,
                            backgroundColor: badgeBg,
                            iconColor: badgeFg,
                          ),
                          SizedBox(width: spacing.space16),
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleSmall?.copyWith(color: fg),
                            ),
                          ),
                          SizedBox(width: spacing.space16),
                          Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              if (t < 1.0)
                                Opacity(
                                  opacity: buttonOpacity,
                                  child: IgnorePointer(
                                    ignoring: t > 0.0,
                                    child: Button(
                                      label: widget.revealLabel,
                                      variant: ButtonVariant.tonal,
                                      onTap: t == 0.0 ? _handleReveal : null,
                                    ),
                                  ),
                                ),
                              if (t > 0.0)
                                Opacity(
                                  opacity: amountOpacity,
                                  child: Transform.scale(
                                    scale: amountScale,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      widget.amount,
                                      style: textTheme.headlineSmall?.copyWith(
                                        fontFamily: kMonoFontFamily,
                                        color: fg,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (widget.disclaimer != null) ...[
                        SizedBox(height: spacing.space8),
                        Text(
                          widget.disclaimer!,
                          style: textTheme.bodySmall?.copyWith(color: fgDim),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Staggered expanding rings emanating from the amount position, echoing
/// the BurstPulseIllustration ring language.
class _RevealPulsePainter extends CustomPainter {
  const _RevealPulsePainter({
    required this.progress,
    required this.color,
    required this.baseOpacity,
  });

  final double progress;
  final Color color;
  final double baseOpacity;

  // Ring birth offsets within the celebration timeline; decorative painter
  // internals, kept local like BurstPulseIllustration's ring constants.
  static const _delays = [0.0, 0.12, 0.24];

  // Rings emanate from the trailing amount region of the card.
  static const _origin = Alignment(0.75, 0.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = _origin.alongSize(size);
    final maxRadius = size.width * 0.5;

    for (final delay in _delays) {
      final local = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (local <= 0.0 || local >= 1.0) continue;

      final radius = maxRadius * Curves.easeOut.transform(local);
      final ringOpacity = baseOpacity * (1.0 - Curves.easeIn.transform(local));
      if (radius <= 0.0 || ringOpacity <= 0.0) continue;

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: ringOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_RevealPulsePainter old) => old.progress != progress;
}
