import 'dart:async';

import 'package:crypto_mobile_app/core/config/appearance.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Blocks input to [child] while foreground-resume validation is [pending],
/// covering it with a splash once that takes longer than [showDelay].
///
/// Resume validation refreshes producer policy over the network and wakes the
/// paused native node, which can take seconds. Quick resumes finish inside
/// [showDelay] and never flash the splash. The UI is released after [maxBlock]
/// even if validation is still running: node-backed operations stay gated by
/// the native admission barrier, so only the screen stops waiting.
class ResumeSplashGate extends StatefulWidget {
  const ResumeSplashGate({
    super.key,
    required this.pending,
    this.resumeGeneration = 0,
    required this.child,
  });

  static const showDelay = Duration(milliseconds: 300);
  static const maxBlock = Duration(milliseconds: 1500);

  @visibleForTesting
  static const splashKey = ValueKey('resume-splash');

  final bool pending;

  /// Bumped on every foreground resume. A resume while an earlier validation
  /// is still [pending] keeps [pending] true, so this is what restarts the
  /// block for its own [maxBlock] budget.
  final int resumeGeneration;
  final Widget child;

  @override
  State<ResumeSplashGate> createState() => _ResumeSplashGateState();
}

class _ResumeSplashGateState extends State<ResumeSplashGate> {
  Timer? _showTimer;
  Timer? _releaseTimer;
  bool _visible = false;
  bool _blocking = false;

  @override
  void initState() {
    super.initState();
    if (widget.pending) _startBlocking();
  }

  @override
  void didUpdateWidget(ResumeSplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.pending) {
      if (oldWidget.pending) _release();
      return;
    }
    if (!oldWidget.pending ||
        widget.resumeGeneration != oldWidget.resumeGeneration) {
      _startBlocking();
    }
  }

  void _startBlocking() {
    _cancelTimers();
    _blocking = true;
    _showTimer = Timer(ResumeSplashGate.showDelay, () {
      if (mounted) setState(() => _visible = true);
    });
    _releaseTimer = Timer(ResumeSplashGate.maxBlock, () {
      if (mounted) setState(_release);
    });
  }

  void _release() {
    _cancelTimers();
    _blocking = false;
    _visible = false;
  }

  void _cancelTimers() {
    _showTimer?.cancel();
    _releaseTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AbsorbPointer(absorbing: _blocking, child: widget.child),
        if (_blocking)
          const ModalBarrier(dismissible: false, color: Colors.transparent),
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
        color: AppearanceStorage.groundFor(theme.brightness),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/wordmark.png',
                height: sizing.iconDisplayLarge,
                color: theme.colorScheme.onSurface,
              ),
              SizedBox(height: spacing.space32),
              const CircularProgressIndicator(),
              SizedBox(height: spacing.space16),
              Text(
                AppLocalizations.of(context).resumeSplashLoading,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
