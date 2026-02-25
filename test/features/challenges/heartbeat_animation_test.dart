import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crypto_mobile_app/design_system/src/score_header.dart';
import 'package:crypto_mobile_app/features/challenges/heartbeat_animation.dart';

// ---------------------------------------------------------------------------
// Fake TickerProvider for unit-style tests inside testWidgets
// ---------------------------------------------------------------------------

class _TestTickerProvider extends TickerProvider {
  final List<Ticker> _tickers = [];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }

  void disposeAll() {
    for (final t in _tickers) {
      if (t.isActive) t.dispose();
    }
  }
}

/// Pumps in small increments to let chained Future.delayed + animation
/// controllers progress through their full sequences.
Future<void> _pumpForDuration(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < total) {
    await tester.pump(step);
    elapsed += step;
  }
}

void main() {
  group('HeartbeatAnimation', () {
    testWidgets('starts and completes standard animation cycle',
        (tester) async {
      final vsync = _TestTickerProvider();
      final heartbeat = HeartbeatAnimation(vsync: vsync);

      final completer = Completer<void>();
      final values = <GlowValues>[];
      heartbeat.glowValues.addListener(() {
        values.add(heartbeat.glowValues.value);
      });

      // Start the animation with an immediately-completing API future.
      completer.complete();
      final runFuture = heartbeat.run(
        apiFuture: completer.future,
        variant: ScoreHeaderVariant.standard,
        disableAnimations: false,
      );

      // Pump enough frames for the full animation to complete.
      // Stagger: 550 + 550 + 750 = 1850ms, plus heartbeat cycles ~900ms,
      // plus fade-out ~600ms. 6 seconds covers everything.
      await _pumpForDuration(tester, const Duration(seconds: 6));
      await runFuture;

      // Should have emitted values during the animation.
      expect(values, isNotEmpty);

      // Should end in reset state (isAnimating: false, all zeros).
      final last = heartbeat.glowValues.value;
      expect(last.isAnimating, isFalse);
      expect(last.technical, 0);
      expect(last.flash, 0);
      expect(last.community, 0);

      heartbeat.dispose();
      vsync.disposeAll();
    });

    testWidgets('accessibility mode sets static values then resets',
        (tester) async {
      final vsync = _TestTickerProvider();
      final heartbeat = HeartbeatAnimation(vsync: vsync);

      final completer = Completer<void>();
      GlowValues? midValues;

      heartbeat.glowValues.addListener(() {
        if (heartbeat.glowValues.value.isAnimating) {
          midValues = heartbeat.glowValues.value;
        }
      });

      final runFuture = heartbeat.run(
        apiFuture: completer.future,
        variant: ScoreHeaderVariant.standard,
        disableAnimations: true,
      );

      await tester.pump();

      // Should have static glow values.
      expect(midValues, isNotNull);
      expect(midValues!.technical, 0.30);
      expect(midValues!.flash, 0.30);
      expect(midValues!.community, 0.30);
      expect(midValues!.isAnimating, isTrue);

      // Complete the API call.
      completer.complete();
      await tester.pump();
      await runFuture;

      // Should be reset.
      final last = heartbeat.glowValues.value;
      expect(last.isAnimating, isFalse);
      expect(last.technical, 0);

      heartbeat.dispose();
      vsync.disposeAll();
    });

    testWidgets('glow variant skips animation in accessibility mode',
        (tester) async {
      final vsync = _TestTickerProvider();
      final heartbeat = HeartbeatAnimation(vsync: vsync);

      final values = <GlowValues>[];
      heartbeat.glowValues.addListener(() {
        values.add(heartbeat.glowValues.value);
      });

      final completer = Completer<void>();
      completer.complete();
      final runFuture = heartbeat.run(
        apiFuture: completer.future,
        variant: ScoreHeaderVariant.glow,
        disableAnimations: true,
      );

      await tester.pump();
      await runFuture;

      // Glow variant + accessibility = early return, no emission.
      expect(values, isEmpty);

      heartbeat.dispose();
      vsync.disposeAll();
    });

    testWidgets('dispose is safe during animation', (tester) async {
      final vsync = _TestTickerProvider();
      final heartbeat = HeartbeatAnimation(vsync: vsync);

      final neverCompletes = Completer<void>();

      // Start animation but don't await — dispose while running.
      unawaited(heartbeat.run(
        apiFuture: neverCompletes.future,
        variant: ScoreHeaderVariant.standard,
        disableAnimations: false,
      ));

      await _pumpForDuration(tester, const Duration(milliseconds: 200));

      // Should not throw.
      heartbeat.dispose();
      vsync.disposeAll();

      // Drain any pending timers so the test framework doesn't complain.
      await _pumpForDuration(tester, const Duration(seconds: 6));
    });

    testWidgets('completion loop repeats while API is pending',
        (tester) async {
      final vsync = _TestTickerProvider();
      final heartbeat = HeartbeatAnimation(vsync: vsync);

      final completer = Completer<void>();
      var sawAnimating = false;

      heartbeat.glowValues.addListener(() {
        if (heartbeat.glowValues.value.isAnimating) {
          sawAnimating = true;
        }
      });

      unawaited(heartbeat.run(
        apiFuture: completer.future,
        variant: ScoreHeaderVariant.standard,
        disableAnimations: false,
      ));

      // Let stagger + first completion cycle run.
      await _pumpForDuration(tester, const Duration(seconds: 4));
      expect(sawAnimating, isTrue);

      // Now complete the API.
      completer.complete();
      await _pumpForDuration(tester, const Duration(seconds: 4));

      // Should reach reset state.
      final last = heartbeat.glowValues.value;
      expect(last.isAnimating, isFalse);

      heartbeat.dispose();
      vsync.disposeAll();
    });
  });
}
