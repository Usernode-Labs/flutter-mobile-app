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

    final fcHex = _toHex(semantic.flash.colorContainer);
    final tcHex = _toHex(semantic.technical.colorContainer);
    final ccHex = _toHex(semantic.community.colorContainer);
    final fsHex = _toHex(semantic.flash.onColorContainer);
    final tsHex = _toHex(semantic.technical.onColorContainer);
    final csHex = _toHex(semantic.community.onColorContainer);

    final cacheKey = '$fcHex|$tcHex|$ccHex|$fsHex|$tsHex|$csHex';
    final illustration = _cache[cacheKey] ??
        (_cache[cacheKey] = SvgPicture.string(
          _trioSvg
              .replaceAll('{{FC}}', fcHex)
              .replaceAll('{{TC}}', tcHex)
              .replaceAll('{{CC}}', ccHex)
              .replaceAll('{{FS}}', fsHex)
              .replaceAll('{{TS}}', tsHex)
              .replaceAll('{{CS}}', csHex),
        ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: SizedBox(
            height: 128,
            width: double.infinity,
            child: Center(child: illustration),
          ),
        ),
        SizedBox(height: spacing.space4),
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
          spacing: spacing.space12,
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
// SVG template – horizontal trio illustration (compact)
// ---------------------------------------------------------------------------
// {{FC}}/{{TC}}/{{CC}} = category fill (colorContainer)
// {{FS}}/{{TS}}/{{CS}} = category stroke (onColorContainer)

const _trioSvg = '<svg width="210" height="118" viewBox="0 0 210 118"'
    ' fill="none" xmlns="http://www.w3.org/2000/svg">'
    // Flash – circle
    '<path d="M128.765 111.55C143.245 111.55 154.984 99.8108 154.984'
    ' 85.3301C154.984 70.8493 143.245 59.1104 128.765 59.1104C114.284'
    ' 59.1104 102.545 70.8493 102.545 85.3301C102.545 99.8108 114.284'
    ' 111.55 128.765 111.55Z" fill="{{FC}}"/>'
    '<path d="M128.764 117.668C146.622 117.668 161.098 103.192 161.098'
    ' 85.3342C161.098 67.4765 146.622 53 128.764 53C110.906 53 96.4297'
    ' 67.4765 96.4297 85.3342C96.4297 103.192 110.906 117.668 128.764'
    ' 117.668Z" fill="{{FC}}" fill-opacity="0.3"/>'
    '<path d="M129.222 101.501C138.151 101.501 145.389 94.263 145.389'
    ' 85.3341C145.389 76.4053 138.151 69.167 129.222 69.167C120.293'
    ' 69.167 113.055 76.4053 113.055 85.3341C113.055 94.263 120.293'
    ' 101.501 129.222 101.501Z" stroke="{{FS}}" stroke-linecap="round"'
    ' stroke-dasharray="4 4"/>'
    // Technical – hexagon
    '<g opacity="0.6">'
    '<path d="M34.8504 13.8506L72.2621 19.8056L85.9121 55.8351L62.1505'
    ' 85.9095L24.7389 79.9545L11.0889 43.925L34.8504 13.8506Z"'
    ' fill="{{TC}}"/>'
    '<path d="M38.9211 97L7.43127 76.021L0 38.9211L20.979 7.43127L58.0789'
    ' 0L89.5687 20.979L97 58.0789L76.021 89.5687L38.9211 97Z"'
    ' fill="{{TC}}" fill-opacity="0.3"/>'
    '<path d="M56.7217 24.9521L72.0494 41.2218L68.9635 63.4214L49.7862'
    ' 74.8343L28.9602 66.867L22.1672 45.5187L34.5215 26.8644L56.7217'
    ' 24.9521Z" stroke="{{TS}}"/>'
    '</g>'
    // Community – blob
    '<g opacity="0.5">'
    '<path d="M206.552 30.6204C206.466 31.0947 206.075 31.7589 206.033'
    ' 33.4666C205.99 35.1744 206.387 39.1784 206.296 40.8667C206.206'
    ' 42.5549 205.87 42.704 205.488 43.5958C205.105 44.4876 204.791'
    ' 45.2301 204.001 46.2173C203.211 47.2046 202.404 48.3187 200.746'
    ' 49.5189C199.087 50.7189 196.003 51.9426 194.05 53.418C192.097'
    ' 54.8935 190.416 57.3186 189.028 58.3715C187.64 59.4241 186.735'
    ' 59.5415 185.724 59.7345C184.714 59.9275 184.461 59.8762 182.966'
    ' 59.53C181.471 59.1838 179.168 57.9369 176.753 57.6573C174.337'
    ' 57.3777 170.601 58.1126 168.476 57.852C166.351 57.5914 165.396'
    ' 56.9707 164.003 56.0945C162.609 55.2183 161.397 54.2767 160.114'
    ' 52.5943C158.831 50.9119 157.849 48.0483 156.305 45.9999C154.761'
    ' 43.9516 151.951 41.7548 150.85 40.304C149.748 38.8532 149.853'
    ' 38.2556 149.694 37.2943C149.536 36.3329 149.553 36.0313 149.899'
    ' 34.5361C150.245 33.0409 151.494 30.7231 151.772 28.3224C152.049'
    ' 25.9217 151.31 22.2448 151.563 20.132C151.816 18.0192 152.737'
    ' 16.7512 153.289 15.6454C153.841 14.5398 154.283 14.1582 154.874'
    ' 13.4979C155.465 12.8377 155.409 12.6207 156.835 11.6838C158.261'
    ' 10.7466 161.381 9.41897 163.429 7.87494C165.477 6.33091 167.674'
    ' 3.52125 169.125 2.41934C170.576 1.31768 171.173 1.42285 172.135'
    ' 1.26425C173.096 1.10589 173.398 1.12248 174.893 1.46872C176.388'
    ' 1.81496 179.039 3.08766 181.106 3.34142C183.174 3.59542 185.845'
    ' 3.01129 187.296 2.9925C188.747 2.97371 188.892 3.0086 189.811'
    ' 3.2282C190.729 3.4478 191.819 3.80282 192.806 4.31059C193.794'
    ' 4.81811 194.829 5.47349 195.736 6.27381C196.642 7.07389 197.258'
    ' 7.63606 198.244 9.11153C199.23 10.587 200.329 13.3735 201.65'
    ' 15.1264C202.972 16.8795 205.166 18.4955 206.173 19.6299C207.18'
    ' 20.7645 207.362 20.9738 207.692 21.9337C208.023 22.8939 208.344'
    ' 23.9426 208.154 25.3902C207.964 26.8379 206.819 29.7486 206.552'
    ' 30.6204C206.639 30.146 206.285 31.4922 206.552 30.6204Z"'
    ' fill="{{CC}}" fill-opacity="0.3"/>'
    '<path d="M200.51 30.5885C200.442 30.9583 200.138 31.4761 200.104'
    ' 32.8076C200.071 34.1391 200.381 37.261 200.31 38.5773C200.239'
    ' 39.8936 199.978 40.0098 199.679 40.7051C199.38 41.4005 199.136'
    ' 41.9794 198.519 42.7491C197.902 43.5188 197.272 44.3875 195.978'
    ' 45.3233C194.683 46.2589 192.276 47.2129 190.752 48.3633C189.227'
    ' 49.5137 187.915 51.4045 186.832 52.2254C185.748 53.0461 185.042'
    ' 53.1376 184.253 53.2881C183.464 53.4386 183.267 53.3986 182.1'
    ' 53.1287C180.933 52.8587 179.135 51.8866 177.25 51.6686C175.365'
    ' 51.4506 172.449 52.0236 170.79 51.8204C169.131 51.6172 168.386'
    ' 51.1332 167.298 50.4501C166.21 49.7669 165.264 49.0328 164.263'
    ' 47.7211C163.261 46.4093 162.495 44.1767 161.29 42.5796C160.085'
    ' 40.9825 157.892 39.2698 157.032 38.1386C156.172 37.0074 156.254'
    ' 36.5415 156.13 35.7919C156.006 35.0424 156.019 34.8073 156.289'
    ' 33.6415C156.56 32.4757 157.535 30.6685 157.751 28.7968C157.968'
    ' 26.925 157.391 24.0582 157.588 22.4109C157.785 20.7636 158.505'
    ' 19.7749 158.936 18.9127C159.366 18.0507 159.711 17.7532 160.173'
    ' 17.2384C160.634 16.7236 160.59 16.5545 161.703 15.824C162.816'
    ' 15.0932 165.251 14.0581 166.85 12.8543C168.449 11.6504 170.164'
    ' 9.45981 171.296 8.60067C172.429 7.74173 172.895 7.82372 173.645'
    ' 7.70007C174.396 7.5766 174.631 7.58954 175.798 7.85949C176.965'
    ' 8.12944 179.035 9.12175 180.648 9.3196C182.262 9.51764 184.347'
    ' 9.0622 185.479 9.04755C186.612 9.0329 186.726 9.06011 187.442'
    ' 9.23132C188.159 9.40254 189.01 9.67934 189.78 10.0752C190.551'
    ' 10.4709 191.36 10.9819 192.067 11.6059C192.775 12.2297 193.256'
    ' 12.668 194.025 13.8184C194.795 14.9688 195.652 17.1414 196.684'
    ' 18.5081C197.715 19.875 199.428 21.1349 200.214 22.0194C201'
    ' 22.904 201.142 23.0672 201.4 23.8156C201.658 24.5643 201.909'
    ' 25.3819 201.76 26.5106C201.612 27.6393 200.718 29.9087 200.51'
    ' 30.5885C200.578 30.2186 200.302 31.2682 200.51 30.5885Z"'
    ' fill="{{CC}}"/>'
    '<path d="M192.741 30.5602C192.698 30.7974 192.503 31.1294 192.481'
    ' 31.9833C192.46 32.8372 192.659 34.8392 192.613 35.6833C192.568'
    ' 36.5275 192.4 36.602 192.209 37.0479C192.018 37.4938 191.861'
    ' 37.8651 191.466 38.3587C191.07 38.8523 190.667 39.4093 189.838'
    ' 40.0095C189.009 40.6095 187.467 41.2213 186.49 41.959C185.514'
    ' 42.6967 184.673 43.9093 183.979 44.4357C183.285 44.962 182.833'
    ' 45.0207 182.327 45.1172C181.822 45.2137 181.696 45.1881 180.948'
    ' 45.015C180.201 44.8419 179.049 44.2185 177.841 44.0786C176.634'
    ' 43.9388 174.766 44.3063 173.703 44.176C172.641 44.0457 172.163'
    ' 43.7353 171.466 43.2972C170.77 42.8591 170.164 42.3883 169.522'
    ' 41.5471C168.881 40.706 168.39 39.2742 167.618 38.25C166.846'
    ' 37.2258 165.441 36.1274 164.89 35.402C164.339 34.6766 164.392'
    ' 34.3778 164.312 33.8971C164.233 33.4165 164.241 33.2657 164.415'
    ' 32.518C164.588 31.7704 165.212 30.6116 165.351 29.4112C165.49'
    ' 28.2108 165.12 26.3724 165.246 25.316C165.373 24.2596 165.834'
    ' 23.6256 166.11 23.0727C166.385 22.5199 166.607 22.3291 166.902'
    ' 21.999C167.197 21.6688 167.169 21.5604 167.882 21.0919C168.595'
    ' 20.6233 170.155 19.9595 171.18 19.1875C172.204 18.4155 173.302'
    ' 17.0106 174.028 16.4597C174.753 15.9088 175.052 15.9614 175.532'
    ' 15.8821C176.013 15.8029 176.164 15.8112 176.911 15.9844C177.659'
    ' 16.1575 178.985 16.7938 180.018 16.9207C181.052 17.0477 182.388'
    ' 16.7556 183.113 16.7463C183.838 16.7369 183.911 16.7543 184.37'
    ' 16.8641C184.83 16.9739 185.374 17.1514 185.868 17.4053C186.362'
    ' 17.6591 186.88 17.9867 187.333 18.3869C187.786 18.7869 188.094'
    ' 19.068 188.587 19.8058C189.08 20.5435 189.629 21.9367 190.29'
    ' 22.8132C190.951 23.6898 192.048 24.4978 192.552 25.0649C193.055'
    ' 25.6322 193.146 25.7369 193.311 26.2169C193.476 26.6969 193.637'
    ' 27.2213 193.542 27.9451C193.447 28.6689 192.875 30.1243 192.741'
    ' 30.5602ZM192.741 30.5602C192.608 30.9961 192.785 30.323 192.741'
    ' 30.5602Z" stroke="{{CS}}" stroke-width="0.96"'
    ' stroke-linecap="round" stroke-linejoin="round"/>'
    '</g>'
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
        spacing: spacing.space4,
        children: [
          Icon(
            icon,
            size: sizing.iconSmall,
            color: iconColor,
          ),
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
