import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:crypto_mobile_app/core/config/design_tokens.dart';
import 'package:crypto_mobile_app/core/widgets/app_button.dart';
import 'package:crypto_mobile_app/core/widgets/app_text_field.dart';
import 'package:crypto_mobile_app/core/config/l10n/app_localizations.dart';
import '../models/feedback_model.dart';
import '../feedback_provider.dart';

class FeedbackFormContent extends ConsumerStatefulWidget {
  const FeedbackFormContent({super.key});

  @override
  ConsumerState<FeedbackFormContent> createState() =>
      _FeedbackFormContentState();
}

class _FeedbackFormContentState extends ConsumerState<FeedbackFormContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCategory = 'Bug Report';
  bool _includeDeviceInfo = true;
  final List<File> _screenshots = [];

  final List<String> _categories = [
    'Bug Report',
    'Feature Request',
    'General Feedback',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final submissionState = ref.watch(feedbackSubmissionProvider);
    final l10n = AppLocalizations.of(context);

    // Listen to submission state changes
    ref.listen<FeedbackSubmissionState>(
      feedbackSubmissionProvider,
      (previous, next) {
        if (next.status == FeedbackSubmissionStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.feedbackSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else if (next.status == FeedbackSubmissionStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.errorMessage ?? l10n.feedbackError),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: kSpace24,
          right: kSpace24,
          bottom: MediaQuery.of(context).viewInsets.bottom + kSpace24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title field
            AppTextField(
              controller: _titleController,
              labelText: l10n.feedbackTitle,
              hintText: l10n.feedbackTitleHint,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.feedbackRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: kSpace16),

            // Description field
            AppTextField(
              controller: _descriptionController,
              labelText: l10n.feedbackDescription,
              hintText: l10n.feedbackDescriptionHint,
              maxLines: 5,
              minLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.feedbackRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: kSpace16),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: l10n.feedbackCategory,
                border: OutlineInputBorder(
                  borderRadius: kBorderRadiusMedium,
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: kSpace16),

            // Screenshot section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(kSpace16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: kIconRegular,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: kSpace8),
                        Text(
                          l10n.feedbackScreenshots,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed:
                              _screenshots.length < 3 ? _pickScreenshot : null,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(l10n.feedbackAddScreenshot),
                        ),
                      ],
                    ),
                    if (_screenshots.isNotEmpty) ...[
                      const SizedBox(height: kSpace8),
                      Wrap(
                        spacing: kSpace8,
                        runSpacing: kSpace8,
                        children: _screenshots.asMap().entries.map((entry) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  kRadiusSmall,
                                ),
                                child: Image.file(
                                  entry.value,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeScreenshot(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                    if (_screenshots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: kSpace8),
                        child: Text(
                          l10n.feedbackNoScreenshots,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: kSpace16),

            // Device info checkbox
            CheckboxListTile(
              value: _includeDeviceInfo,
              onChanged: (value) {
                setState(() {
                  _includeDeviceInfo = value ?? true;
                });
              },
              title: Text(l10n.feedbackIncludeDeviceInfo),
              subtitle: Text(l10n.feedbackDeviceInfoHelp),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: kSpace24),

            // Submit button
            AppButton(
              label: l10n.feedbackSubmit,
              onPressed:
                  submissionState.status == FeedbackSubmissionStatus.submitting
                      ? null
                      : _submitFeedback,
              isLoading:
                  submissionState.status == FeedbackSubmissionStatus.submitting,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        setState(() {
          _screenshots.add(File(image.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)
                .feedbackImagePickFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeScreenshot(int index) {
    setState(() {
      _screenshots.removeAt(index);
    });
  }

  void _submitFeedback() {
    if (_formKey.currentState?.validate() ?? false) {
      final feedback = FeedbackModel(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        includeDeviceInfo: _includeDeviceInfo,
        screenshots: _screenshots.isNotEmpty ? _screenshots : null,
      );

      ref.read(feedbackSubmissionProvider.notifier).submitFeedback(feedback);
    }
  }
}
