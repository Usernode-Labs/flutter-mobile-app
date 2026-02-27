import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight FPS overlay for profiling scroll performance.
///
/// Shows rolling FPS, worst frame time, and jank count (frames > 16ms).
/// Tree-shaken in release builds — wraps [child] transparently when inactive.
///
/// Usage:
/// ```dart
/// FpsMonitor(child: ChallengesScreen())
/// ```
class FpsMonitor extends StatefulWidget {
  const FpsMonitor({super.key, required this.child});

  final Widget child;

  @override
  State<FpsMonitor> createState() => _FpsMonitorState();
}

class _FpsMonitorState extends State<FpsMonitor> {
  static const _kWindowSize = 60;
  static const _kJankThreshold = Duration(milliseconds: 16);

  final _frameTimes = Queue<Duration>();
  double _fps = 0;
  Duration _worstFrame = Duration.zero;
  int _jankCount = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode || kProfileMode) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  @override
  void dispose() {
    if (kDebugMode || kProfileMode) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final total = timing.totalSpan;
      _frameTimes.addLast(total);
      if (_frameTimes.length > _kWindowSize) {
        _frameTimes.removeFirst();
      }
    }

    if (_frameTimes.isEmpty) return;

    var worst = Duration.zero;
    var totalMicros = 0;
    var janks = 0;
    for (final d in _frameTimes) {
      totalMicros += d.inMicroseconds;
      if (d > worst) worst = d;
      if (d > _kJankThreshold) janks++;
    }

    final avgMicros = totalMicros / _frameTimes.length;
    final fps = avgMicros > 0 ? 1000000.0 / avgMicros : 0.0;

    if (mounted) {
      setState(() {
        _fps = fps;
        _worstFrame = worst;
        _jankCount = janks;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode && !kProfileMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 4,
          right: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_fps.toStringAsFixed(1)} FPS | '
                'worst ${_worstFrame.inMilliseconds}ms | '
                'jank $_jankCount/${_frameTimes.length}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
