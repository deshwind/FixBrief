import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/jobs/data/repositories/demo_job_repository.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 10 demo job repository', () {
    test('customer completes an eligible job and submits one review', () async {
      final repository = DemoJobRepository('customer-user', UserRole.customer);
      addTearDown(repository.dispose);

      final jobs = await repository.watchJobs().first;
      final active = jobs.firstWhere((job) => job.id == 'demo-job-vehicle');
      expect(active.status, JobStatus.repairInProgress);
      expect(
        active.status.availableTransitions(UserRole.customer),
        contains(JobStatus.completed),
      );

      final completed = await repository.updateStatus(
        active.id,
        JobStatus.completed,
        reason: 'Repair collected and checked.',
      );
      expect(completed.status, JobStatus.completed);
      expect(completed.completedAt, isNotNull);
      expect(completed.history.last.reason, 'Repair collected and checked.');

      final review = await repository.submitReview(
        completed.id,
        const JobReviewInput(
          overallRating: 5,
          communicationRating: 5,
          qualityRating: 5,
          punctualityRating: 4,
          valueRating: 4,
          quoteAccuracyRating: 5,
          comment: 'Clear updates and a careful repair.',
        ),
      );
      expect(review.direction, ReviewDirection.customerToRepairer);
      expect(
        (await repository.watchJob(completed.id).first)!.hasMyReview,
        isTrue,
      );

      await expectLater(
        repository.submitReview(
          completed.id,
          const JobReviewInput(
            overallRating: 5,
            communicationRating: 5,
            qualityRating: 5,
            punctualityRating: 5,
            valueRating: 5,
            quoteAccuracyRating: 5,
            comment: '',
          ),
        ),
        throwsA(isA<JobFailure>()),
      );
    });

    test('repairer updates progress but cannot confirm completion', () async {
      final repository = DemoJobRepository('repairer-user', UserRole.repairer);
      addTearDown(repository.dispose);

      final active = (await repository.watchJobs().first).firstWhere(
        (job) => job.id == 'demo-job-vehicle',
      );
      final waiting = await repository.updateStatus(
        active.id,
        JobStatus.waitingForParts,
        reason: 'Replacement component ordered.',
      );
      expect(waiting.status, JobStatus.waitingForParts);
      expect(waiting.history.last.changedBy, 'repairer-user');

      await expectLater(
        repository.updateStatus(waiting.id, JobStatus.completed),
        throwsA(isA<JobFailure>()),
      );
    });

    test('repairer reviews customer and responds to customer review', () async {
      final repository = DemoJobRepository('repairer-user', UserRole.repairer);
      addTearDown(repository.dispose);
      final completed = (await repository.watchJobs().first).firstWhere(
        (job) => job.id == 'demo-job-phone',
      );

      final customerReview = completed.reviews.single;
      final response = await repository.respondToReview(
        customerReview.id,
        'Thank you for the thoughtful feedback.',
      );
      expect(response.repairerResponse, contains('thoughtful feedback'));

      final repairerReview = await repository.submitReview(
        completed.id,
        const JobReviewInput(
          overallRating: 5,
          communicationRating: 5,
          descriptionAccuracyRating: 5,
          attendanceRating: 5,
          locationAccessibilityRating: 4,
          comment: 'Accurate description and easy handover.',
        ),
      );
      expect(repairerReview.direction, ReviewDirection.repairerToCustomer);
      expect(repairerReview.qualityRating, isNull);
    });
  });

  test('job aggregate safely parses status, history, and review JSON', () {
    final job = RepairJob.fromJson({
      'id': 'job-1',
      'request_id': 'request-1',
      'accepted_quote_id': 'quote-1',
      'customer_id': 'customer-1',
      'repairer_id': 'repairer-1',
      'item_name': 'Laptop',
      'counterpart_name': 'Repair Lab',
      'status': 'waiting_for_parts',
      'agreed_minimum_minor': '12000',
      'agreed_maximum_minor': 18000,
      'currency_code': 'GBP',
      'accepted_at': '2026-07-20T10:00:00Z',
      'updated_at': '2026-07-22T10:00:00Z',
      'history': [
        {
          'id': 1,
          'from_status': 'repair_in_progress',
          'to_status': 'waiting_for_parts',
          'created_at': '2026-07-22T10:00:00Z',
        },
      ],
      'reviews': <Object?>[],
      'has_my_review': false,
    });

    expect(job.status, JobStatus.waitingForParts);
    expect(job.history.single.fromStatus, JobStatus.repairInProgress);
    expect(job.agreedMinimumMinor, 12000);
  });
}
