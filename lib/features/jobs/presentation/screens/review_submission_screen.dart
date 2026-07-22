import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/presentation/providers/job_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReviewSubmissionScreen extends ConsumerStatefulWidget {
  const ReviewSubmissionScreen({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<ReviewSubmissionScreen> createState() =>
      _ReviewSubmissionScreenState();
}

class _ReviewSubmissionScreenState
    extends ConsumerState<ReviewSubmissionScreen> {
  final _commentController = TextEditingController();
  final Map<String, int> _ratings = {};
  var _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    final job = ref.watch(jobProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          role == UserRole.customer ? 'Leave a review' : 'Review customer',
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        accent: role == UserRole.customer
            ? LiquidGlassColors.vehicles
            : LiquidGlassColors.industrial,
        child: job.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Text('This review could not be prepared. Try again.'),
          ),
          data: (value) {
            if (value == null) {
              return const Center(
                child: Text('This job is no longer available.'),
              );
            }
            if (!value.canReview) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'A review is available once the job is complete, and can be submitted once.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return _ReviewForm(
              job: value,
              role: role,
              ratings: _ratings,
              commentController: _commentController,
              submitting: _submitting,
              onRatingChanged: (key, rating) {
                setState(() => _ratings[key] = rating);
              },
              onSubmit: () => _submit(value, role),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit(RepairJob job, UserRole role) async {
    final required = role == UserRole.customer
        ? const [
            'overall',
            'quality',
            'communication',
            'punctuality',
            'value',
            'quote_accuracy',
          ]
        : const [
            'overall',
            'communication',
            'description_accuracy',
            'attendance',
            'location_accessibility',
          ];
    if (required.any((key) => _ratings[key] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a rating for every category.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .submitReview(
            job.id,
            JobReviewInput(
              overallRating: _ratings['overall']!,
              communicationRating: _ratings['communication']!,
              comment: _commentController.text,
              qualityRating: _ratings['quality'],
              punctualityRating: _ratings['punctuality'],
              valueRating: _ratings['value'],
              quoteAccuracyRating: _ratings['quote_accuracy'],
              descriptionAccuracyRating: _ratings['description_accuracy'],
              attendanceRating: _ratings['attendance'],
              locationAccessibilityRating: _ratings['location_accessibility'],
            ),
          );
      ref.invalidate(jobProvider(widget.jobId));
      ref.invalidate(jobsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you. Your review is now published.'),
        ),
      );
      Navigator.pop(context);
    } on JobFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The review could not be submitted. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.job,
    required this.role,
    required this.ratings,
    required this.commentController,
    required this.submitting,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final RepairJob job;
  final UserRole role;
  final Map<String, int> ratings;
  final TextEditingController commentController;
  final bool submitting;
  final void Function(String key, int rating) onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final questions = role == UserRole.customer
        ? const [
            ('overall', 'Overall experience'),
            ('quality', 'Quality of repair'),
            ('communication', 'Communication'),
            ('punctuality', 'Punctuality'),
            ('value', 'Value for money'),
            ('quote_accuracy', 'Quote accuracy'),
          ]
        : const [
            ('overall', 'Overall experience'),
            ('communication', 'Communication'),
            ('description_accuracy', 'Description accuracy'),
            ('attendance', 'Appointment attendance'),
            ('location_accessibility', 'Location accessibility'),
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          role == UserRole.customer
              ? 'Share honest feedback about ${job.counterpartName}.'
              : 'Share fair feedback about working with ${job.counterpartName}.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              for (var index = 0; index < questions.length; index++) ...[
                if (index > 0) const Divider(height: 28),
                _RatingQuestion(
                  label: questions[index].$2,
                  rating: ratings[questions[index].$1],
                  onChanged: (rating) =>
                      onRatingChanged(questions[index].$1, rating),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          padding: const EdgeInsets.all(18),
          child: TextField(
            controller: commentController,
            minLines: 4,
            maxLines: 8,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Written feedback (optional)',
              hintText: 'What went well, and what could be improved?',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_rounded),
          label: Text(submitting ? 'Publishing…' : 'Publish review'),
        ),
        const SizedBox(height: 10),
        Text(
          'Reviews are linked to completed jobs. Keep feedback factual and respectful.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _RatingQuestion extends StatelessWidget {
  const _RatingQuestion({
    required this.label,
    required this.rating,
    required this.onChanged,
  });

  final String label;
  final int? rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 2,
          children: [
            for (var value = 1; value <= 5; value++)
              Semantics(
                button: true,
                selected: rating == value,
                label: '$label: $value out of 5 stars',
                child: IconButton(
                  tooltip: '$value out of 5',
                  onPressed: () => onChanged(value),
                  icon: Icon(
                    value <= (rating ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: value <= (rating ?? 0)
                        ? Colors.amber.shade700
                        : null,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
