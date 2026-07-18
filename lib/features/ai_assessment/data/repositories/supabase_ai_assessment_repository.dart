import 'dart:async';

import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/domain/repositories/ai_assessment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAiAssessmentRepository implements AiAssessmentRepository {
  SupabaseAiAssessmentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AiAssessment> generate(
    AiAssessmentRequest request, {
    bool regenerate = false,
  }) async {
    final data = await _invoke(<String, Object?>{
      'action': 'generate',
      'request_id': request.requestId,
      'regenerate': regenerate,
    });
    return _assessmentFrom(data);
  }

  @override
  Future<AiAssessment> answerFollowUpQuestions(
    AiAssessmentRequest request,
    Map<String, String> answers,
  ) async {
    final data = await _invoke(<String, Object?>{
      'action': 'answer',
      'request_id': request.requestId,
      'answers': answers.entries
          .map(
            (entry) => <String, String>{
              'question_id': entry.key,
              'answer': entry.value,
            },
          )
          .toList(),
    });
    return _assessmentFrom(data);
  }

  @override
  Future<void> saveRepairBrief(String requestId, RepairBriefEdits edits) async {
    await _invoke(<String, Object?>{
      'action': 'save_brief',
      'request_id': requestId,
      'edits': edits.toJson(),
    });
  }

  @override
  Future<void> publish(String requestId, RepairBriefEdits edits) async {
    await _invoke(<String, Object?>{
      'action': 'publish',
      'request_id': requestId,
      'edits': edits.toJson(),
    });
  }

  AiAssessment _assessmentFrom(Map<String, Object?> data) {
    final assessment = data['assessment'];
    if (assessment is! Map) {
      throw const AiAssessmentFailure(
        'The assessment service returned an incomplete response.',
      );
    }
    try {
      return AiAssessmentValidator.validate(
        AiAssessment.fromJson(
          assessment.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          ),
        ),
      );
    } on AiAssessmentFailure {
      rethrow;
    } on Object {
      throw const AiAssessmentFailure(
        'The assessment response could not be read safely.',
      );
    }
  }

  Future<Map<String, Object?>> _invoke(Map<String, Object?> body) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client.functions
            .invoke('generate-ai-assessment', body: body)
            .timeout(const Duration(seconds: 40));
        if (response.status < 200 || response.status >= 300) {
          final message = _errorMessage(response.data);
          throw AiAssessmentFailure(
            message,
            canRetry:
                response.status == 408 ||
                response.status == 429 ||
                response.status >= 500,
          );
        }
        final data = response.data;
        if (data is! Map) {
          throw const AiAssessmentFailure(
            'The assessment service returned an incomplete response.',
          );
        }
        return data.map(
          (key, value) => MapEntry(key.toString(), value as Object?),
        );
      } on AiAssessmentFailure catch (failure) {
        lastError = failure;
        if (!failure.canRetry || attempt == 1) {
          rethrow;
        }
      } on TimeoutException catch (error) {
        lastError = error;
        if (attempt == 1) {
          throw const AiAssessmentFailure(
            'The assessment is taking longer than expected. Please try again.',
          );
        }
      } on Object catch (error) {
        lastError = error;
        if (attempt == 1) {
          throw const AiAssessmentFailure(
            'The assessment service could not be reached. Your request is safe.',
          );
        }
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
    throw AiAssessmentFailure('Assessment failed: $lastError');
  }

  String _errorMessage(Object? data) {
    if (data is Map && data['error'] is String) {
      return data['error']! as String;
    }
    return 'The assessment could not be completed. Please try again.';
  }
}
