import 'package:flutter/foundation.dart';

enum MarketplaceUrgency {
  emergency,
  asap,
  within24Hours,
  within3Days,
  within1Week,
  flexible;

  factory MarketplaceUrgency.fromDatabase(String? value) => switch (value) {
    'emergency' => MarketplaceUrgency.emergency,
    'asap' => MarketplaceUrgency.asap,
    'within_24_hours' => MarketplaceUrgency.within24Hours,
    'within_3_days' => MarketplaceUrgency.within3Days,
    'within_1_week' => MarketplaceUrgency.within1Week,
    _ => MarketplaceUrgency.flexible,
  };

  String get databaseValue => switch (this) {
    MarketplaceUrgency.emergency => 'emergency',
    MarketplaceUrgency.asap => 'asap',
    MarketplaceUrgency.within24Hours => 'within_24_hours',
    MarketplaceUrgency.within3Days => 'within_3_days',
    MarketplaceUrgency.within1Week => 'within_1_week',
    MarketplaceUrgency.flexible => 'flexible',
  };

  String get label => switch (this) {
    MarketplaceUrgency.emergency => 'Emergency',
    MarketplaceUrgency.asap => 'As soon as possible',
    MarketplaceUrgency.within24Hours => 'Within 24 hours',
    MarketplaceUrgency.within3Days => 'Within 3 days',
    MarketplaceUrgency.within1Week => 'Within 1 week',
    MarketplaceUrgency.flexible => 'Flexible',
  };

  bool get isHighPriority => switch (this) {
    MarketplaceUrgency.emergency ||
    MarketplaceUrgency.asap ||
    MarketplaceUrgency.within24Hours => true,
    _ => false,
  };
}

enum MarketplaceSort {
  bestMatch('best_match', 'Best match'),
  nearest('nearest', 'Nearest'),
  newest('newest', 'Newest'),
  urgent('urgent', 'Most urgent');

  const MarketplaceSort(this.databaseValue, this.label);

  final String databaseValue;
  final String label;
}

@immutable
class MarketplaceFilters {
  const MarketplaceFilters({
    this.search = '',
    this.categoryId,
    this.urgency,
    this.maximumDistanceKilometres,
    this.mobileOnly = false,
    this.collectionOnly = false,
    this.sort = MarketplaceSort.bestMatch,
  });

  final String search;
  final String? categoryId;
  final MarketplaceUrgency? urgency;
  final double? maximumDistanceKilometres;
  final bool mobileOnly;
  final bool collectionOnly;
  final MarketplaceSort sort;

  bool get isFiltered =>
      search.trim().isNotEmpty ||
      categoryId != null ||
      urgency != null ||
      maximumDistanceKilometres != null ||
      mobileOnly ||
      collectionOnly ||
      sort != MarketplaceSort.bestMatch;

  MarketplaceFilters copyWith({
    String? search,
    String? categoryId,
    bool clearCategory = false,
    MarketplaceUrgency? urgency,
    bool clearUrgency = false,
    double? maximumDistanceKilometres,
    bool clearMaximumDistance = false,
    bool? mobileOnly,
    bool? collectionOnly,
    MarketplaceSort? sort,
  }) {
    return MarketplaceFilters(
      search: search ?? this.search,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      urgency: clearUrgency ? null : urgency ?? this.urgency,
      maximumDistanceKilometres: clearMaximumDistance
          ? null
          : maximumDistanceKilometres ?? this.maximumDistanceKilometres,
      mobileOnly: mobileOnly ?? this.mobileOnly,
      collectionOnly: collectionOnly ?? this.collectionOnly,
      sort: sort ?? this.sort,
    );
  }
}

@immutable
class MarketplaceRequest {
  const MarketplaceRequest({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.itemName,
    required this.summary,
    required this.approximateArea,
    required this.urgency,
    required this.publishedAt,
    required this.matchScore,
    required this.matchReasons,
    this.subcategoryId,
    this.subcategoryName,
    this.distanceKilometres,
    this.mobileRepairRequired = false,
    this.collectionRequired = false,
    this.inspectionRequired = false,
    this.evidenceCount = 0,
    this.safetyRisk = 'none',
    this.stopUsingItem = false,
    this.totalCount = 0,
  });

  factory MarketplaceRequest.fromJson(Map<String, Object?> json) {
    return MarketplaceRequest(
      id: _string(json['id']),
      categoryId: _string(json['category_id']),
      categoryName: _string(json['category_name'], fallback: 'General repair'),
      subcategoryId: _nullableString(json['subcategory_id']),
      subcategoryName: _nullableString(json['subcategory_name']),
      itemName: _string(json['item_name'], fallback: 'Repair request'),
      summary: _string(
        json['problem_summary'] ?? json['summary'],
        fallback: 'Open the request to review the customer brief.',
      ),
      approximateArea: _string(
        json['approximate_area'],
        fallback: 'Approximate area withheld',
      ),
      distanceKilometres: _nullableDouble(json['distance_kilometres']),
      urgency: MarketplaceUrgency.fromDatabase(
        _nullableString(json['urgency']),
      ),
      publishedAt:
          DateTime.tryParse(_string(json['published_at']))?.toLocal() ??
          DateTime.now(),
      matchScore: _double(json['match_score']),
      matchReasons: _stringList(json['match_reasons']),
      mobileRepairRequired: _bool(json['mobile_repair_required']),
      collectionRequired: _bool(json['collection_required']),
      inspectionRequired: _bool(json['inspection_required']),
      evidenceCount: _int(json['evidence_count']),
      safetyRisk: _string(json['safety_risk'], fallback: 'none'),
      stopUsingItem: _bool(json['stop_using_item']),
      totalCount: _int(json['total_count']),
    );
  }

  final String id;
  final String categoryId;
  final String categoryName;
  final String? subcategoryId;
  final String? subcategoryName;
  final String itemName;
  final String summary;
  final String approximateArea;
  final double? distanceKilometres;
  final MarketplaceUrgency urgency;
  final DateTime publishedAt;
  final double matchScore;
  final List<String> matchReasons;
  final bool mobileRepairRequired;
  final bool collectionRequired;
  final bool inspectionRequired;
  final int evidenceCount;
  final String safetyRisk;
  final bool stopUsingItem;
  final int totalCount;

  bool get isNearby => distanceKilometres != null && distanceKilometres! <= 8;

  String get categoryLine {
    final subcategory = subcategoryName;
    return subcategory == null || subcategory.isEmpty
        ? categoryName
        : '$categoryName · $subcategory';
  }
}

@immutable
class MarketplaceEvidence {
  const MarketplaceEvidence({
    required this.id,
    required this.kind,
    required this.mimeType,
    required this.label,
    this.signedUrl,
    this.durationMilliseconds,
  });

  factory MarketplaceEvidence.fromJson(Map<String, Object?> json) {
    final kind = _string(json['kind'], fallback: 'document');
    return MarketplaceEvidence(
      id: _string(json['id']),
      kind: kind,
      mimeType: _string(json['mime_type']),
      label: _string(json['label'], fallback: _evidenceLabel(kind)),
      signedUrl: _nullableString(json['signed_url']),
      durationMilliseconds: _nullableInt(json['duration_milliseconds']),
    );
  }

  final String id;
  final String kind;
  final String mimeType;
  final String label;
  final String? signedUrl;
  final int? durationMilliseconds;
}

@immutable
class MarketplaceAssessment {
  const MarketplaceAssessment({
    required this.summary,
    required this.disclaimer,
    required this.confidence,
    required this.safetyRisk,
    required this.stopUsingItem,
    required this.possibleCauses,
    this.safetyWarning,
    this.recommendedProfessional,
    this.inspectionRecommendation,
  });

  factory MarketplaceAssessment.fromJson(Map<String, Object?> json) {
    return MarketplaceAssessment(
      summary: _string(json['problem_summary']),
      disclaimer: _string(
        json['disclaimer'],
        fallback: 'AI-assisted assessment — not a confirmed diagnosis.',
      ),
      confidence: _string(json['confidence'], fallback: 'low'),
      safetyRisk: _string(json['safety_risk'], fallback: 'none'),
      stopUsingItem: _bool(json['stop_using_item']),
      safetyWarning: _nullableString(json['safety_warning']),
      recommendedProfessional: _nullableString(
        json['recommended_professional_type'],
      ),
      inspectionRecommendation: _nullableString(
        json['inspection_recommendation'],
      ),
      possibleCauses: _mapList(
        json['possible_causes'],
      ).map(MarketplacePossibleCause.fromJson).toList(growable: false),
    );
  }

  final String summary;
  final String disclaimer;
  final String confidence;
  final String safetyRisk;
  final bool stopUsingItem;
  final String? safetyWarning;
  final String? recommendedProfessional;
  final String? inspectionRecommendation;
  final List<MarketplacePossibleCause> possibleCauses;
}

@immutable
class MarketplacePossibleCause {
  const MarketplacePossibleCause({
    required this.cause,
    required this.confidence,
    required this.reason,
  });

  factory MarketplacePossibleCause.fromJson(Map<String, Object?> json) {
    return MarketplacePossibleCause(
      cause: _string(json['cause']),
      confidence: _double(json['confidence']),
      reason: _string(json['reasoning_summary'] ?? json['reason']),
    );
  }

  final String cause;
  final double confidence;
  final String reason;
}

@immutable
class MarketplaceRequestDetail {
  const MarketplaceRequestDetail({
    required this.request,
    required this.problemDescription,
    required this.repairBrief,
    required this.symptoms,
    required this.evidence,
    required this.privacyNotice,
    this.brand,
    this.model,
    this.previousRepairs,
    this.preferredDate,
    this.assessment,
  });

  factory MarketplaceRequestDetail.fromJson(Map<String, Object?> json) {
    final requestJson = _map(json['request']);
    final request = MarketplaceRequest.fromJson(requestJson);
    return MarketplaceRequestDetail(
      request: request,
      brand: _nullableString(requestJson['brand']),
      model: _nullableString(requestJson['model']),
      previousRepairs: _nullableString(requestJson['previous_repairs']),
      problemDescription: _string(requestJson['problem_description']),
      repairBrief: _string(requestJson['structured_brief']),
      preferredDate: DateTime.tryParse(
        _string(requestJson['preferred_repair_date']),
      ),
      symptoms: _stringList(json['symptoms']),
      evidence: _mapList(
        json['evidence'],
      ).map(MarketplaceEvidence.fromJson).toList(growable: false),
      assessment: json['assessment'] == null
          ? null
          : MarketplaceAssessment.fromJson(_map(json['assessment'])),
      privacyNotice: _string(
        json['privacy_notice'],
        fallback:
            'Only the customer’s approximate area is visible. Their exact address and identity remain private.',
      ),
    );
  }

  final MarketplaceRequest request;
  final String? brand;
  final String? model;
  final String? previousRepairs;
  final String problemDescription;
  final String repairBrief;
  final DateTime? preferredDate;
  final List<String> symptoms;
  final List<MarketplaceEvidence> evidence;
  final MarketplaceAssessment? assessment;
  final String privacyNotice;
}

@immutable
class RepairerSpecialisation {
  const RepairerSpecialisation({
    required this.category,
    required this.label,
    this.subcategory,
    this.yearsExperience,
  });

  factory RepairerSpecialisation.fromJson(Map<String, Object?> json) {
    return RepairerSpecialisation(
      category: _string(json['category'], fallback: 'General repair'),
      subcategory: _nullableString(json['subcategory']),
      label: _string(json['specialisation'], fallback: 'General repair'),
      yearsExperience: _nullableInt(json['years_experience']),
    );
  }

  final String category;
  final String? subcategory;
  final String label;
  final int? yearsExperience;
}

@immutable
class RepairerServiceArea {
  const RepairerServiceArea({
    required this.name,
    required this.radiusKilometres,
    required this.emergencyService,
    required this.mobileRepair,
    required this.collectionService,
  });

  factory RepairerServiceArea.fromJson(Map<String, Object?> json) {
    return RepairerServiceArea(
      name: _string(json['area_name'], fallback: 'Service area'),
      radiusKilometres: _double(json['radius_kilometres']),
      emergencyService: _bool(json['emergency_service']),
      mobileRepair: _bool(json['mobile_repair']),
      collectionService: _bool(json['collection_service']),
    );
  }

  final String name;
  final double radiusKilometres;
  final bool emergencyService;
  final bool mobileRepair;
  final bool collectionService;
}

@immutable
class RepairerMarketplaceProfile {
  const RepairerMarketplaceProfile({
    required this.userId,
    required this.fullName,
    required this.businessName,
    required this.description,
    required this.yearsExperience,
    required this.qualifications,
    required this.inspectionFeeMinor,
    required this.currencyCode,
    required this.serviceRadiusKilometres,
    required this.workingHours,
    required this.emergencyServiceAvailable,
    required this.mobileRepairAvailable,
    required this.collectionServiceAvailable,
    required this.verificationStatus,
    required this.averageRating,
    required this.reviewCount,
    required this.completedJobCount,
    required this.responseRate,
    required this.quoteAcceptanceRate,
    required this.specialisations,
    required this.certifications,
    required this.serviceAreas,
    required this.availability,
    this.logoUrl,
  });

  factory RepairerMarketplaceProfile.fromJson(Map<String, Object?> json) {
    return RepairerMarketplaceProfile(
      userId: _string(json['user_id']),
      fullName: _string(json['full_name'], fallback: 'Repair professional'),
      businessName: _string(json['business_name'], fallback: 'Repair business'),
      description: _string(json['business_description']),
      logoUrl: _nullableString(json['logo_url']),
      yearsExperience: _int(json['years_experience']),
      qualifications: _stringList(json['qualifications']),
      inspectionFeeMinor: _int(json['inspection_fee_minor']),
      currencyCode: _string(json['currency_code'], fallback: 'GBP'),
      serviceRadiusKilometres: _double(json['service_radius_kilometres']),
      workingHours: _string(
        json['working_hours'],
        fallback: 'Contact the repairer for availability',
      ),
      emergencyServiceAvailable: _bool(json['emergency_service_available']),
      mobileRepairAvailable: _bool(json['mobile_repair_available']),
      collectionServiceAvailable: _bool(json['collection_service_available']),
      verificationStatus: _string(
        json['verification_status'],
        fallback: 'unverified',
      ),
      averageRating: _double(json['average_rating']),
      reviewCount: _int(json['review_count']),
      completedJobCount: _int(json['completed_job_count']),
      responseRate: _double(json['response_rate']),
      quoteAcceptanceRate: _double(json['quote_acceptance_rate']),
      specialisations: _mapList(
        json['specialisations'],
      ).map(RepairerSpecialisation.fromJson).toList(growable: false),
      certifications: _stringList(json['certifications']),
      serviceAreas: _mapList(
        json['service_areas'],
      ).map(RepairerServiceArea.fromJson).toList(growable: false),
      availability: _stringList(json['availability']),
    );
  }

  final String userId;
  final String fullName;
  final String businessName;
  final String description;
  final String? logoUrl;
  final int yearsExperience;
  final List<String> qualifications;
  final int inspectionFeeMinor;
  final String currencyCode;
  final double serviceRadiusKilometres;
  final String workingHours;
  final bool emergencyServiceAvailable;
  final bool mobileRepairAvailable;
  final bool collectionServiceAvailable;
  final String verificationStatus;
  final double averageRating;
  final int reviewCount;
  final int completedJobCount;
  final double responseRate;
  final double quoteAcceptanceRate;
  final List<RepairerSpecialisation> specialisations;
  final List<String> certifications;
  final List<RepairerServiceArea> serviceAreas;
  final List<String> availability;

  bool get isVerified => verificationStatus == 'verified';
}

@immutable
class RepairerDashboardSummary {
  const RepairerDashboardSummary({
    required this.profile,
    required this.matches,
    required this.newMatchCount,
    required this.nearbyCount,
    required this.highUrgencyCount,
    required this.submittedQuoteCount,
    required this.activeJobCount,
    required this.ongoingJobCount,
    required this.waitingForPartsCount,
    required this.completedJobCount,
    required this.todayAppointmentCount,
    required this.monthEarningsMinor,
  });

  final RepairerMarketplaceProfile profile;
  final List<MarketplaceRequest> matches;
  final int newMatchCount;
  final int nearbyCount;
  final int highUrgencyCount;
  final int submittedQuoteCount;
  final int activeJobCount;
  final int ongoingJobCount;
  final int waitingForPartsCount;
  final int completedJobCount;
  final int todayAppointmentCount;
  final int monthEarningsMinor;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, Object?>{};
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _string(Object? value, {String fallback = ''}) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? fallback : result;
}

String? _nullableString(Object? value) {
  final result = value?.toString().trim() ?? '';
  return result.isEmpty ? null : result;
}

double _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

double? _nullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  return switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text),
    _ => null,
  };
}

int _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

int? _nullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  return switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };
}

bool _bool(Object? value) => switch (value) {
  final bool boolean => boolean,
  final String text => text.toLowerCase() == 'true',
  final num number => number != 0,
  _ => false,
};

String _evidenceLabel(String kind) => switch (kind) {
  'image' => 'Customer photo',
  'video' => 'Customer video',
  'audio' => 'Customer audio',
  'error_code' => 'Error-code evidence',
  'receipt' => 'Purchase receipt',
  'warranty' => 'Warranty evidence',
  _ => 'Customer document',
};
