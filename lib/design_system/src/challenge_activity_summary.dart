import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens/app_radii.dart';
import '../tokens/app_semantic_colors.dart';
import '../tokens/app_sizing.dart';
import '../tokens/app_spacing.dart';

class ChallengeActivitySummary extends StatelessWidget {
  const ChallengeActivitySummary({
    super.key,
    required this.completedCount,
    required this.missedCount,
    required this.totalCount,
    this.onViewCompleted,
    this.onViewMissed,
  });

  final int completedCount;
  final int missedCount;
  final int totalCount;
  final VoidCallback? onViewCompleted;
  final VoidCallback? onViewMissed;

  String get _headline {
    if (completedCount > 0) return 'All caught up!';
    if (missedCount > 0) return 'No challenges completed';
    return 'No challenges yet';
  }

  String get _summary {
    if (totalCount > 0) {
      final tackled = completedCount + missedCount;
      return "You've tackled $tackled of $totalCount challenges this season.";
    }
    return 'Check back soon for new challenges.';
  }

  static final _cache = <String, SvgPicture>{};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final spacing = Theme.of(context).extension<AppSpacing>()!;
    final radii = Theme.of(context).extension<AppRadii>()!;
    final sizing = Theme.of(context).extension<AppSizing>()!;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    final fcHex = _toHex(semantic.flash.color);
    final tcHex = _toHex(semantic.technical.color);
    final ccHex = _toHex(semantic.community.color);
    final sHex = _toHex(colors.onSurface);

    final cacheKey = '$fcHex|$tcHex|$ccHex|$sHex';
    final illustration = _cache[cacheKey] ??
        (_cache[cacheKey] = SvgPicture.string(
          _trioSvg
              .replaceAll('{{FC}}', fcHex)
              .replaceAll('{{TC}}', tcHex)
              .replaceAll('{{CC}}', ccHex)
              .replaceAll('{{S}}', sHex),
        ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: Center(child: illustration),
        ),
        SizedBox(height: spacing.space8),
        Text(
          _headline,
          style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.space8),
        Text(
          _summary,
          style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: spacing.space12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.check_circle,
                  label: '$completedCount Done',
                  iconColor: colors.onSurface,
                  textColor: colors.onSurface,
                  backgroundColor: colors.surfaceContainerLow,
                  borderRadius: radii.full,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewCompleted,
                ),
              ),
            ),
            SizedBox(width: spacing.space12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: IntrinsicWidth(
                child: _Pill(
                  icon: Symbols.disabled_by_default,
                  label: '$missedCount Missed',
                  iconColor: colors.onSurfaceVariant,
                  textColor: colors.onSurfaceVariant,
                  backgroundColor: colors.surfaceContainerLow,
                  borderRadius: radii.full,
                  spacing: spacing,
                  sizing: sizing,
                  onTap: onViewMissed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _toHex(Color color) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// SVG template – horizontal trio illustration
// ---------------------------------------------------------------------------
// {{FC}} = flash color, {{TC}} = technical color, {{CC}} = community color,
// {{S}} = stroke color (onSurface).

const _trioSvg = '<svg width="248" height="121" viewBox="0 0 248 121"'
    ' fill="none" xmlns="http://www.w3.org/2000/svg">'
    // Flash – circle (left)
    '<path d="M36.3351 89.7928C52.6073 89.7928 65.7984 76.6017 65.7984'
    ' 60.3295C65.7984 44.0574 52.6073 30.8662 36.3351 30.8662C20.063'
    ' 30.8662 6.87183 44.0574 6.87183 60.3295C6.87183 76.6017 20.063'
    ' 89.7928 36.3351 89.7928Z" fill="{{FC}}" fill-opacity="0.2"/>'
    '<path d="M36.3342 96.6684C56.4011 96.6684 72.6684 80.4011 72.6684'
    ' 60.3342C72.6684 40.2674 56.4011 24 36.3342 24C16.2674 24 0 40.2674'
    ' 0 60.3342C0 80.4011 16.2674 96.6684 36.3342 96.6684Z"'
    ' fill="{{FC}}" fill-opacity="0.1"/>'
    '<path d="M36.8488 78.5012C46.8822 78.5012 55.0159 70.3675 55.0159'
    ' 60.3341C55.0159 50.3007 46.8822 42.167 36.8488 42.167C26.8153'
    ' 42.167 18.6816 50.3007 18.6816 60.3341C18.6816 70.3675 26.8153'
    ' 78.5012 36.8488 78.5012Z" stroke="{{S}}" stroke-opacity="0.8"'
    ' stroke-linecap="round" stroke-dasharray="4 4"/>'
    // Technical – hexagon (center)
    '<path d="M114.054 34.0889L141.304 38.4265L151.247 64.6704L133.939'
    ' 86.5767L106.688 82.239L96.7456 55.9951L114.054 34.0889Z"'
    ' fill="{{TC}}" fill-opacity="0.2"/>'
    '<path d="M117.019 94.6549L94.0814 79.3738L88.6685 52.3502L103.95'
    ' 29.4129L130.973 24L153.91 39.2811L159.323 66.3047L144.042'
    ' 89.242L117.019 94.6549Z" fill="{{TC}}" fill-opacity="0.1"/>'
    '<path d="M129.984 42.1748L141.149 54.0257L138.901 70.1958L124.933'
    ' 78.509L109.763 72.7056L104.815 57.1555L113.814 43.5677L129.984'
    ' 42.1748Z" stroke="{{S}}"/>'
    // Community – blob (right)
    '<path d="M244.564 60.4778C244.461 61.0429 243.996 61.8341 243.945'
    ' 63.8686C243.894 65.903 244.367 70.6729 244.259 72.6841C244.151'
    ' 74.6953 243.752 74.8729 243.296 75.9353C242.84 76.9977 242.466'
    ' 77.8822 241.525 79.0583C240.583 80.2344 239.623 81.5616 237.647'
    ' 82.9914C235.671 84.4209 231.998 85.8787 229.671 87.6364C227.344'
    ' 89.3941 225.341 92.2831 223.688 93.5373C222.035 94.7913 220.956'
    ' 94.9311 219.752 95.161C218.549 95.391 218.248 95.3299 216.467'
    ' 94.9175C214.685 94.505 211.941 93.0197 209.064 92.6865C206.187'
    ' 92.3534 201.736 93.2289 199.205 92.9185C196.673 92.6081 195.536'
    ' 91.8686 193.875 90.8248C192.215 89.781 190.771 88.6592 189.243'
    ' 86.655C187.715 84.6509 186.545 81.2395 184.705 78.7993C182.866'
    ' 76.3591 179.519 73.7422 178.207 72.0138C176.894 70.2855 177.019'
    ' 69.5736 176.83 68.4284C176.642 67.2831 176.661 66.9238 177.074'
    ' 65.1426C177.486 63.3613 178.975 60.6002 179.305 57.7403C179.635'
    ' 54.8803 178.755 50.5002 179.056 47.9832C179.357 45.4663 180.455'
    ' 43.9557 181.112 42.6383C181.77 41.3213 182.296 40.8667 183'
    ' 40.0801C183.704 39.2935 183.638 39.0351 185.336 37.9189C187.035'
    ' 36.8025 190.752 35.2209 193.192 33.3815C195.632 31.5421 198.249'
    ' 28.195 199.977 26.8823C201.706 25.57 202.418 25.6952 203.563'
    ' 25.5063C204.708 25.3177 205.067 25.3374 206.849 25.7499C208.63'
    ' 26.1623 211.788 27.6785 214.251 27.9808C216.714 28.2834 219.896'
    ' 27.5875 221.624 27.5651C223.353 27.5428 223.526 27.5843 224.62'
    ' 27.8459C225.714 28.1075 227.012 28.5305 228.189 29.1354C229.365'
    ' 29.74 230.599 30.5207 231.679 31.4741C232.758 32.4272 233.492'
    ' 33.097 234.667 34.8547C235.841 36.6124 237.15 39.9319 238.725'
    ' 42.0201C240.299 44.1085 242.913 46.0337 244.113 47.385C245.312'
    ' 48.7367 245.529 48.9861 245.923 50.1296C246.316 51.2734 246.699'
    ' 52.5227 246.473 54.2473C246.246 55.9718 244.882 59.4393 244.564'
    ' 60.4778C244.667 59.9128 244.246 61.5164 244.564 60.4778Z"'
    ' fill="{{CC}}" fill-opacity="0.1"/>'
    '<path d="M237.366 60.44C237.286 60.8806 236.923 61.4975 236.883'
    ' 63.0837C236.843 64.6699 237.212 68.3889 237.128 69.957C237.044'
    ' 71.5251 236.732 71.6635 236.376 72.4919C236.02 73.3202 235.729'
    ' 74.0099 234.994 74.9268C234.259 75.8438 233.509 76.8786 231.967'
    ' 77.9934C230.425 79.108 227.557 80.2445 225.741 81.615C223.925'
    ' 82.9854 222.361 85.2379 221.071 86.2158C219.781 87.1935 218.939'
    ' 87.3025 217.999 87.4818C217.06 87.6611 216.825 87.6135 215.434'
    ' 87.2919C214.044 86.9703 211.902 85.8122 209.657 85.5525C207.411'
    ' 85.2928 203.937 85.9754 201.961 85.7333C199.985 85.4913 199.097'
    ' 84.9147 197.801 84.1009C196.505 83.2871 195.378 82.4125 194.185'
    ' 80.8499C192.992 79.2872 192.079 76.6275 190.643 74.7249C189.208'
    ' 72.8223 186.595 70.7819 185.571 69.4344C184.546 68.0868 184.644'
    ' 67.5318 184.497 66.6389C184.349 65.7459 184.365 65.4658 184.687'
    ' 64.077C185.009 62.6882 186.17 60.5354 186.428 58.3056C186.686'
    ' 56.0758 185.998 52.6606 186.234 50.6982C186.469 48.7358 187.326'
    ' 47.558 187.839 46.5309C188.352 45.504 188.763 45.1496 189.313'
    ' 44.5363C189.862 43.923 189.81 43.7216 191.136 42.8513C192.462'
    ' 41.9808 195.363 40.7477 197.268 39.3136C199.172 37.8794 201.215'
    ' 35.2698 202.564 34.2463C203.913 33.223 204.469 33.3207 205.363'
    ' 33.1734C206.257 33.0263 206.537 33.0417 207.927 33.3633C209.318'
    ' 33.6849 211.783 34.867 213.705 35.1027C215.627 35.3387 218.112'
    ' 34.7961 219.46 34.7786C220.809 34.7612 220.945 34.7936 221.799'
    ' 34.9976C222.653 35.2015 223.666 35.5313 224.584 36.0029C225.502'
    ' 36.4743 226.465 37.083 227.308 37.8264C228.151 38.5695 228.724'
    ' 39.0917 229.641 40.4621C230.557 41.8326 231.579 44.4207 232.808'
    ' 46.0489C234.037 47.6772 236.077 49.1782 237.014 50.2318C237.95'
    ' 51.2857 238.119 51.4801 238.426 52.3717C238.733 53.2635 239.032'
    ' 54.2375 238.856 55.5822C238.679 56.9268 237.614 59.6303 237.366'
    ' 60.44C237.447 59.9994 237.118 61.2498 237.366 60.44Z"'
    ' fill="{{CC}}" fill-opacity="0.2"/>'
    '<path d="M228.111 60.4054C228.06 60.688 227.827 61.0836 227.802'
    ' 62.1008C227.776 63.118 228.013 65.503 227.959 66.5086C227.905'
    ' 67.5141 227.705 67.6029 227.477 68.1341C227.249 68.6654 227.062'
    ' 69.1076 226.591 69.6957C226.121 70.2837 225.64 70.9473 224.653'
    ' 71.6622C223.665 72.377 221.828 73.1058 220.664 73.9847C219.501'
    ' 74.8635 218.499 76.308 217.673 76.9352C216.846 77.5622 216.307'
    ' 77.6321 215.705 77.747C215.103 77.862 214.953 77.8315 214.062'
    ' 77.6252C213.172 77.419 211.8 76.6763 210.361 76.5098C208.923'
    ' 76.3432 206.697 76.781 205.431 76.6258C204.166 76.4705 203.597'
    ' 76.1008 202.767 75.5789C201.937 75.057 201.215 74.4961 200.45'
    ' 73.494C199.686 72.4919 199.101 70.7863 198.182 69.5662C197.262'
    ' 68.3461 195.588 67.0376 194.932 66.1734C194.276 65.3092 194.339'
    ' 64.9533 194.244 64.3807C194.15 63.8081 194.16 63.6284 194.366'
    ' 62.7378C194.572 61.8472 195.316 60.4666 195.481 59.0366C195.647'
    ' 57.6067 195.206 55.4166 195.357 54.1581C195.508 52.8996 196.056'
    ' 52.1443 196.385 51.4857C196.714 50.8271 196.977 50.5998 197.329'
    ' 50.2066C197.681 49.8133 197.648 49.6841 198.497 49.126C199.346'
    ' 48.5677 201.205 47.777 202.425 46.8573C203.645 45.9376 204.953'
    ' 44.264 205.818 43.6077C206.682 42.9515 207.038 43.0141 207.61'
    ' 42.9197C208.183 42.8253 208.363 42.8352 209.253 43.0414C210.144'
    ' 43.2477 211.723 44.0058 212.954 44.1569C214.186 44.3082 215.777'
    ' 43.9603 216.641 43.9491C217.505 43.9379 217.592 43.9587 218.139'
    ' 44.0895C218.686 44.2203 219.335 44.4317 219.923 44.7342C220.511'
    ' 45.0365 221.128 45.4269 221.668 45.9036C222.208 46.3801 222.575'
    ' 46.715 223.162 47.5938C223.75 48.4727 224.404 50.1324 225.191'
    ' 51.1765C225.978 52.2208 227.286 53.1833 227.885 53.859C228.485'
    ' 54.5348 228.594 54.6595 228.79 55.2313C228.987 55.8032 229.178'
    ' 56.4278 229.065 57.2901C228.952 58.1524 228.27 59.8861 228.111'
    ' 60.4054ZM228.111 60.4054C227.952 60.9247 228.163 60.1229 228.111'
    ' 60.4054Z" stroke="{{S}}" stroke-width="0.96"'
    ' stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

// ---------------------------------------------------------------------------
// Pill widget
// ---------------------------------------------------------------------------

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.textColor,
    required this.backgroundColor,
    required this.borderRadius,
    required this.spacing,
    required this.sizing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color textColor;
  final Color backgroundColor;
  final double borderRadius;
  final AppSpacing spacing;
  final AppSizing sizing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
    );

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space12,
        vertical: spacing.space8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: sizing.iconSmall,
            color: iconColor,
            weight: 300,
            opticalSize: 20,
          ),
          SizedBox(width: spacing.space4),
          Flexible(
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: backgroundColor,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: content,
    );
  }
}
