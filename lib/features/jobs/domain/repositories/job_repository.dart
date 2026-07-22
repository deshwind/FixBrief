import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';

abstract interface class JobRepository {
  Stream<List<RepairJob>> watchJobs();

  Stream<RepairJob?> watchJob(String jobId);

  Future<RepairJob> updateStatus(
    String jobId,
    JobStatus status, {
    String? reason,
  });

  Future<JobReview> submitReview(String jobId, JobReviewInput input);

  Future<JobReview> respondToReview(String reviewId, String response);

  Future<void> dispose();
}
