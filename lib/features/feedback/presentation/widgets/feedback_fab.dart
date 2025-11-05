import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import 'feedback_form.dart';

class FeedbackFab extends StatelessWidget {
  const FeedbackFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showFeedbackForm(context),
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
      elevation: kElevationMedium,
      child: const Icon(Icons.feedback_outlined),
    );
  }

  void _showFeedbackForm(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      title: 'Send Feedback',
      subtitle: 'Help us improve the app',
      maxHeightFraction: 0.85,
      child: const FeedbackFormContent(),
    );
  }
}
