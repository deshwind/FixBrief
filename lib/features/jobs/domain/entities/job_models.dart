import 'package:fixbrief/core/constants/user_role.dart';
import 'package:flutter/foundation.dart';

enum JobStatus {
  inspectionRequested,
  inspectionBooked,
  repairScheduled,
  repairInProgress,
  waitingForParts,
  readyForCollection,
  completed,
  cancelled,
  disputed,
}

extension JobStatusView on JobStatus {
  String get databaseValue => switch (this) {
    JobStatus.inspectionRequested => 'inspection_requested',
    JobStatus.inspectionBooked => 'inspection_booked',
    JobStatus.repairScheduled => 'repair_scheduled',
    JobStatus.repairInProgress => 'repair_in_progress',
    JobStatus.waitingForParts => 'waiting_for_parts',
    JobStatus.readyForCollection => 'ready_for_collection',
    JobStatus.completed => 'completed',
    JobStatus.cancelled => 'cancelled',
    JobStatus.disputed => 'disputed',
  };

  String get label => switch (this) {
    JobStatus.inspectionRequested => 'Inspection requested',
    JobStatus.inspectionBooked => 'Inspection booked',
    JobStatus.repairScheduled => 'Repair scheduled',
    JobStatus.repairInProgress => 'Repair in progress',
    JobStatus.waitingForParts => 'Waiting for parts',
    JobStatus.readyForCollection => 'Ready for collection',
    JobStatus.completed => 'Completed',
    JobStatus.cancelled => 'Cancelled',
    JobStatus.disputed => 'Disputed',
  };

  String get actionLabel => switch (this) {
    JobStatus.inspectionRequested => 'Request inspection',
    JobStatus.inspectionBooked => 'Mark inspection booked',
    JobStatus.repairScheduled => 'Schedule repair',
    JobStatus.repairInProgress => 'Start repair',
    JobStatus.waitingForParts => 'Mark waiting for parts',
    JobStatus.readyForCollection => 'Mark ready for collection',
    JobStatus.completed => 'Confirm repair completed',
    JobStatus.cancelled => 'Cancel job',
    JobStatus.disputed => 'Raise a concern',
  };

  bool get isTerminal =>
      this == JobStatus.completed || this == JobStatus.cancelled;

  List<JobStatus> availableTransitions(UserRole role) {
    final allowedByState = switch (this) {
      JobStatus.inspectionRequested => const [
        JobStatus.inspectionBooked,
        JobStatus.cancelled,
        JobStatus.disputed,
      ],
      JobStatus.inspectionBooked => const [
        JobStatus.repairScheduled,
        JobStatus.cancelled,
        JobStatus.disputed,
      ],
      JobStatus.repairScheduled => const [
        JobStatus.repairInProgress,
        JobStatus.cancelled,
        JobStatus.disputed,
      ],
      JobStatus.repairInProgress => const [
        JobStatus.waitingForParts,
        JobStatus.readyForCollection,
        JobStatus.completed,
        JobStatus.cancelled,
        JobStatus.disputed,
      ],
      JobStatus.waitingForParts => const [
        JobStatus.repairInProgress,
        JobStatus.readyForCollection,
        JobStatus.completed,
        JobStatus.cancelled,
        JobStatus.disputed,
      ],
      JobStatus.readyForCollection => const [
        JobStatus.repairInProgress,
        JobStatus.completed,
        JobStatus.disputed,
      ],
      JobStatus.completed => const [JobStatus.disputed],
      JobStatus.cancelled => const [JobStatus.disputed],
      JobStatus.disputed => const [
        JobStatus.repairInProgress,
        JobStatus.completed,
        JobStatus.cancelled,
      ],
    };
    if (role == UserRole.customer) {
      final canComplete = switch (this) {
        JobStatus.repairInProgress ||
        JobStatus.waitingForParts ||
        JobStatus.readyForCollection => true,
        _ => false,
      };
      final canCancel = switch (this) {
        JobStatus.inspectionRequested ||
        JobStatus.inspectionBooked ||
        JobStatus.repairScheduled => true,
        _ => false,
      };
      return allowedByState
          .where(
            (candidate) =>
                candidate == JobStatus.disputed ||
                (candidate == JobStatus.completed && canComplete) ||
                (candidate == JobStatus.cancelled && canCancel),
          )
          .toList(growable: false);
    }
    const roleStatuses = {
      JobStatus.inspectionBooked,
      JobStatus.repairScheduled,
      JobStatus.repairInProgress,
      JobStatus.waitingForParts,
      JobStatus.readyForCollection,
      JobStatus.cancelled,
      JobStatus.disputed,
    };
    return allowedByState.where(roleStatuses.contains).toList(growable: false);
  }
}

JobStatus jobStatusFromDatabase(Object? value) {
  final normalized = value?.toString() ?? '';
  return JobStatus.values.firstWhere(
    (status) => status.databaseValue == normalized,
    orElse: () => JobStatus.inspectionRequested,
  );
}

enum ReviewDirection { customerToRepairer, repairerToCustomer }

extension ReviewDirectionView on ReviewDirection {
  String get databaseValue => switch (this) {
    ReviewDirection.customerToRepairer => 'customer_to_repairer',
    ReviewDirection.repairerToCustomer => 'repairer_to_customer',
  };
}

@immutable
class JobStatusEvent {
  const JobStatusEvent({
    required this.id,
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.changedBy,
    this.reason,
  });

  factory JobStatusEvent.fromJson(Map<String, Object?> json) {
    return JobStatusEvent(
      id: _string(json['id']),
      fromStatus: json['from_status'] == null
          ? null
          : jobStatusFromDatabase(json['from_status']),
      toStatus: jobStatusFromDatabase(json['to_status']),
      changedBy: _nullableString(json['changed_by']),
      reason: _nullableString(json['reason']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final JobStatus? fromStatus;
  final JobStatus toStatus;
  final String? changedBy;
  final String? reason;
  final DateTime createdAt;
}

@immutable
class JobReview {
  const JobReview({
    required this.id,
    required this.jobId,
    required this.authorId,
    required this.reviewedUserId,
    required this.direction,
    required this.overallRating,
    required this.authorName,
    required this.createdAt,
    this.qualityRating,
    this.communicationRating,
    this.punctualityRating,
    this.valueRating,
    this.quoteAccuracyRating,
    this.descriptionAccuracyRating,
    this.attendanceRating,
    this.locationAccessibilityRating,
    this.comment,
    this.repairerResponse,
    this.respondedAt,
  });

  factory JobReview.fromJson(Map<String, Object?> json) {
    return JobReview(
      id: _string(json['id']),
      jobId: _string(json['job_id']),
      authorId: _string(json['author_id']),
      reviewedUserId: _string(json['reviewed_user_id']),
      direction: _string(json['direction']) == 'repairer_to_customer'
          ? ReviewDirection.repairerToCustomer
          : ReviewDirection.customerToRepairer,
      overallRating: _int(json['overall_rating']),
      qualityRating: _nullableInt(json['quality_rating']),
      communicationRating: _nullableInt(json['communication_rating']),
      punctualityRating: _nullableInt(json['punctuality_rating']),
      valueRating: _nullableInt(json['value_rating']),
      quoteAccuracyRating: _nullableInt(json['quote_accuracy_rating']),
      descriptionAccuracyRating: _nullableInt(
        json['description_accuracy_rating'],
      ),
      attendanceRating: _nullableInt(json['attendance_rating']),
      locationAccessibilityRating: _nullableInt(
        json['location_accessibility_rating'],
      ),
      comment: _nullableString(json['comment']),
      repairerResponse: _nullableString(json['repairer_response']),
      respondedAt: _date(json['responded_at']),
      authorName: _string(json['author_name'], fallback: 'FixBrief member'),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String jobId;
  final String authorId;
  final String reviewedUserId;
  final ReviewDirection direction;
  final int overallRating;
  final int? qualityRating;
  final int? communicationRating;
  final int? punctualityRating;
  final int? valueRating;
  final int? quoteAccuracyRating;
  final int? descriptionAccuracyRating;
  final int? attendanceRating;
  final int? locationAccessibilityRating;
  final String? comment;
  final String? repairerResponse;
  final DateTime? respondedAt;
  final String authorName;
  final DateTime createdAt;
}

@immutable
class JobReviewInput {
  const JobReviewInput({
    required this.overallRating,
    required this.communicationRating,
    required this.comment,
    this.qualityRating,
    this.punctualityRating,
    this.valueRating,
    this.quoteAccuracyRating,
    this.descriptionAccuracyRating,
    this.attendanceRating,
    this.locationAccessibilityRating,
  });

  final int overallRating;
  final int communicationRating;
  final int? qualityRating;
  final int? punctualityRating;
  final int? valueRating;
  final int? quoteAccuracyRating;
  final int? descriptionAccuracyRating;
  final int? attendanceRating;
  final int? locationAccessibilityRating;
  final String comment;

  Map<String, Object?> toJson() => <String, Object?>{
    'overall_rating': overallRating,
    'quality_rating': qualityRating,
    'communication_rating': communicationRating,
    'punctuality_rating': punctualityRating,
    'value_rating': valueRating,
    'quote_accuracy_rating': quoteAccuracyRating,
    'description_accuracy_rating': descriptionAccuracyRating,
    'attendance_rating': attendanceRating,
    'location_accessibility_rating': locationAccessibilityRating,
    'comment': comment.trim(),
  };
}

@immutable
class RepairJob {
  const RepairJob({
    required this.id,
    required this.requestId,
    required this.acceptedQuoteId,
    required this.customerId,
    required this.repairerId,
    required this.itemName,
    required this.counterpartName,
    required this.status,
    required this.agreedMinimumMinor,
    required this.agreedMaximumMinor,
    required this.currencyCode,
    required this.acceptedAt,
    required this.updatedAt,
    required this.history,
    required this.reviews,
    required this.hasMyReview,
    this.businessName,
    this.approximateArea,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.disputedAt,
    this.disputeReason,
  });

  factory RepairJob.fromJson(Map<String, Object?> json) {
    return RepairJob(
      id: _string(json['id']),
      requestId: _string(json['request_id']),
      acceptedQuoteId: _string(json['accepted_quote_id']),
      customerId: _string(json['customer_id']),
      repairerId: _string(json['repairer_id']),
      itemName: _string(json['item_name'], fallback: 'Repair job'),
      counterpartName: _string(
        json['counterpart_name'],
        fallback: 'FixBrief member',
      ),
      businessName: _nullableString(json['business_name']),
      approximateArea: _nullableString(json['approximate_area']),
      status: jobStatusFromDatabase(json['status']),
      agreedMinimumMinor: _int(json['agreed_minimum_minor']),
      agreedMaximumMinor: _int(json['agreed_maximum_minor']),
      currencyCode: _string(json['currency_code'], fallback: 'GBP'),
      acceptedAt: _date(json['accepted_at']) ?? DateTime.now(),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      cancellationReason: _nullableString(json['cancellation_reason']),
      disputedAt: _date(json['disputed_at']),
      disputeReason: _nullableString(json['dispute_reason']),
      updatedAt: _date(json['updated_at']) ?? DateTime.now(),
      history: _maps(
        json['history'],
      ).map(JobStatusEvent.fromJson).toList(growable: false),
      reviews: _maps(
        json['reviews'],
      ).map(JobReview.fromJson).toList(growable: false),
      hasMyReview: _bool(json['has_my_review']),
    );
  }

  final String id;
  final String requestId;
  final String acceptedQuoteId;
  final String customerId;
  final String repairerId;
  final String itemName;
  final String counterpartName;
  final String? businessName;
  final String? approximateArea;
  final JobStatus status;
  final int agreedMinimumMinor;
  final int agreedMaximumMinor;
  final String currencyCode;
  final DateTime acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? disputedAt;
  final String? disputeReason;
  final DateTime updatedAt;
  final List<JobStatusEvent> history;
  final List<JobReview> reviews;
  final bool hasMyReview;

  bool get canReview => status == JobStatus.completed && !hasMyReview;

  RepairJob copyWith({
    JobStatus? status,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? disputedAt,
    String? disputeReason,
    DateTime? updatedAt,
    List<JobStatusEvent>? history,
    List<JobReview>? reviews,
    bool? hasMyReview,
  }) {
    return RepairJob(
      id: id,
      requestId: requestId,
      acceptedQuoteId: acceptedQuoteId,
      customerId: customerId,
      repairerId: repairerId,
      itemName: itemName,
      counterpartName: counterpartName,
      businessName: businessName,
      approximateArea: approximateArea,
      status: status ?? this.status,
      agreedMinimumMinor: agreedMinimumMinor,
      agreedMaximumMinor: agreedMaximumMinor,
      currencyCode: currencyCode,
      acceptedAt: acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      disputedAt: disputedAt ?? this.disputedAt,
      disputeReason: disputeReason ?? this.disputeReason,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
      reviews: reviews ?? this.reviews,
      hasMyReview: hasMyReview ?? this.hasMyReview,
    );
  }
}

class JobFailure implements Exception {
  const JobFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value
      .map((item) {
        if (item is Map<String, Object?>) {
          return item;
        }
        if (item is Map) {
          return item.map((key, value) => MapEntry(key.toString(), value));
        }
        return <String, Object?>{};
      })
      .toList(growable: false);
}

String _string(Object? value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}

String? _nullableString(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

int _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

int? _nullableInt(Object? value) => value == null ? null : _int(value);

bool _bool(Object? value) => switch (value) {
  final bool boolean => boolean,
  final num number => number != 0,
  final String text => text.toLowerCase() == 'true',
  _ => false,
};

DateTime? _date(Object? value) {
  final text = value?.toString();
  return text == null ? null : DateTime.tryParse(text)?.toLocal();
}
