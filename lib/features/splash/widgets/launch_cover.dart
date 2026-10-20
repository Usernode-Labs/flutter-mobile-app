import 'dart:async';

import 'package:clock/clock.dart';
import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The native launch screen, continued in Flutter: the app ground with the
/// Homeroom mark at the size and place `ios/Runner/Base.lproj/
/// LaunchScreen.storyboard` draws it.
///
/// Every Flutter surface between the tap and the page's first painted frame
/// draws this (the splash while the native session starts, then the cover
/// `SvShellScreen` keeps over its WebView), so a launch reads as ONE still
/// screen that fades into the page. It must stay pixel-identical to the
/// storyboard: a different colour, size or position is a visible jump the
/// moment Flutter's first frame replaces the launch image. So no fade, scale
/// or slide, and no title.
///
/// After [slowAfter] on screen, a "Connecting to Homeroom…" line appears
/// under the mark, so a slow start reads as waiting rather than stuck.
/// [message] replaces that line, for the first launch that could not load.
/// Either sits BELOW the mark rather than in a column with it, so its
/// arrival never moves the mark.
class LaunchCover extends StatefulWidget {
  const LaunchCover({super.key, this.message});

  /// Shown under the mark in place of the "Connecting" line, at once.
  final Widget? message;

  static const markAsset = 'assets/brand/mark.png';

  /// The mark's height in logical pixels: the launch image's own point size.
  /// tool/brand/build_icons.py writes `LaunchImage.imageset` and [markAsset]
  /// from the same master at 128pt, and the storyboard draws it unscaled.
  static const markHeight = 128.0;

  /// The mark on the dark ground: build_icons.py's CREAM, the colour the
  /// dark launch image is baked in. The light one is black.
  static const _cream = Color(0xFFFFFEF4);

  /// How long the cover stays silent before the "Connecting" line appears.
  static const slowAfter = Duration(milliseconds: 2500);

  @visibleForTesting
  static const connectingKey = ValueKey('launch-cover-connecting');

  static Color markColorFor(Brightness brightness) =>
      brightness == Brightness.dark ? _cream : Colors.black;

  /// Decodes the mark into the image cache before Flutter's first frame.
  ///
  /// Flutter keeps the native launch screen up until its first frame, and
  /// an asset image decodes asynchronously, so without this that first
  /// frame is the bare ground and the mark blinks out for a few frames
  /// before it reappears. Resolved at the device's own pixel ratio, so the
  /// cache key is the one [Image.asset] asks for. Completes on error too:
  /// the mark is not worth failing a launch over.
  static Future<void> precacheMark() {
    final completer = Completer<void>();
    final dispatcher = PlatformDispatcher.instance;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    final stream = const AssetImage(markAsset).resolve(
      ImageConfiguration(
        bundle: rootBundle,
        devicePixelRatio: view?.devicePixelRatio ?? 1,
        platform: defaultTargetPlatform,
      ),
    );
    late final ImageStreamListener listener;
    void done() {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    }

    listener = ImageStreamListener(
      (_, __) => done(),
      onError: (_, __) => done(),
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  State<LaunchCover> createState() => _LaunchCoverState();
}

class _LaunchCoverState extends State<LaunchCover> {
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    final remaining = LaunchCoverClock.untilSlow();
    if (remaining == Duration.zero) {
      _slow = true;
    } else {
      _slowTimer = Timer(remaining, () {
        if (mounted) setState(() => _slow = true);
      });
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final brightness = theme.brightness;
    final message = widget.message ??
        (_slow
            ? Text(
                AppLocalizations.of(context).svShellConnectingTitle,
                key: LaunchCover.connectingKey,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              )
            : null);

    // Material rather than a bare ColoredBox: it gives the line and the
    // offline message their text style and ink.
    return Material(
      color: AppearanceStorage.groundFor(brightness),
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            // Centred on the whole screen, not the safe area: the
            // storyboard centres the image on its root view.
            Center(
              child: Image.asset(
                LaunchCover.markAsset,
                height: LaunchCover.markHeight,
                color: LaunchCover.markColorFor(brightness),
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
            if (message != null)
              Positioned(
                left: spacing.space24,
                right: spacing.space24,
                top: constraints.maxHeight / 2 +
                    LaunchCover.markHeight / 2 +
                    spacing.space24,
                child: message,
              ),
          ],
        ),
      ),
    );
  }
}

/// When the launch cover first went up in this process.
///
/// Shared by every widget that draws the cover, so the "Connecting" line
/// appears [LaunchCover.slowAfter] after the user first saw it, however many
/// widgets have drawn it since: the splash and the shell's cover are one
/// screen to the user. Timed with `package:clock`, which tests fake.
abstract final class LaunchCoverClock {
  static Stopwatch? _shown;

  /// How long until the cover has been up for [LaunchCover.slowAfter]; zero
  /// once it has. Starts the clock if no cover has been drawn yet.
  static Duration untilSlow() {
    final shown = _shown ??= clock.stopwatch()..start();
    final remaining = LaunchCover.slowAfter - shown.elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @visibleForTesting
  static void reset() => _shown = null;
}
