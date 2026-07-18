import 'dart:async';

import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/domain/repositories/quote_repository.dart';

class DemoQuoteRepository implements QuoteRepository {
  DemoQuoteRepository({this.simulatedDelay = Duration.zero});

  final Duration simulatedDelay;
  final Map<String, ProvisionalQuote> _myQuotes = {};
  late final Map<String, ProvisionalQuote> _customerQuotes = {
    for (final quote in _seedCustomerQuotes()) quote.id: quote,
  };
  String? _acceptedQuoteId;
  String? _jobId;

  @override
  Future<ProvisionalQuote?> loadMyQuote(String requestId) async {
    await _wait();
    return _myQuotes.values
        .where((quote) => quote.requestId == requestId)
        .firstOrNull;
  }

  @override
  Future<List<ProvisionalQuote>> loadMyQuotes() async {
    await _wait();
    return _myQuotes.values.toList(growable: false).reversed.toList();
  }

  @override
  Future<ProvisionalQuote> saveDraft(QuoteDraftInput input) async {
    await _wait();
    _validateInput(input);
    final existing = input.quoteId == null ? null : _myQuotes[input.quoteId];
    if (input.quoteId != null && existing == null) {
      throw const QuoteFailure('This quote is no longer available.');
    }
    if (existing != null && !existing.canEdit) {
      throw const QuoteFailure('This quote can no longer be edited.');
    }
    final quote = _fromInput(
      input,
      id: existing?.id ?? 'demo-quote-${input.requestId}',
      status: existing?.status ?? QuoteStatus.draft,
      submittedAt: existing?.submittedAt,
    );
    _myQuotes[quote.id] = quote;
    return quote;
  }

  @override
  Future<ProvisionalQuote> submitQuote(String quoteId) async {
    await _wait();
    final quote = _myQuotes[quoteId];
    if (quote == null || quote.status != QuoteStatus.draft) {
      throw const QuoteFailure('Only a saved draft can be submitted.');
    }
    if (quote.totalMaximumMinor <= 0 ||
        quote.expiresAt == null ||
        quote.expiresAt!.isBefore(DateTime.now())) {
      throw const QuoteFailure(
        'Add a price range and future expiry before submitting.',
      );
    }
    final submitted = _withStatus(
      quote,
      QuoteStatus.submitted,
      submittedAt: DateTime.now(),
    );
    _myQuotes[quoteId] = submitted;
    return submitted;
  }

  @override
  Future<ProvisionalQuote> withdrawQuote(String quoteId) async {
    await _wait();
    final quote = _myQuotes[quoteId];
    if (quote == null || !quote.status.canEdit) {
      throw const QuoteFailure('This quote can no longer be withdrawn.');
    }
    final withdrawn = _withStatus(quote, QuoteStatus.withdrawn);
    _myQuotes[quoteId] = withdrawn;
    return withdrawn;
  }

  @override
  Future<QuoteComparison> loadComparison(String requestId) async {
    await _wait();
    final quotes = <ProvisionalQuote>[
      ..._customerQuotes.values.where((quote) => quote.requestId == requestId),
      ..._myQuotes.values.where(
        (quote) =>
            quote.requestId == requestId &&
            quote.status != QuoteStatus.draft &&
            quote.status != QuoteStatus.withdrawn,
      ),
    ];
    return QuoteComparison(
      requestId: requestId,
      itemName: 'Ford Focus front-left clicking',
      requestStatus: _acceptedQuoteId == null
          ? 'quotes_received'
          : 'quote_accepted',
      quotes: quotes,
      acceptedQuoteId: _acceptedQuoteId,
      jobId: _jobId,
    );
  }

  @override
  Future<String> acceptQuote(
    String quoteId, {
    required String idempotencyKey,
  }) async {
    await _wait();
    if (_jobId != null) {
      return _jobId!;
    }
    if (idempotencyKey.length < 8) {
      throw const QuoteFailure('Please try accepting the quote again.');
    }
    final selected = _customerQuotes[quoteId] ?? _myQuotes[quoteId];
    if (selected == null || !selected.canAccept) {
      throw const QuoteFailure('This quote is no longer available.');
    }
    for (final entry in _customerQuotes.entries.toList()) {
      if (entry.value.requestId == selected.requestId &&
          entry.value.status == QuoteStatus.submitted) {
        _customerQuotes[entry.key] = _withStatus(
          entry.value,
          entry.key == quoteId ? QuoteStatus.accepted : QuoteStatus.rejected,
        );
      }
    }
    for (final entry in _myQuotes.entries.toList()) {
      if (entry.value.requestId == selected.requestId &&
          entry.value.status == QuoteStatus.submitted) {
        _myQuotes[entry.key] = _withStatus(
          entry.value,
          entry.key == quoteId ? QuoteStatus.accepted : QuoteStatus.rejected,
        );
      }
    }
    _acceptedQuoteId = quoteId;
    _jobId = 'demo-job-${selected.requestId}';
    return _jobId!;
  }

  Future<void> _wait() => Future<void>.delayed(simulatedDelay);
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

void _validateInput(QuoteDraftInput input) {
  final amounts = [
    input.inspectionFeeMinor,
    input.calloutFeeMinor,
    input.labourMinimumMinor,
    input.labourMaximumMinor,
    input.partsMinimumMinor,
    input.partsMaximumMinor,
    input.otherChargesMinimumMinor,
    input.otherChargesMaximumMinor,
  ];
  if (amounts.any((amount) => amount < 0)) {
    throw const QuoteFailure('Quote amounts cannot be negative.');
  }
  if (input.labourMinimumMinor > input.labourMaximumMinor ||
      input.partsMinimumMinor > input.partsMaximumMinor ||
      input.otherChargesMinimumMinor > input.otherChargesMaximumMinor) {
    throw const QuoteFailure(
      'Each minimum amount must be no greater than its maximum.',
    );
  }
  if (input.expiresAt.isBefore(DateTime.now())) {
    throw const QuoteFailure('Choose a future quote expiry date.');
  }
}

ProvisionalQuote _fromInput(
  QuoteDraftInput input, {
  required String id,
  required QuoteStatus status,
  DateTime? submittedAt,
}) {
  return ProvisionalQuote(
    id: id,
    requestId: input.requestId,
    repairerId: 'demo-repairer-northline',
    itemName: 'Ford Focus',
    categoryName: 'Vehicles',
    approximateArea: 'Chorlton area',
    status: status,
    inspectionFeeMinor: input.inspectionFeeMinor,
    calloutFeeMinor: input.calloutFeeMinor,
    labourMinimumMinor: input.labourMinimumMinor,
    labourMaximumMinor: input.labourMaximumMinor,
    partsMinimumMinor: input.partsMinimumMinor,
    partsMaximumMinor: input.partsMaximumMinor,
    otherChargesMinimumMinor: input.otherChargesMinimumMinor,
    otherChargesMaximumMinor: input.otherChargesMaximumMinor,
    totalMinimumMinor: input.totalMinimumMinor,
    totalMaximumMinor: input.totalMaximumMinor,
    currencyCode: 'GBP',
    earliestAvailability: input.earliestAvailability,
    estimatedDurationMinutes: input.estimatedDurationMinutes,
    collectionAvailable: input.collectionAvailable,
    mobileRepairAvailable: input.mobileRepairAvailable,
    warrantyDays: input.warrantyDays,
    expiresAt: input.expiresAt,
    additionalComments: input.additionalComments,
    assumptions: input.assumptions,
    exclusions: input.exclusions,
    submittedAt: submittedAt,
    businessName: 'Northline Repairs',
    fullName: 'Sam North',
    averageRating: 4.8,
    reviewCount: 126,
    completedJobCount: 214,
    responseRate: 94,
    distanceKilometres: 2.4,
    quoteAccuracyRating: 4.7,
    qualifications: const ['IMI Level 3 Light Vehicle Maintenance'],
    isVerified: true,
    recommendationReasons: const [],
  );
}

List<ProvisionalQuote> _seedCustomerQuotes() {
  final now = DateTime.now();
  Map<String, Object?> quote({
    required String id,
    required String repairerId,
    required String business,
    required int inspection,
    required int callout,
    required int labourMin,
    required int labourMax,
    required int partsMin,
    required int partsMax,
    required double rating,
    required int reviews,
    required int jobs,
    required double distance,
    required int availabilityHours,
    required int warranty,
    required double response,
    required List<String> qualifications,
    bool recommended = false,
    List<String> reasons = const [],
  }) => <String, Object?>{
    'id': id,
    'request_id': 'demo-request-vehicle',
    'repairer_id': repairerId,
    'status': 'submitted',
    'inspection_fee_minor': inspection,
    'callout_fee_minor': callout,
    'labour_minimum_minor': labourMin,
    'labour_maximum_minor': labourMax,
    'parts_minimum_minor': partsMin,
    'parts_maximum_minor': partsMax,
    'other_charges_minimum_minor': 0,
    'other_charges_maximum_minor': 0,
    'total_minimum_minor': inspection + callout + labourMin + partsMin,
    'total_maximum_minor': inspection + callout + labourMax + partsMax,
    'currency_code': 'GBP',
    'earliest_availability': now
        .add(Duration(hours: availabilityHours))
        .toIso8601String(),
    'estimated_duration_minutes': 150,
    'collection_available': true,
    'mobile_repair_available': true,
    'warranty_days': warranty,
    'expires_at': now.add(const Duration(days: 6)).toIso8601String(),
    'additional_comments':
        'Provisional estimate subject to a physical steering and suspension inspection.',
    'assumptions': ['The noise is limited to the reported front-left area'],
    'exclusions': ['Alignment and unrelated wear are excluded'],
    'submitted_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
    'business_name': business,
    'full_name': business,
    'average_rating': rating,
    'review_count': reviews,
    'completed_job_count': jobs,
    'response_rate': response,
    'distance_kilometres': distance,
    'quote_accuracy_rating': recommended ? 4.8 : 4.2,
    'qualifications': qualifications,
    'verification_status': 'verified',
    'is_recommended': recommended,
    'recommendation_label': recommended ? 'Strong overall fit' : null,
    'recommendation_reasons': reasons,
  };

  return [
    ProvisionalQuote.fromJson(
      quote(
        id: 'demo-customer-quote-quickfix',
        repairerId: 'demo-repairer-quickfix',
        business: 'QuickFix Automotive',
        inspection: 2500,
        callout: 0,
        labourMin: 7000,
        labourMax: 13000,
        partsMin: 4500,
        partsMax: 10500,
        rating: 4.2,
        reviews: 38,
        jobs: 63,
        distance: 1.8,
        availabilityHours: 72,
        warranty: 30,
        response: 82,
        qualifications: const ['Vehicle maintenance certificate'],
      ),
    ),
    ProvisionalQuote.fromJson(
      quote(
        id: 'demo-customer-quote-mancunian',
        repairerId: 'demo-repairer-mancunian',
        business: 'Mancunian Motor Care',
        inspection: 3500,
        callout: 2500,
        labourMin: 8500,
        labourMax: 15500,
        partsMin: 4000,
        partsMax: 12500,
        rating: 4.9,
        reviews: 287,
        jobs: 412,
        distance: 3.1,
        availabilityHours: 18,
        warranty: 180,
        response: 97,
        qualifications: const [
          'IMI Level 3 Light Vehicle Maintenance',
          'Hybrid and EV awareness',
        ],
        recommended: true,
        reasons: const [
          'Strong customer rating',
          'Fast availability',
          'Relevant qualifications listed',
          'Meaningful warranty included',
          'Strong quote accuracy history',
        ],
      ),
    ),
    ProvisionalQuote.fromJson(
      quote(
        id: 'demo-customer-quote-apex',
        repairerId: 'demo-repairer-apex',
        business: 'Apex Vehicle Diagnostics',
        inspection: 4500,
        callout: 0,
        labourMin: 8000,
        labourMax: 15000,
        partsMin: 4000,
        partsMax: 12000,
        rating: 4.7,
        reviews: 142,
        jobs: 198,
        distance: 4.7,
        availabilityHours: 30,
        warranty: 90,
        response: 92,
        qualifications: const ['Advanced vehicle diagnostics'],
      ),
    ),
  ];
}

ProvisionalQuote _withStatus(
  ProvisionalQuote quote,
  QuoteStatus status, {
  DateTime? submittedAt,
}) {
  return ProvisionalQuote(
    id: quote.id,
    requestId: quote.requestId,
    repairerId: quote.repairerId,
    itemName: quote.itemName,
    categoryName: quote.categoryName,
    approximateArea: quote.approximateArea,
    status: status,
    inspectionFeeMinor: quote.inspectionFeeMinor,
    calloutFeeMinor: quote.calloutFeeMinor,
    labourMinimumMinor: quote.labourMinimumMinor,
    labourMaximumMinor: quote.labourMaximumMinor,
    partsMinimumMinor: quote.partsMinimumMinor,
    partsMaximumMinor: quote.partsMaximumMinor,
    otherChargesMinimumMinor: quote.otherChargesMinimumMinor,
    otherChargesMaximumMinor: quote.otherChargesMaximumMinor,
    totalMinimumMinor: quote.totalMinimumMinor,
    totalMaximumMinor: quote.totalMaximumMinor,
    currencyCode: quote.currencyCode,
    earliestAvailability: quote.earliestAvailability,
    estimatedDurationMinutes: quote.estimatedDurationMinutes,
    collectionAvailable: quote.collectionAvailable,
    mobileRepairAvailable: quote.mobileRepairAvailable,
    warrantyDays: quote.warrantyDays,
    expiresAt: quote.expiresAt,
    additionalComments: quote.additionalComments,
    assumptions: quote.assumptions,
    exclusions: quote.exclusions,
    submittedAt: submittedAt ?? quote.submittedAt,
    businessName: quote.businessName,
    fullName: quote.fullName,
    averageRating: quote.averageRating,
    reviewCount: quote.reviewCount,
    completedJobCount: quote.completedJobCount,
    responseRate: quote.responseRate,
    distanceKilometres: quote.distanceKilometres,
    quoteAccuracyRating: quote.quoteAccuracyRating,
    qualifications: quote.qualifications,
    isVerified: quote.isVerified,
    isRecommended: quote.isRecommended,
    recommendationLabel: quote.recommendationLabel,
    recommendationReasons: quote.recommendationReasons,
  );
}
