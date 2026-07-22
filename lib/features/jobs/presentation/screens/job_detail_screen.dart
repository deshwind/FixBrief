import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/presentation/providers/job_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  const JobDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  var _updating = false;

  @override
  Widget build(BuildContext context) {
    final role =
        ref.watch(authSessionControllerProvider).onboarding.role ??
        UserRole.customer;
    final job = ref.watch(jobProvider(widget.jobId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job details'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: FluidBackground(
        accent: role == UserRole.customer
            ? LiquidGlassColors.vehicles
            : LiquidGlassColors.industrial,
        child: job.when(
          loading: () => const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Loading job'),
          ),
          error: (error, stackTrace) => _JobError(
            message: error is JobFailure
                ? error.message
                : 'This job could not be loaded. Try again.',
            onRetry: () => ref.invalidate(jobProvider(widget.jobId)),
          ),
          data: (value) => value == null
              ? const _MissingJob()
              : _JobContent(
                  job: value,
                  role: role,
                  updating: _updating,
                  onRefresh: () async {
                    ref.invalidate(jobProvider(widget.jobId));
                    await ref.read(jobProvider(widget.jobId).future);
                  },
                  onStatusSelected: (status) => _changeStatus(value, status),
                  onReview: () => context.push(
                    role == UserRole.customer
                        ? AppPaths.customerJobReviewFor(value.id)
                        : AppPaths.repairerJobReviewFor(value.id),
                  ),
                  onRespond: _respondToReview,
                ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(RepairJob job, JobStatus status) async {
    final result = await _showStatusDialog(context, status);
    if (!mounted || result == null) {
      return;
    }
    setState(() => _updating = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .updateStatus(job.id, status, reason: result.note);
      ref.invalidate(jobProvider(widget.jobId));
      ref.invalidate(jobsProvider);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job updated to ${status.label.toLowerCase()}.'),
        ),
      );
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
            content: Text('The job could not be updated. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _respondToReview(JobReview review) async {
    final response = await _showResponseDialog(context);
    if (!mounted || response == null) {
      return;
    }
    setState(() => _updating = true);
    try {
      await ref
          .read(jobRepositoryProvider)
          .respondToReview(review.id, response);
      ref.invalidate(jobProvider(widget.jobId));
      ref.invalidate(jobsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your response has been published.')),
        );
      }
    } on JobFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The response could not be sent.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }
}

class _JobContent extends StatelessWidget {
  const _JobContent({
    required this.job,
    required this.role,
    required this.updating,
    required this.onRefresh,
    required this.onStatusSelected,
    required this.onReview,
    required this.onRespond,
  });

  final RepairJob job;
  final UserRole role;
  final bool updating;
  final Future<void> Function() onRefresh;
  final ValueChanged<JobStatus> onStatusSelected;
  final VoidCallback onReview;
  final ValueChanged<JobReview> onRespond;

  @override
  Widget build(BuildContext context) {
    final transitions = job.status.availableTransitions(role);
    final formatter = NumberFormat.simpleCurrency(
      name: job.currencyCode,
      decimalDigits: 0,
    );
    final price =
        '${formatter.format(job.agreedMinimumMinor / 100)}\u2013${formatter.format(job.agreedMaximumMinor / 100)}';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          LiquidGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.itemName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(job.counterpartName),
                          if (job.approximateArea != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              job.approximateArea!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    LiquidGlassStatusPill(
                      label: job.status.label,
                      status: _statusStyle(job.status),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.payments_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Agreed estimate $price',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppPaths.conversations),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(
                    role == UserRole.customer
                        ? 'Message repair professional'
                        : 'Message customer',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Repair timeline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          LiquidGlassCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: _JobTimeline(job: job),
          ),
          if (transitions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Update job', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    role == UserRole.customer
                        ? 'Confirm completion once the repair is finished, or raise a concern.'
                        : 'Choose the next accurate status for this repair.',
                  ),
                  const SizedBox(height: 14),
                  for (final status in transitions) ...[
                    FilledButton.icon(
                      onPressed: updating
                          ? null
                          : () => onStatusSelected(status),
                      icon: Icon(_statusActionIcon(status)),
                      label: Text(status.actionLabel),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (updating)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Updating job',
                    ),
                ],
              ),
            ),
          ],
          if (job.canReview) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: updating ? null : onReview,
              icon: const Icon(Icons.star_outline_rounded),
              label: Text(
                role == UserRole.customer
                    ? 'Review repair professional'
                    : 'Review customer',
              ),
            ),
          ],
          if (job.history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Status history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LiquidGlassCard(
              padding: const EdgeInsets.all(18),
              child: _StatusHistory(events: job.history),
            ),
          ],
          if (job.reviews.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final review in job.reviews) ...[
              _ReviewCard(
                review: review,
                canRespond:
                    role == UserRole.repairer &&
                    review.direction == ReviewDirection.customerToRepairer &&
                    review.repairerResponse == null,
                onRespond: updating ? null : () => onRespond(review),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _JobTimeline extends StatelessWidget {
  const _JobTimeline({required this.job});

  final RepairJob job;

  static const _jobMilestones = [
    JobStatus.inspectionRequested,
    JobStatus.inspectionBooked,
    JobStatus.repairScheduled,
    JobStatus.repairInProgress,
    JobStatus.waitingForParts,
    JobStatus.readyForCollection,
    JobStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final reachedStatuses = <JobStatus>{
      job.status,
      ...job.history.map((event) => event.toStatus),
    };
    final furthestReached = _jobMilestones.indexed
        .where((entry) => reachedStatuses.contains(entry.$2))
        .map((entry) => entry.$1)
        .fold(-1, (highest, index) => index > highest ? index : highest);
    final rows = <_TimelineRowData>[
      _TimelineRowData(
        label: 'Request submitted',
        state: _TimelineState.done,
        date: job.acceptedAt,
      ),
      _TimelineRowData(
        label: 'Quotes received',
        state: _TimelineState.done,
        date: job.acceptedAt,
      ),
      _TimelineRowData(
        label: 'Quote accepted',
        state: _TimelineState.done,
        date: job.acceptedAt,
      ),
      for (final (index, milestone) in _jobMilestones.indexed)
        _TimelineRowData(
          label: milestone.label,
          state: job.status == milestone && !job.status.isTerminal
              ? _TimelineState.current
              : reachedStatuses.contains(milestone)
              ? _TimelineState.done
              : index < furthestReached &&
                    (milestone == JobStatus.waitingForParts ||
                        milestone == JobStatus.readyForCollection)
              ? _TimelineState.skipped
              : index < furthestReached
              ? _TimelineState.done
              : _TimelineState.upcoming,
          date: _eventDate(job, milestone),
        ),
    ];
    if (job.status == JobStatus.cancelled || job.status == JobStatus.disputed) {
      rows.add(
        _TimelineRowData(
          label: job.status.label,
          state: _TimelineState.alert,
          date: job.status == JobStatus.cancelled
              ? job.cancelledAt
              : job.disputedAt,
        ),
      );
    }
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++)
          _TimelineRow(
            data: rows[index],
            showConnector: index < rows.length - 1,
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.data, required this.showConnector});

  final _TimelineRowData data;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final color = switch (data.state) {
      _TimelineState.done => colors.success,
      _TimelineState.current => Theme.of(context).colorScheme.primary,
      _TimelineState.alert => colors.danger,
      _TimelineState.skipped => colors.secondaryText,
      _TimelineState.upcoming => colors.secondaryText,
    };
    final icon = switch (data.state) {
      _TimelineState.done => Icons.check_rounded,
      _TimelineState.current => Icons.radio_button_checked_rounded,
      _TimelineState.alert => Icons.error_outline_rounded,
      _TimelineState.skipped => Icons.remove_circle_outline_rounded,
      _TimelineState.upcoming => Icons.circle_outlined,
    };
    final stateLabel = switch (data.state) {
      _TimelineState.done => 'Complete',
      _TimelineState.current => 'Current',
      _TimelineState.alert => 'Attention',
      _TimelineState.skipped => 'Not needed',
      _TimelineState.upcoming => 'Upcoming',
    };
    return Semantics(
      label: '${data.label}, $stateLabel',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Icon(icon, color: color, size: 22),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 38,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: color.withValues(alpha: 0.35),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: TextStyle(
                      fontWeight: data.state == _TimelineState.current
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.date == null
                        ? stateLabel
                        : '$stateLabel · ${DateFormat('d MMM y, HH:mm').format(data.date!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHistory extends StatelessWidget {
  const _StatusHistory({required this.events});

  final List<JobStatusEvent> events;

  @override
  Widget build(BuildContext context) {
    final ordered = [...events]
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return Column(
      children: [
        for (var index = 0; index < ordered.length; index++) ...[
          if (index > 0) const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history_rounded, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ordered[index].toStatus.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      DateFormat(
                        'd MMM y, HH:mm',
                      ).format(ordered[index].createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (ordered[index].reason != null) ...[
                      const SizedBox(height: 5),
                      Text(ordered[index].reason!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.canRespond,
    required this.onRespond,
  });

  final JobReview review;
  final bool canRespond;
  final VoidCallback? onRespond;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.authorName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Semantics(
                label: '${review.overallRating} out of 5 stars',
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 3),
                    Text('${review.overallRating}/5'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            review.direction == ReviewDirection.customerToRepairer
                ? 'Customer review'
                : 'Repair professional review',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (review.comment != null) ...[
            const SizedBox(height: 12),
            Text(review.comment!),
          ],
          if (review.repairerResponse != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Repair professional response',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(review.repairerResponse!),
                ],
              ),
            ),
          ],
          if (canRespond) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRespond,
              icon: const Icon(Icons.reply_rounded),
              label: const Text('Respond publicly'),
            ),
          ],
        ],
      ),
    );
  }
}

class _JobError extends StatelessWidget {
  const _JobError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _MissingJob extends StatelessWidget {
  const _MissingJob();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('This job is no longer available.'));
  }
}

class _TimelineRowData {
  const _TimelineRowData({required this.label, required this.state, this.date});

  final String label;
  final _TimelineState state;
  final DateTime? date;
}

enum _TimelineState { done, current, upcoming, skipped, alert }

class _StatusDialogResult {
  const _StatusDialogResult(this.note);

  final String? note;
}

Future<_StatusDialogResult?> _showStatusDialog(
  BuildContext context,
  JobStatus status,
) {
  var note = '';
  final needsReason =
      status == JobStatus.cancelled || status == JobStatus.disputed;
  return showDialog<_StatusDialogResult>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final valid = !needsReason || note.trim().length >= 5;
        return AlertDialog(
          title: Text(status.actionLabel),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status == JobStatus.completed
                      ? 'Confirm that the repair work has been completed. Reviews become available after confirmation.'
                      : 'This update is shared with the other person and added to the permanent status history.',
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLength: 2000,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (value) => setDialogState(() => note = value),
                  decoration: InputDecoration(
                    labelText: needsReason
                        ? 'Reason (required)'
                        : 'Update note',
                    hintText: needsReason
                        ? 'Explain what happened'
                        : 'Add useful details (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: valid
                  ? () => Navigator.pop(
                      dialogContext,
                      _StatusDialogResult(
                        note.trim().isEmpty ? null : note.trim(),
                      ),
                    )
                  : null,
              child: const Text('Confirm update'),
            ),
          ],
        );
      },
    ),
  );
}

Future<String?> _showResponseDialog(BuildContext context) {
  var response = '';
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Respond to review'),
        content: SingleChildScrollView(
          child: TextField(
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 3000,
            onChanged: (value) => setDialogState(() => response = value),
            decoration: const InputDecoration(
              hintText: 'Write a professional public response',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: response.trim().length >= 2
                ? () => Navigator.pop(dialogContext, response.trim())
                : null,
            child: const Text('Publish response'),
          ),
        ],
      ),
    ),
  );
}

DateTime? _eventDate(RepairJob job, JobStatus status) {
  if (status == JobStatus.completed && job.completedAt != null) {
    return job.completedAt;
  }
  for (final event in job.history.reversed) {
    if (event.toStatus == status) {
      return event.createdAt;
    }
  }
  return null;
}

IconData _statusActionIcon(JobStatus status) => switch (status) {
  JobStatus.completed => Icons.task_alt_rounded,
  JobStatus.cancelled => Icons.cancel_outlined,
  JobStatus.disputed => Icons.report_problem_outlined,
  JobStatus.waitingForParts => Icons.inventory_2_outlined,
  JobStatus.readyForCollection => Icons.shopping_bag_outlined,
  _ => Icons.update_rounded,
};

LiquidGlassStatus _statusStyle(JobStatus status) => switch (status) {
  JobStatus.completed => LiquidGlassStatus.success,
  JobStatus.cancelled || JobStatus.disputed => LiquidGlassStatus.danger,
  JobStatus.waitingForParts => LiquidGlassStatus.warning,
  _ => LiquidGlassStatus.info,
};
