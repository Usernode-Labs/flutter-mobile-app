import 'dart:async';

import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Covers [child] with a splash while foreground-resume validation is
/// [pending] for longer than [showDelay].
///
/// Resume validation refreshes producer policy over the network and wakes the
/// paused native node, which can take seconds. The app wrapper already blocks
/// input for that window; without this the frozen UI reads as a hang. Quick
/// resumes finish inside [showDelay] and never flash the splash.
class ResumeSplashGate extends StatefulWidget {
  const ResumeSplashGate({
    super.key,
    required this.pending,
    required this.child,
  });

  static const showDelay = Duration(milliseconds: 300);

  @visibleForTesting
  static const splashKey = ValueKey('resume-splash');

  final bool pending;
  final Widget child;

  @override
  State<ResumeSplashGate> createState() => _ResumeSplashGateState();
}

class _ResumeSplashGateState extends State<ResumeSplashGate> {
  Timer? _showTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.pending) _scheduleShow();
  }

  @override
  void didUpdateWidget(ResumeSplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pending == oldWidget.pending) return;
    if (widget.pending) {
      _scheduleShow();
    } else {
      _showTimer?.cancel();
      _visible = false;
    }
  }

  void _scheduleShow() {
    _showTimer?.cancel();
    _showTimer = Timer(ResumeSplashGate.showDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible) const _ResumeSplash(key: ResumeSplashGate.splashKey),
      ],
    );
  }
}

class _ResumeSplash extends StatelessWidget {
  const _ResumeSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;

    // Same ground as the native launch screen and the SV shell, so the splash
    // reads as the app surface rather than a separate screen.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 150),
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: ColoredBox(
        color: AppearanceStorage.background ??
            theme.colorScheme.surfaceContainerLowest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/mark.png',
                height: sizing.iconDisplayLarge,
                color: theme.colorScheme.onSurface,
              ),
              SizedBox(height: spacing.space32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
