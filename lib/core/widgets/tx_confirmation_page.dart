import 'dart:convert';

import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_radii.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_sizing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Full-screen confirmation page for transactions.
///
/// Pushed as an opaque route so it covers any underlying platform views
/// (e.g. WebView). Returns `true` when the user confirms, `false` on deny/back.
class TxConfirmationPage extends StatefulWidget {
  const TxConfirmationPage({
    super.key,
    required this.from,
    required this.to,
    required this.amount,
    required this.memo,
    this.confirmTitle,
    this.confirmSubtitle,
  });

  final String from;
  final String to;
  final BigInt amount;
  final String memo;
  final String? confirmTitle;
  final String? confirmSubtitle;

  @override
  State<TxConfirmationPage> createState() => _TxConfirmationPageState();
}

class _TxConfirmationPageState extends State<TxConfirmationPage> {
  bool _detailsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.extension<AppSpacing>()!;
    final sizing = theme.extension<AppSizing>()!;
    final radii = theme.extension<AppRadii>()!;
    final muted = theme.colorScheme.onSurfaceVariant;

    String formattedMemo = widget.memo;
    if (widget.memo.isNotEmpty) {
      try {
        final parsed = jsonDecode(widget.memo);
        const encoder = JsonEncoder.withIndent('  ');
        formattedMemo = encoder.convert(parsed);
      } catch (_) {}
    }

    Widget detailRow(String label, String value, {bool mono = false}) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            SizedBox(height: spacing.space4),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: mono ? kMonoFontFamily : null,
              ),
            ),
          ],
        ),
      );
    }

    final detailsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        detailRow('From', widget.from, mono: true),
        const Divider(height: 1),
        detailRow('To', widget.to, mono: true),
        const Divider(height: 1),
        detailRow('Fee', '0'),
        if (formattedMemo.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(top: spacing.space8),
            child: Text(
              'Memo',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
          SizedBox(height: spacing.space4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    formattedMemo,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Symbols.arrow_back_sharp),
        ),
        title: Text(widget.confirmTitle ?? 'Confirm Transaction'),
        titleSpacing: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.confirmSubtitle ??
                    'A dapp is requesting to send a transaction.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              SizedBox(height: spacing.space24),
              Text(
                'Amount',
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
              SizedBox(height: spacing.space4),
              Text(
                widget.amount.toString(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: kMonoFontFamily,
                ),
              ),
              SizedBox(height: spacing.space16),
              Expanded(
                child: SingleChildScrollView(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(100),
                      borderRadius: radii.borderRadiusMedium,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: _detailsExpanded
                              ? BorderRadius.vertical(
                                  top: radii.borderRadiusMedium.topLeft,
                                )
                              : radii.borderRadiusMedium,
                          onTap: () => setState(
                            () => _detailsExpanded = !_detailsExpanded,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: spacing.space16,
                              vertical: spacing.space12,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Details',
                                  style: theme.textTheme.titleSmall,
                                ),
                                const Spacer(),
                                AnimatedRotation(
                                  turns: _detailsExpanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Symbols.expand_more,
                                    size: sizing.iconSmall,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: EdgeInsets.fromLTRB(
                              spacing.space16,
                              0,
                              spacing.space16,
                              spacing.space16,
                            ),
                            child: detailsContent,
                          ),
                          crossFadeState: _detailsExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.space24),
              Row(
                children: [
                  Expanded(
                    child: Button(
                      label: 'Deny',
                      variant: ButtonVariant.outlined,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  SizedBox(width: spacing.space12),
                  Expanded(
                    child: Button(
                      label: 'Confirm',
                      variant: ButtonVariant.primary,
                      onTap: () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes [TxConfirmationPage] as a full-screen opaque route.
/// Returns `true` if confirmed, `false` if denied.
Future<bool> requestTransactionConfirmation(
  BuildContext context, {
  required String from,
  required String to,
  required BigInt amount,
  required String memo,
  String? confirmTitle,
  String? confirmSubtitle,
}) async {
  final confirmed = await Navigator.push<bool>(
    context,
    PageRouteBuilder<bool>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => TxConfirmationPage(
        from: from,
        to: to,
        amount: amount,
        memo: memo,
        confirmTitle: confirmTitle,
        confirmSubtitle: confirmSubtitle,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )),
          child: child,
        );
      },
    ),
  );

  return confirmed ?? false;
}
