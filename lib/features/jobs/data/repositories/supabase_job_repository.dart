import 'dart:async';

import 'package:fixbrief/features/jobs/domain/entities/job_models.dart';
import 'package:fixbrief/features/jobs/domain/repositories/job_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseJobRepository implements JobRepository {
  SupabaseJobRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<RepairJob>> watchJobs() async* {
    yield await _loadJobs();
    final changes = _client
        .from('jobs')
        .stream(primaryKey: const ['id'])
        .order('updated_at', ascending: false);
    await for (final _ in changes) {
      yield await _loadJobs();
    }
  }

  @override
  Stream<RepairJob?> watchJob(String jobId) async* {
    _validateId(jobId);
    yield await _loadJob(jobId);
    final changes = _client
        .from('jobs')
        .stream(primaryKey: const ['id'])
        .eq('id', jobId);
    await for (final _ in changes) {
      yield await _loadJob(jobId);
    }
  }

  @override
  Future<RepairJob> updateStatus(
    String jobId,
    JobStatus status, {
    String? reason,
  }) async {
    _validateId(jobId);
    await _rpc(
      'set_job_status',
      params: <String, Object?>{
        'job_id': jobId,
        'new_status': status.databaseValue,
        'reason': reason?.trim(),
      },
    );
    return _requireJob(await _loadJob(jobId));
  }

  @override
  Future<JobReview> submitReview(String jobId, JobReviewInput input) async {
    _validateId(jobId);
    final response = await _rpc(
      'submit_job_review',
      params: <String, Object?>{
        'target_job_id': jobId,
        'review_payload': input.toJson(),
      },
    );
    return JobReview.fromJson(_map(response));
  }

  @override
  Future<JobReview> respondToReview(String reviewId, String response) async {
    _validateId(reviewId);
    final result = await _rpc(
      'respond_to_job_review',
      params: <String, Object?>{
        'target_review_id': reviewId,
        'response_text': response.trim(),
      },
    );
    return JobReview.fromJson(_map(result));
  }

  @override
  Future<void> dispose() async {}

  Future<List<RepairJob>> _loadJobs() async {
    final response = await _rpc('get_jobs');
    return _maps(response).map(RepairJob.fromJson).toList(growable: false);
  }

  Future<RepairJob?> _loadJob(String jobId) async {
    final response = await _rpc(
      'get_job_details',
      params: <String, Object?>{'target_job_id': jobId},
    );
    if (response == null) {
      return null;
    }
    final data = _map(response);
    return data.isEmpty ? null : RepairJob.fromJson(data);
  }

  RepairJob _requireJob(RepairJob? job) {
    if (job == null) {
      throw const JobFailure('This job is no longer available.');
    }
    return job;
  }

  Future<Object?> _rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    try {
      return await _client
          .rpc<Object?>(function, params: params)
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      throw _mapError(error);
    } on TimeoutException {
      throw const JobFailure(
        'The job service is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  JobFailure _mapError(PostgrestException error) {
    final setupMissing =
        error.code == '42P01' ||
        error.code == '42703' ||
        error.code == '42883' ||
        error.code == 'PGRST202';
    final invalid =
        error.code == '22023' ||
        error.code == '22P02' ||
        error.code == '23505' ||
        error.code == '23514';
    return JobFailure(
      setupMissing
          ? 'The Stage 10 jobs migration has not been deployed in this environment.'
          : invalid
          ? error.message
          : error.code == '42501'
          ? 'This job or review is not available to your account.'
          : 'We could not update this job. Check your connection and try again.',
      code: error.code,
    );
  }

  void _validateId(String id) {
    if (id.trim().isEmpty || id.length > 100) {
      throw const JobFailure('This job link is invalid.');
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, Object?>{};
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}
