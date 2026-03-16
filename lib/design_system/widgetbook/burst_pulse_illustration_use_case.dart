import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../design_system.dart';

WidgetbookComponent burstPulseIllustrationComponent() {
  return WidgetbookComponent(
    name: 'BurstPulseIllustration',
    useCases: [
      WidgetbookUseCase(
        name: 'Simulator',
        builder: (context) {
          final total = context.knobs.int.slider(
            label: 'Total transactions',
            initialValue: 50,
            min: 5,
            max: 500,
          );
          final failureRate = context.knobs.double.slider(
            label: 'Failure rate',
            initialValue: 0.1,
            min: 0,
            max: 1,
          );
          final intervalMs = context.knobs.int.slider(
            label: 'Interval (ms)',
            initialValue: 200,
            min: 50,
            max: 1000,
          );

          return _BurstSimulator(
            total: total,
            failureRate: failureRate,
            intervalMs: intervalMs,
          );
        },
      ),
    ],
  );
}

class _BurstSimulator extends StatefulWidget {
  const _BurstSimulator({
    required this.total,
    required this.failureRate,
    required this.intervalMs,
  });

  final int total;
  final double failureRate;
  final int intervalMs;

  @override
  State<_BurstSimulator> createState() => _BurstSimulatorState();
}

class _BurstSimulatorState extends State<_BurstSimulator> {
  final _random = Random();
  List<BurstRingOutcome> _rings = [];
  Timer? _timer;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_BurstSimulator old) {
    super.didUpdateWidget(old);
    if (old.total != widget.total ||
        old.failureRate != widget.failureRate ||
        old.intervalMs != widget.intervalMs) {
      _restart();
    }
  }

  void _start() {
    _rings = [];
    _active = true;
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: widget.intervalMs),
      (_) {
        if (_rings.length >= widget.total) {
          _timer?.cancel();
          setState(() => _active = false);
          return;
        }
        setState(() {
          _rings = [
            ..._rings,
            _random.nextDouble() < widget.failureRate
                ? BurstRingOutcome.failed
                : BurstRingOutcome.succeeded,
          ];
        });
      },
    );
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _rings = [];
      _active = false;
    });
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Expanded(
          child: BurstPulseIllustration(
            rings: _rings,
            active: _active,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_rings.length} / ${widget.total}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _restart,
          child: const Text('Restart'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
