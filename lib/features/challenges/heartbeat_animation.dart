import 'dart:async';

import 'package:flutter/material.dart';

import 'package:crypto_mobile_app/design_system/src/score_header.dart';

/// Immutable snapshot of per-lobe glow values.
class GlowValues {
  final double technical;
  final double flash;
  final double community;
  final bool isAnimating;

  const GlowValues({
    this.technical = 0,
    this.flash = 0,
    this.community = 0,
    this.isAnimating = false,
  });
}

/// Encapsulates the heartbeat glow animation orchestration.
///
/// Owns 4 [AnimationController]s and exposes a [ValueNotifier<GlowValues>]
/// that the screen listens to for rebuilds. Requires a [TickerProvider]
/// (from the widget's `TickerProviderStateMixin`).
class HeartbeatAnimation {
  HeartbeatAnimation({required TickerProvider vsync}) {
    _technicalGlow = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 900),
    );
    _flashGlow = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 900),
    );
    _communityGlow = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 900),
    );
    _fadeOut = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
      value: 1.0,
    );
  }

  late final AnimationController _technicalGlow;
  late final AnimationController _flashGlow;
  late final AnimationController _communityGlow;
  late final AnimationController _fadeOut;

  // Current per-lobe values, updated by animation listeners.
  double _technicalValue = 0;
  double _flashValue = 0;
  double _communityValue = 0;
  bool _isAnimating = false;

  /// Current glow state. Listen to this to update the UI.
  final glowValues = ValueNotifier<GlowValues>(const GlowValues());

  bool _disposed = false;

  /// Fires the heartbeat glow sequence tied to [apiFuture].
  ///
  /// The stagger + one completion beat is the minimum animation. If the API
  /// calls haven't finished by then, the completion beat repeats until they
  /// do. Once done, a final fade-out plays before returning.
  Future<void> run({
    required Future<void> apiFuture,
    required ScoreHeaderVariant variant,
    required bool disableAnimations,
  }) async {
    var apiDone = false;
    unawaited(apiFuture.whenComplete(() => apiDone = true));

    final isGlowVariant = variant == ScoreHeaderVariant.glow;

    if (disableAnimations) {
      if (!isGlowVariant) {
        _technicalValue = 0.30;
        _flashValue = 0.30;
        _communityValue = 0.30;
        _isAnimating = true;
        _emitCurrent();
        await apiFuture.catchError((_) {});
        if (_disposed) return;
        _reset();
      }
      return;
    }

    _isAnimating = true;
    _emitCurrent();
    _fadeOut.value = 1.0;

    final double peak;
    final double hold;
    final double completionPeak;

    if (isGlowVariant) {
      peak = 1.0;
      hold = 0.7;
      completionPeak = 1.0;
    } else {
      peak = 0.45;
      hold = 0.30;
      completionPeak = 0.55;
    }

    try {
      final staggerSeq = _heartbeatSequence(peak, hold);

      // Stagger: technical → 550ms → flash → 550ms → community
      _runHeartbeat(_technicalGlow, staggerSeq, (v) => _technicalValue = v);
      await Future.delayed(const Duration(milliseconds: 550));
      if (_disposed) return;

      _runHeartbeat(_flashGlow, staggerSeq, (v) => _flashValue = v);
      await Future.delayed(const Duration(milliseconds: 550));
      if (_disposed) return;

      _runHeartbeat(_communityGlow, staggerSeq, (v) => _communityValue = v);

      // Hold while stagger animations settle.
      await Future.delayed(const Duration(milliseconds: 750));
      if (_disposed) return;

      // Completion heartbeat — loop until API calls are done.
      final completionSeq = _heartbeatSequence(completionPeak, hold);
      do {
        await Future.wait([
          _runHeartbeat(
              _technicalGlow, completionSeq, (v) => _technicalValue = v),
          _runHeartbeat(_flashGlow, completionSeq, (v) => _flashValue = v),
          _runHeartbeat(
              _communityGlow, completionSeq, (v) => _communityValue = v),
        ]);
        if (_disposed) return;
      } while (!apiDone);

      if (isGlowVariant) {
        _reset();
      } else {
        // Fade all to 0.
        _fadeOut.value = 1.0;
        void fadeListener() {
          if (_disposed) return;
          final f = _fadeOut.value;
          _technicalValue = hold * f;
          _flashValue = hold * f;
          _communityValue = hold * f;
          _emitCurrent();
        }

        _fadeOut.addListener(fadeListener);
        await _fadeOut.reverse(from: 1.0);
        _fadeOut.removeListener(fadeListener);
        if (_disposed) return;
        _reset();
      }
    } catch (_) {
      if (!_disposed) _reset();
    }
  }

  void dispose() {
    _disposed = true;
    _technicalGlow.dispose();
    _flashGlow.dispose();
    _communityGlow.dispose();
    _fadeOut.dispose();
    glowValues.dispose();
  }

  // -- Private helpers -------------------------------------------------------

  void _emitCurrent() {
    if (_disposed) return;
    glowValues.value = GlowValues(
      technical: _technicalValue,
      flash: _flashValue,
      community: _communityValue,
      isAnimating: _isAnimating,
    );
  }

  void _reset() {
    _technicalValue = 0;
    _flashValue = 0;
    _communityValue = 0;
    _isAnimating = false;
    _emitCurrent();
  }

  /// Heartbeat TweenSequence: lub-dub pattern.
  static TweenSequence<double> _heartbeatSequence(double peak, double hold) =>
      TweenSequence([
        // Beat 1 rise (lub)
        TweenSequenceItem(tween: Tween(begin: 0.0, end: peak), weight: 12),
        // Beat 1 fall
        TweenSequenceItem(
            tween: Tween(begin: peak, end: peak * 0.6), weight: 14),
        // Valley
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.6, end: peak * 0.6), weight: 20),
        // Beat 2 rise (dub)
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.6, end: peak * 0.85), weight: 12),
        // Settle to hold
        TweenSequenceItem(
            tween: Tween(begin: peak * 0.85, end: hold), weight: 42),
      ]);

  /// Runs a heartbeat on [controller], updating [setter] on every frame
  /// and emitting the current state via [glowValues].
  Future<void> _runHeartbeat(
    AnimationController controller,
    TweenSequence<double> sequence,
    void Function(double) setter,
  ) {
    controller.reset();
    final animation = sequence.animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    void listener() {
      setter(animation.value);
      _emitCurrent();
    }

    animation.addListener(listener);
    return controller.forward().then((_) => animation.removeListener(listener));
  }
}
