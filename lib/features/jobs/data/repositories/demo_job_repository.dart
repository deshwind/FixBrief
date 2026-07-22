import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/domain/repositories/job_repository.dart';
import 'package:uuid/uuid.dart';

class DemoJobRepository implements JobRepository {
  DemoJobRepository(
    this._currentUserId,
    this._role, {
    this.simulatedDelay = Duration.zero,
  }) {
    _seed();
  }

  final String _currentUserId;
  final UserRole _role;
  final Duration simulatedDelay;
  final Uuid _uuid = const Uuid();
  final StreamController<List<RepairJob>> _jobsController =
      StreamController<List<RepairJob>>.broadcast();
  final Map<String, StreamController<RepairJob?>> _jobControllers = {};
  final List<RepairJob> _jobs = [];
  bool _disposed = false;

  @override
  Stream<List<RepairJob>> watchJobs() async* {
    yield List.unmodifiable(_jobs);
    yield* _jobsController.stream;
  }

  @override
  Stream<RepairJob?> watchJob(String jobId) async* {
    yield _findJob(jobId);
    yield* _jobController(jobId).stream;
  }

  @override
  Future<RepairJob> updateStatus(
    String jobId,
    JobStatus status, {
    String? reason,
  }) async {
    await _wait();
    final index = _jobIndex(jobId);
    final current = _jobs[index];
    if (!current.status.availableTransitions(_role).contains(status)) {
      throw JobFailure(
        '${_role == UserRole.customer ? 'Customers' : 'Repair professionals'} cannot apply that job status.',
      );
    }
    final normalizedReason = reason?.trim();
    if ((normalizedReason?.length ?? 0) > 2000) {
      throw const JobFailure('Status notes must be under 2,000 characters.');
    }
    final now = DateTime.now();
    final event = JobStatusEvent(
      id: 'demo-history-${_uuid.v4()}',
      fromStatus: current.status,
      toStatus: status,
      changedBy: _currentUserId,
      reason: normalizedReason?.isEmpty == true ? null : normalizedReason,
      createdAt: now,
    );
    final updated = current.copyWith(
      status: status,
      completedAt: status == JobStatus.completed ? now : null,
      cancelledAt: status == JobStatus.cancelled ? now : null,
      cancellationReason: status == JobStatus.cancelled
          ? normalizedReason
          : null,
      disputedAt: status == JobStatus.disputed ? now : null,
      disputeReason: status == JobStatus.disputed ? normalizedReason : null,
      updatedAt: now,
      history: [...current.history, event],
    );
    _jobs[index] = updated;
    _emit(updated);
    return updated;
  }

  @override
  Future<JobReview> submitReview(String jobId, JobReviewInput input) async {
    await _wait();
    _validateReview(input);
    final index = _jobIndex(jobId);
    final current = _jobs[index];
    if (current.status != JobStatus.completed) {
      throw const JobFailure(
        'Reviews are available only after a completed job.',
      );
    }
    if (current.hasMyReview) {
      throw const JobFailure('You have already reviewed this job.');
    }
    final isCustomer = _role == UserRole.customer;
    final now = DateTime.now();
    final review = JobReview(
      id: 'demo-review-${_uuid.v4()}',
      jobId: current.id,
      authorId: _currentUserId,
      reviewedUserId: isCustomer ? current.repairerId : current.customerId,
      direction: isCustomer
          ? ReviewDirection.customerToRepairer
          : ReviewDirection.repairerToCustomer,
      overallRating: input.overallRating,
      qualityRating: isCustomer ? input.qualityRating : null,
      communicationRating: input.communicationRating,
      punctualityRating: isCustomer ? input.punctualityRating : null,
      valueRating: isCustomer ? input.valueRating : null,
      quoteAccuracyRating: isCustomer ? input.quoteAccuracyRating : null,
      descriptionAccuracyRating: isCustomer
          ? null
          : input.descriptionAccuracyRating,
      attendanceRating: isCustomer ? null : input.attendanceRating,
      locationAccessibilityRating: isCustomer
          ? null
          : input.locationAccessibilityRating,
      comment: input.comment.trim().isEmpty ? null : input.comment.trim(),
      authorName: isCustomer ? 'Alex Morgan' : 'Sam North',
      createdAt: now,
    );
    final updated = current.copyWith(
      reviews: [...current.reviews, review],
      hasMyReview: true,
      updatedAt: now,
    );
    _jobs[index] = updated;
    _emit(updated);
    return review;
  }

  @override
  Future<JobReview> respondToReview(String reviewId, String response) async {
    await _wait();
    final normalized = response.trim();
    if (normalized.length < 2 || normalized.length > 3000) {
      throw const JobFailure(
        'Enter a response between 2 and 3,000 characters.',
      );
    }
    if (_role != UserRole.repairer) {
      throw const JobFailure(
        'Only the reviewed repair professional can reply.',
      );
    }
    for (var jobIndex = 0; jobIndex < _jobs.length; jobIndex++) {
      final job = _jobs[jobIndex];
      final reviewIndex = job.reviews.indexWhere(
        (review) => review.id == reviewId,
      );
      if (reviewIndex < 0) {
        continue;
      }
      final current = job.reviews[reviewIndex];
      if (current.direction != ReviewDirection.customerToRepairer ||
          current.reviewedUserId != _currentUserId) {
        throw const JobFailure(
          'Only the reviewed repair professional can reply.',
        );
      }
      if (current.repairerResponse != null) {
        throw const JobFailure('A response has already been submitted.');
      }
      final updatedReview = _copyReview(
        current,
        response: normalized,
        respondedAt: DateTime.now(),
      );
      final reviews = [...job.reviews]..[reviewIndex] = updatedReview;
      final updatedJob = job.copyWith(
        reviews: reviews,
        updatedAt: DateTime.now(),
      );
      _jobs[jobIndex] = updatedJob;
      _emit(updatedJob);
      return updatedReview;
    }
    throw const JobFailure('This review is no longer available.');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _jobsController.close();
    for (final controller in _jobControllers.values) {
      await controller.close();
    }
  }

  void _seed() {
    final now = DateTime.now();
    final isCustomer = _role == UserRole.customer;
    final customerId = isCustomer
        ? _currentUserId
        : '10000000-0000-4000-8000-000000000001';
    final repairerId = isCustomer
        ? '20000000-0000-4000-8000-000000000001'
        : _currentUserId;
    final activeHistory = [
      JobStatusEvent(
        id: 'demo-history-accepted',
        toStatus: JobStatus.repairScheduled,
        changedBy: customerId,
        reason: 'Quote accepted and repair arranged.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      JobStatusEvent(
        id: 'demo-history-started',
        fromStatus: JobStatus.repairScheduled,
        toStatus: JobStatus.repairInProgress,
        changedBy: repairerId,
        reason: 'Inspection completed and repair work started.',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];
    _jobs.add(
      RepairJob(
        id: 'demo-job-vehicle',
        requestId: 'demo-request-vehicle',
        acceptedQuoteId: 'demo-customer-quote-mancunian',
        customerId: customerId,
        repairerId: repairerId,
        itemName: '2018 Ford Focus',
        counterpartName: isCustomer ? 'Northside Auto Care' : 'Alex Morgan',
        businessName: 'Northside Auto Care',
        approximateArea: 'Manchester M20',
        status: JobStatus.repairInProgress,
        agreedMinimumMinor: 15500,
        agreedMaximumMinor: 33500,
        currencyCode: 'GBP',
        acceptedAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 5)),
        history: activeHistory,
        reviews: const [],
        hasMyReview: false,
      ),
    );

    final completedId = 'demo-job-phone';
    final completedAt = now.subtract(const Duration(days: 14));
    final seedReview = JobReview(
      id: 'demo-review-existing',
      jobId: completedId,
      authorId: isCustomer ? repairerId : customerId,
      reviewedUserId: _currentUserId,
      direction: isCustomer
          ? ReviewDirection.repairerToCustomer
          : ReviewDirection.customerToRepairer,
      overallRating: 5,
      qualityRating: isCustomer ? null : 5,
      communicationRating: 5,
      punctualityRating: isCustomer ? null : 5,
      valueRating: isCustomer ? null : 4,
      quoteAccuracyRating: isCustomer ? null : 5,
      descriptionAccuracyRating: isCustomer ? 5 : null,
      attendanceRating: isCustomer ? 5 : null,
      locationAccessibilityRating: isCustomer ? 4 : null,
      comment: isCustomer
          ? 'Clear description and easy appointment access.'
          : 'Clear communication and the final cost stayed within the estimate.',
      authorName: isCustomer ? 'Northside Auto Care' : 'Alex Morgan',
      createdAt: completedAt.add(const Duration(days: 1)),
    );
    _jobs.add(
      RepairJob(
        id: completedId,
        requestId: 'demo-request-phone',
        acceptedQuoteId: 'demo-quote-phone',
        customerId: customerId,
        repairerId: repairerId,
        itemName: 'Phone charging port',
        counterpartName: isCustomer ? 'Northside Auto Care' : 'Alex Morgan',
        businessName: 'Northside Auto Care',
        approximateArea: 'Manchester M20',
        status: JobStatus.completed,
        agreedMinimumMinor: 6500,
        agreedMaximumMinor: 8000,
        currencyCode: 'GBP',
        acceptedAt: now.subtract(const Duration(days: 18)),
        completedAt: completedAt,
        updatedAt: completedAt,
        history: [
          JobStatusEvent(
            id: 'demo-phone-scheduled',
            toStatus: JobStatus.repairScheduled,
            createdAt: now.subtract(const Duration(days: 18)),
          ),
          JobStatusEvent(
            id: 'demo-phone-progress',
            fromStatus: JobStatus.repairScheduled,
            toStatus: JobStatus.repairInProgress,
            createdAt: now.subtract(const Duration(days: 15)),
          ),
          JobStatusEvent(
            id: 'demo-phone-completed',
            fromStatus: JobStatus.repairInProgress,
            toStatus: JobStatus.completed,
            createdAt: completedAt,
          ),
        ],
        reviews: [seedReview],
        hasMyReview: false,
      ),
    );
  }

  void _validateReview(JobReviewInput input) {
    final ratings = [
      input.overallRating,
      input.communicationRating,
      input.qualityRating,
      input.punctualityRating,
      input.valueRating,
      input.quoteAccuracyRating,
      input.descriptionAccuracyRating,
      input.attendanceRating,
      input.locationAccessibilityRating,
    ].whereType<int>();
    if (ratings.any((rating) => rating < 1 || rating > 5)) {
      throw const JobFailure('Review ratings must be between 1 and 5.');
    }
    if (input.comment.trim().length > 5000) {
      throw const JobFailure('Review comments must be under 5,000 characters.');
    }
  }

  Future<void> _wait() => Future<void>.delayed(simulatedDelay);

  RepairJob? _findJob(String id) =>
      _jobs.where((job) => job.id == id).firstOrNull;

  int _jobIndex(String id) {
    final index = _jobs.indexWhere((job) => job.id == id);
    if (index < 0) {
      throw const JobFailure('This job is no longer available.');
    }
    return index;
  }

  StreamController<RepairJob?> _jobController(String id) {
    return _jobControllers.putIfAbsent(
      id,
      StreamController<RepairJob?>.broadcast,
    );
  }

  void _emit(RepairJob job) {
    _jobsController.add(List.unmodifiable(_jobs));
    _jobControllers[job.id]?.add(job);
  }
}

JobReview _copyReview(
  JobReview review, {
  required String response,
  required DateTime respondedAt,
}) {
  return JobReview(
    id: review.id,
    jobId: review.jobId,
    authorId: review.authorId,
    reviewedUserId: review.reviewedUserId,
    direction: review.direction,
    overallRating: review.overallRating,
    qualityRating: review.qualityRating,
    communicationRating: review.communicationRating,
    punctualityRating: review.punctualityRating,
    valueRating: review.valueRating,
    quoteAccuracyRating: review.quoteAccuracyRating,
    descriptionAccuracyRating: review.descriptionAccuracyRating,
    attendanceRating: review.attendanceRating,
    locationAccessibilityRating: review.locationAccessibilityRating,
    comment: review.comment,
    repairerResponse: response,
    respondedAt: respondedAt,
    authorName: review.authorName,
    createdAt: review.createdAt,
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
