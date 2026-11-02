import 'package:crypto_mobile_app/core/bootstrap/proving_parameters_preparation.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import 'package:crypto_mobile_app/design_system/tokens/app_spacing.dart';
import 'package:crypto_mobile_app/design_system/src/button.dart';
import 'package:crypto_mobile_app/features/splash/widgets/launch_cover.dart';
import 'package:flutter/material.dart';

/// Reuses the launch cover during foreground parameter preparation.
class ProvingParametersCover extends StatelessWidget {
  const ProvingParametersCover({
    super.key,
    required this.preparation,
    required this.child,
  });

  final ProvingParametersPreparation preparation;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
        valueListenable: preparation,
        child: child,
        builder: (context, progress, child) => Stack(
          fit: StackFit.expand,
          children: [
            child!,
            if (progress != null)
              LaunchCover(
                message: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progress.failed
                          ? AppLocalizations.of(context)
                              .provingParametersDownloadFailed
                          : AppLocalizations.of(context)
                              .provingParametersDownloadProgress(
                                  (progress.fraction * 100).floor()),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(
                        height:
                            Theme.of(context).extension<AppSpacing>()!.space16),
                    if (progress.failed)
                      Button(
                        onTap: preparation.retry,
                        label: AppLocalizations.of(context).retry,
                      )
                    else
                      LinearProgressIndicator(
                        value:
                            progress.totalBytes == 0 ? null : progress.fraction,
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
}
