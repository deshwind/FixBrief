import 'package:flutter/foundation.dart';

const provisionalEstimateWarning =
    'This is a provisional estimate. The final cost may change after physical inspection.';

enum QuoteStatus { draft, submitted, accepted, rejected, withdrawn, expired }

extension QuoteStatusView on QuoteStatus {
  String get label => switch (this) {
    QuoteStatus.draft => 'Draft',
    QuoteStatus.submitted => 'Submitted',
    QuoteStatus.accepted => 'Accepted',
    QuoteStatus.rejected => 'Not selected',
    QuoteStatus.withdrawn => 'Withdrawn',
    QuoteStatus.expired => 'Expired',
  };

  bool get canEdit =>
      this == QuoteStatus.draft || this == QuoteStatus.submitted;
}

@immutable
class ProvisionalQuote {
  const ProvisionalQuote({
    required this.id,
    required this.requestId,
    required this.repairerId,
    required this.status,
    required this.inspectionFeeMinor,
    required this.calloutFeeMinor,
    required this.labourMinimumMinor,
    required this.labourMaximumMinor,
    required this.partsMinimumMinor,
    required this.partsMaximumMinor,
    required this.otherChargesMinimumMinor,
    required this.otherChargesMaximumMinor,
    required this.totalMinimumMinor,
    required this.totalMaximumMinor,
    required this.currencyCode,
    required this.estimatedDurationMinutes,
    required this.collectionAvailable,
    required this.mobileRepairAvailable,
    required this.warrantyDays,
    required this.assumptions,
    required this.exclusions,
    required this.businessName,
    required this.fullName,
    required this.averageRating,
    required this.reviewCount,
    required this.completedJobCount,
    required this.responseRate,
    required this.qualifications,
    required this.isVerified,
    required this.recommendationReasons,
    this.itemName,
    this.categoryName,
    this.approximateArea,
    this.earliestAvailability,
    this.expiresAt,
    this.additionalComments,
    this.submittedAt,
    this.distanceKilometres,
    this.quoteAccuracyRating,
    this.isRecommended = false,
    this.recommendationLabel,
  });

  factory ProvisionalQuote.fromJson(Map<String, Object?> json) {
    return ProvisionalQuote(
      id: _string(json['id']),
      requestId: _string(json['request_id']),
      repairerId: _string(json['repairer_id']),
      itemName: _nullableString(json['item_name']),
      categoryName: _nullableString(json['category_name']),
      approximateArea: _nullableString(json['approximate_area']),
      status: QuoteStatus.values.firstWhere(
        (value) => value.name == _string(json['status']),
        orElse: () => QuoteStatus.draft,
      ),
      inspectionFeeMinor: _int(json['inspection_fee_minor']),
      calloutFeeMinor: _int(json['callout_fee_minor']),
      labourMinimumMinor: _int(json['labour_minimum_minor']),
      labourMaximumMinor: _int(json['labour_maximum_minor']),
      partsMinimumMinor: _int(json['parts_minimum_minor']),
      partsMaximumMinor: _int(json['parts_maximum_minor']),
      otherChargesMinimumMinor: _int(json['other_charges_minimum_minor']),
      otherChargesMaximumMinor: _int(json['other_charges_maximum_minor']),
      totalMinimumMinor: _int(json['total_minimum_minor']),
      totalMaximumMinor: _int(json['total_maximum_minor']),
      currencyCode: _string(json['currency_code'], fallback: 'GBP'),
      earliestAvailability: _date(json['earliest_availability']),
      estimatedDurationMinutes: _int(json['estimated_duration_minutes']),
      collectionAvailable: _bool(json['collection_available']),
      mobileRepairAvailable: _bool(json['mobile_repair_available']),
      warrantyDays: _int(json['warranty_days']),
      expiresAt: _date(json['expires_at']),
      additionalComments: _nullableString(json['additional_comments']),
      assumptions: _strings(json['assumptions']),
      exclusions: _strings(json['exclusions']),
      submittedAt: _date(json['submitted_at']),
      businessName: _string(
        json['business_name'],
        fallback: 'Repair professional',
      ),
      fullName: _string(json['full_name'], fallback: 'Repair professional'),
      averageRating: _double(json['average_rating']),
      reviewCount: _int(json['review_count']),
      completedJobCount: _int(json['completed_job_count']),
      responseRate: _double(json['response_rate']),
      distanceKilometres: _nullableDouble(json['distance_kilometres']),
      quoteAccuracyRating: _nullableDouble(json['quote_accuracy_rating']),
      qualifications: _strings(json['qualifications']),
      isVerified: _string(json['verification_status']) == 'verified',
      isRecommended: _bool(json['is_recommended']),
      recommendationLabel: _nullableString(json['recommendation_label']),
      recommendationReasons: _strings(json['recommendation_reasons']),
    );
  }

  final String id;
  final String requestId;
  final String repairerId;
  final String? itemName;
  final String? categoryName;
  final String? approximateArea;
  final QuoteStatus status;
  final int inspectionFeeMinor;
  final int calloutFeeMinor;
  final int labourMinimumMinor;
  final int labourMaximumMinor;
  final int partsMinimumMinor;
  final int partsMaximumMinor;
  final int otherChargesMinimumMinor;
  final int otherChargesMaximumMinor;
  final int totalMinimumMinor;
  final int totalMaximumMinor;
  final String currencyCode;
  final DateTime? earliestAvailability;
  final int estimatedDurationMinutes;
  final bool collectionAvailable;
  final bool mobileRepairAvailable;
  final int warrantyDays;
  final DateTime? expiresAt;
  final String? additionalComments;
  final List<String> assumptions;
  final List<String> exclusions;
  final DateTime? submittedAt;
  final String businessName;
  final String fullName;
  final double averageRating;
  final int reviewCount;
  final int completedJobCount;
  final double responseRate;
  final double? distanceKilometres;
  final double? quoteAccuracyRating;
  final List<String> qualifications;
  final bool isVerified;
  final bool isRecommended;
  final String? recommendationLabel;
  final List<String> recommendationReasons;

  bool get isExpired =>
      status == QuoteStatus.expired ||
      (expiresAt != null &&
          expiresAt!.isBefore(DateTime.now()) &&
          status == QuoteStatus.submitted);
  bool get canAccept => status == QuoteStatus.submitted && !isExpired;
  bool get canEdit => status.canEdit && !isExpired;
}

@immutable
class QuoteDraftInput {
  const QuoteDraftInput({
    required this.requestId,
    required this.inspectionFeeMinor,
    required this.calloutFeeMinor,
    required this.labourMinimumMinor,
    required this.labourMaximumMinor,
    required this.partsMinimumMinor,
    required this.partsMaximumMinor,
    required this.otherChargesMinimumMinor,
    required this.otherChargesMaximumMinor,
    required this.earliestAvailability,
    required this.estimatedDurationMinutes,
    required this.collectionAvailable,
    required this.mobileRepairAvailable,
    required this.warrantyDays,
    required this.expiresAt,
    required this.additionalComments,
    required this.assumptions,
    required this.exclusions,
    this.quoteId,
  });

  factory QuoteDraftInput.initial(String requestId) {
    final now = DateTime.now();
    return QuoteDraftInput(
      requestId: requestId,
      inspectionFeeMinor: 4500,
      calloutFeeMinor: 0,
      labourMinimumMinor: 9000,
      labourMaximumMinor: 18000,
      partsMinimumMinor: 0,
      partsMaximumMinor: 25000,
      otherChargesMinimumMinor: 0,
      otherChargesMaximumMinor: 0,
      earliestAvailability: now.add(const Duration(days: 1)),
      estimatedDurationMinutes: 120,
      collectionAvailable: false,
      mobileRepairAvailable: true,
      warrantyDays: 90,
      expiresAt: now.add(const Duration(days: 7)),
      additionalComments:
          'Provisional range pending a physical inspection of the reported fault.',
      assumptions: const ['The reported symptoms match the shared evidence'],
      exclusions: const ['Unrelated faults and additional damage are excluded'],
    );
  }

  factory QuoteDraftInput.fromQuote(ProvisionalQuote quote) {
    return QuoteDraftInput(
      requestId: quote.requestId,
      quoteId: quote.id,
      inspectionFeeMinor: quote.inspectionFeeMinor,
      calloutFeeMinor: quote.calloutFeeMinor,
      labourMinimumMinor: quote.labourMinimumMinor,
      labourMaximumMinor: quote.labourMaximumMinor,
      partsMinimumMinor: quote.partsMinimumMinor,
      partsMaximumMinor: quote.partsMaximumMinor,
      otherChargesMinimumMinor: quote.otherChargesMinimumMinor,
      otherChargesMaximumMinor: quote.otherChargesMaximumMinor,
      earliestAvailability:
          quote.earliestAvailability ??
          DateTime.now().add(const Duration(days: 1)),
      estimatedDurationMinutes: quote.estimatedDurationMinutes,
      collectionAvailable: quote.collectionAvailable,
      mobileRepairAvailable: quote.mobileRepairAvailable,
      warrantyDays: quote.warrantyDays,
      expiresAt: quote.expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      additionalComments: quote.additionalComments ?? '',
      assumptions: quote.assumptions,
      exclusions: quote.exclusions,
    );
  }

  final String requestId;
  final String? quoteId;
  final int inspectionFeeMinor;
  final int calloutFeeMinor;
  final int labourMinimumMinor;
  final int labourMaximumMinor;
  final int partsMinimumMinor;
  final int partsMaximumMinor;
  final int otherChargesMinimumMinor;
  final int otherChargesMaximumMinor;
  final DateTime earliestAvailability;
  final int estimatedDurationMinutes;
  final bool collectionAvailable;
  final bool mobileRepairAvailable;
  final int warrantyDays;
  final DateTime expiresAt;
  final String additionalComments;
  final List<String> assumptions;
  final List<String> exclusions;

  int get totalMinimumMinor =>
      inspectionFeeMinor +
      calloutFeeMinor +
      labourMinimumMinor +
      partsMinimumMinor +
      otherChargesMinimumMinor;

  int get totalMaximumMinor =>
      inspectionFeeMinor +
      calloutFeeMinor +
      labourMaximumMinor +
      partsMaximumMinor +
      otherChargesMaximumMinor;

  Map<String, Object?> toJson() => <String, Object?>{
    'inspection_fee_minor': inspectionFeeMinor,
    'callout_fee_minor': calloutFeeMinor,
    'labour_minimum_minor': labourMinimumMinor,
    'labour_maximum_minor': labourMaximumMinor,
    'parts_minimum_minor': partsMinimumMinor,
    'parts_maximum_minor': partsMaximumMinor,
    'other_charges_minimum_minor': otherChargesMinimumMinor,
    'other_charges_maximum_minor': otherChargesMaximumMinor,
    'earliest_availability': earliestAvailability.toUtc().toIso8601String(),
    'estimated_duration_minutes': estimatedDurationMinutes,
    'collection_available': collectionAvailable,
    'mobile_repair_available': mobileRepairAvailable,
    'warranty_days': warrantyDays,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'additional_comments': additionalComments.trim(),
    'assumptions': assumptions,
    'exclusions': exclusions,
  };
}

@immutable
class QuoteComparison {
  const QuoteComparison({
    required this.requestId,
    required this.itemName,
    required this.requestStatus,
    required this.quotes,
    this.acceptedQuoteId,
    this.jobId,
  });

  factory QuoteComparison.fromJson(Map<String, Object?> json) {
    return QuoteComparison(
      requestId: _string(json['request_id']),
      itemName: _string(json['item_name'], fallback: 'Repair request'),
      requestStatus: _string(json['request_status']),
      acceptedQuoteId: _nullableString(json['accepted_quote_id']),
      jobId: _nullableString(json['job_id']),
      quotes: _maps(
        json['quotes'],
      ).map(ProvisionalQuote.fromJson).toList(growable: false),
    );
  }

  final String requestId;
  final String itemName;
  final String requestStatus;
  final String? acceptedQuoteId;
  final String? jobId;
  final List<ProvisionalQuote> quotes;

  List<ProvisionalQuote> get availableQuotes =>
      quotes.where((quote) => quote.canAccept).toList(growable: false);
  bool get hasAcceptedQuote => acceptedQuoteId != null;
}

class QuoteFailure implements Exception {
  const QuoteFailure(this.message, {this.code});

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

List<String> _strings(Object? value) => value is Iterable
    ? value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false)
    : const [];

String _string(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

double _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

double? _nullableDouble(Object? value) => value == null
    ? null
    : switch (value) {
        final num number => number.toDouble(),
        final String text => double.tryParse(text),
        _ => null,
      };

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
