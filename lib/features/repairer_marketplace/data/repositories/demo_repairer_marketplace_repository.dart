import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/repositories/repairer_marketplace_repository.dart';

class DemoRepairerMarketplaceRepository
    implements RepairerMarketplaceRepository {
  DemoRepairerMarketplaceRepository({this.simulatedDelay = Duration.zero});

  final Duration simulatedDelay;

  static final RepairerMarketplaceProfile _profile = RepairerMarketplaceProfile(
    userId: 'demo-repairer-northline',
    fullName: 'Sam North',
    businessName: 'Northline Repairs',
    description:
        'Independent diagnostics and repair across vehicles, appliances, and everyday technology in Greater Manchester.',
    yearsExperience: 14,
    qualifications: const [
      'IMI Level 3 Light Vehicle Maintenance',
      'City & Guilds electrical safety',
    ],
    inspectionFeeMinor: 4500,
    currencyCode: 'GBP',
    serviceRadiusKilometres: 35,
    workingHours: 'Mon–Fri 08:00–18:00, Sat 09:00–14:00',
    emergencyServiceAvailable: true,
    mobileRepairAvailable: true,
    collectionServiceAvailable: true,
    verificationStatus: 'verified',
    averageRating: 4.8,
    reviewCount: 126,
    completedJobCount: 214,
    responseRate: 94,
    quoteAcceptanceRate: 61,
    specialisations: const [
      RepairerSpecialisation(
        category: 'Vehicles',
        subcategory: 'Steering and suspension',
        label: 'Vehicle noise diagnostics',
        yearsExperience: 14,
      ),
      RepairerSpecialisation(
        category: 'Appliances',
        subcategory: 'Laundry appliances',
        label: 'Drum and suspension faults',
        yearsExperience: 9,
      ),
      RepairerSpecialisation(
        category: 'Computers',
        subcategory: 'Laptops',
        label: 'Thermal diagnostics',
        yearsExperience: 8,
      ),
    ],
    certifications: const [
      'Public liability insurance verified',
      'Electrical safety certification',
    ],
    serviceAreas: const [
      RepairerServiceArea(
        name: 'Greater Manchester',
        radiusKilometres: 35,
        emergencyService: true,
        mobileRepair: true,
        collectionService: true,
      ),
    ],
    availability: const ['Weekdays · 08:00–18:00', 'Saturday · 09:00–14:00'],
  );

  static final Map<String, RepairerMarketplaceProfile> _comparisonProfiles = {
    'demo-repairer-quickfix': _quoteProfile(
      id: 'demo-repairer-quickfix',
      name: 'QuickFix Automotive',
      rating: 4.2,
      reviews: 38,
      jobs: 63,
      responseRate: 82,
      warrantyQualification: 'Vehicle maintenance certificate',
    ),
    'demo-repairer-mancunian': _quoteProfile(
      id: 'demo-repairer-mancunian',
      name: 'Mancunian Motor Care',
      rating: 4.9,
      reviews: 287,
      jobs: 412,
      responseRate: 97,
      warrantyQualification: 'IMI Level 3 Light Vehicle Maintenance',
    ),
    'demo-repairer-apex': _quoteProfile(
      id: 'demo-repairer-apex',
      name: 'Apex Vehicle Diagnostics',
      rating: 4.7,
      reviews: 142,
      jobs: 198,
      responseRate: 92,
      warrantyQualification: 'Advanced vehicle diagnostics',
    ),
  };

  static RepairerMarketplaceProfile _quoteProfile({
    required String id,
    required String name,
    required double rating,
    required int reviews,
    required int jobs,
    required double responseRate,
    required String warrantyQualification,
  }) {
    return RepairerMarketplaceProfile(
      userId: id,
      fullName: name,
      businessName: name,
      description:
          'Verified Greater Manchester vehicle repair business with transparent provisional estimates and inspection-led repairs.',
      yearsExperience: 12,
      qualifications: [warrantyQualification],
      inspectionFeeMinor: 3500,
      currencyCode: 'GBP',
      serviceRadiusKilometres: 30,
      workingHours: 'Mon–Fri 08:00–18:00',
      emergencyServiceAvailable: false,
      mobileRepairAvailable: true,
      collectionServiceAvailable: true,
      verificationStatus: 'verified',
      averageRating: rating,
      reviewCount: reviews,
      completedJobCount: jobs,
      responseRate: responseRate,
      quoteAcceptanceRate: 64,
      specialisations: const [
        RepairerSpecialisation(
          category: 'Vehicles',
          subcategory: 'Steering and suspension',
          label: 'Steering and suspension diagnostics',
          yearsExperience: 10,
        ),
      ],
      certifications: const ['Identity and business verification complete'],
      serviceAreas: const [
        RepairerServiceArea(
          name: 'Greater Manchester',
          radiusKilometres: 30,
          emergencyService: false,
          mobileRepair: true,
          collectionService: true,
        ),
      ],
      availability: const ['Weekdays · 08:00–18:00'],
    );
  }

  static List<MarketplaceRequest> get _requests {
    final now = DateTime.now();
    return [
      MarketplaceRequest(
        id: 'demo-request-vehicle',
        categoryId: 'vehicles',
        categoryName: 'Vehicles',
        subcategoryId: 'steering-suspension',
        subcategoryName: 'Steering and suspension',
        itemName: 'Ford Focus',
        summary:
            'Repeated clicking from the front-left wheel area during low-speed turns.',
        approximateArea: 'Chorlton area',
        distanceKilometres: 2.4,
        urgency: MarketplaceUrgency.within24Hours,
        publishedAt: now.subtract(const Duration(minutes: 18)),
        matchScore: 96,
        matchReasons: const [
          'Exact steering specialisation',
          '2.4 km within your service area',
          'Available for this urgency',
        ],
        inspectionRequired: true,
        evidenceCount: 2,
        safetyRisk: 'moderate',
      ),
      MarketplaceRequest(
        id: 'demo-request-appliance',
        categoryId: 'appliances',
        categoryName: 'Appliances',
        subcategoryId: 'laundry',
        subcategoryName: 'Laundry appliances',
        itemName: 'Bosch washing machine',
        summary:
            'Heavy vibration and a loud knock during the spin cycle; movement is getting worse.',
        approximateArea: 'Didsbury area',
        distanceKilometres: 4.1,
        urgency: MarketplaceUrgency.within3Days,
        publishedAt: now.subtract(const Duration(minutes: 42)),
        matchScore: 91,
        matchReasons: const [
          'Laundry-appliance specialisation',
          'Mobile service requested and available',
          'Strong response history',
        ],
        mobileRepairRequired: true,
        inspectionRequired: true,
        evidenceCount: 3,
        safetyRisk: 'low',
      ),
      MarketplaceRequest(
        id: 'demo-request-laptop',
        categoryId: 'computers',
        categoryName: 'Computers',
        subcategoryId: 'laptops',
        subcategoryName: 'Laptops',
        itemName: 'Dell Latitude laptop',
        summary:
            'Cooling fan becomes very loud and the laptop shuts down during video calls.',
        approximateArea: 'Withington area',
        distanceKilometres: 5.8,
        urgency: MarketplaceUrgency.within3Days,
        publishedAt: now.subtract(const Duration(hours: 2)),
        matchScore: 87,
        matchReasons: const [
          'Thermal-diagnostics experience',
          'Collection service is available',
          'Inside your 35 km service radius',
        ],
        collectionRequired: true,
        evidenceCount: 1,
        safetyRisk: 'moderate',
      ),
      MarketplaceRequest(
        id: 'demo-request-plumbing',
        categoryId: 'plumbing',
        categoryName: 'Plumbing',
        subcategoryId: 'leaks',
        subcategoryName: 'Leaks and pipework',
        itemName: 'Kitchen sink pipe',
        summary:
            'A slow leak is visible beneath the sink around a compression joint.',
        approximateArea: 'Sale area',
        distanceKilometres: 7.6,
        urgency: MarketplaceUrgency.within24Hours,
        publishedAt: now.subtract(const Duration(hours: 3)),
        matchScore: 83,
        matchReasons: const [
          'Mobile repair capability',
          'Available within 24 hours',
          'Nearby request',
        ],
        mobileRepairRequired: true,
        evidenceCount: 2,
        safetyRisk: 'moderate',
      ),
      MarketplaceRequest(
        id: 'demo-request-bicycle',
        categoryId: 'bicycles',
        categoryName: 'Bicycles',
        subcategoryId: 'brakes',
        subcategoryName: 'Brakes',
        itemName: 'Trek commuter bicycle',
        summary:
            'Rear brake lever reaches the handlebar and braking effectiveness is poor.',
        approximateArea: 'Stretford area',
        distanceKilometres: 9.2,
        urgency: MarketplaceUrgency.asap,
        publishedAt: now.subtract(const Duration(hours: 5)),
        matchScore: 78,
        matchReasons: const [
          'High-urgency availability',
          'Collection service is available',
          'Inside your service radius',
        ],
        collectionRequired: true,
        evidenceCount: 2,
        safetyRisk: 'high',
        stopUsingItem: true,
      ),
      MarketplaceRequest(
        id: 'demo-request-furniture',
        categoryId: 'furniture',
        categoryName: 'Furniture',
        subcategoryId: 'joints',
        subcategoryName: 'Joints and structure',
        itemName: 'Dining chair',
        summary:
            'One rear leg is loose and the joint opens when light weight is applied.',
        approximateArea: 'Stockport area',
        distanceKilometres: 14.3,
        urgency: MarketplaceUrgency.flexible,
        publishedAt: now.subtract(const Duration(days: 1)),
        matchScore: 68,
        matchReasons: const [
          'Mobile service capability',
          'Inside your service radius',
        ],
        mobileRepairRequired: true,
        inspectionRequired: true,
        evidenceCount: 1,
        safetyRisk: 'moderate',
        stopUsingItem: true,
      ),
    ];
  }

  @override
  Future<List<MarketplaceRequest>> findMatches(
    MarketplaceFilters filters,
  ) async {
    await _wait();
    final query = filters.search.trim().toLowerCase();
    final results = _requests
        .where((request) {
          final searchable = <String>[
            request.itemName,
            request.summary,
            request.categoryName,
            request.subcategoryName ?? '',
            request.approximateArea,
          ].join(' ').toLowerCase();
          return (query.isEmpty || searchable.contains(query)) &&
              (filters.categoryId == null ||
                  request.categoryId == filters.categoryId) &&
              (filters.urgency == null || request.urgency == filters.urgency) &&
              (filters.maximumDistanceKilometres == null ||
                  (request.distanceKilometres != null &&
                      request.distanceKilometres! <=
                          filters.maximumDistanceKilometres!)) &&
              (!filters.mobileOnly || request.mobileRepairRequired) &&
              (!filters.collectionOnly || request.collectionRequired);
        })
        .toList(growable: true);

    results.sort(switch (filters.sort) {
      MarketplaceSort.bestMatch => (a, b) => b.matchScore.compareTo(
        a.matchScore,
      ),
      MarketplaceSort.nearest =>
        (a, b) => (a.distanceKilometres ?? double.infinity).compareTo(
          b.distanceKilometres ?? double.infinity,
        ),
      MarketplaceSort.newest => (a, b) => b.publishedAt.compareTo(
        a.publishedAt,
      ),
      MarketplaceSort.urgent =>
        (a, b) => a.urgency.index != b.urgency.index
            ? a.urgency.index.compareTo(b.urgency.index)
            : b.matchScore.compareTo(a.matchScore),
    });
    return List.unmodifiable(results);
  }

  @override
  Future<RepairerDashboardSummary> loadDashboard() async {
    final matches = await findMatches(const MarketplaceFilters());
    return RepairerDashboardSummary(
      profile: _profile,
      matches: matches.take(3).toList(growable: false),
      newMatchCount: matches.length,
      nearbyCount: matches.where((request) => request.isNearby).length,
      highUrgencyCount: matches
          .where((request) => request.urgency.isHighPriority)
          .length,
      submittedQuoteCount: 3,
      activeJobCount: 4,
      ongoingJobCount: 2,
      waitingForPartsCount: 1,
      completedJobCount: 214,
      todayAppointmentCount: 2,
      monthEarningsMinor: 384000,
    );
  }

  @override
  Future<RepairerMarketplaceProfile> loadProfile({String? repairerId}) async {
    await _wait();
    if (repairerId == null ||
        repairerId.isEmpty ||
        repairerId == _profile.userId) {
      return _profile;
    }
    final comparisonProfile = _comparisonProfiles[repairerId];
    if (comparisonProfile == null) {
      throw const RepairerMarketplaceFailure(
        'This repairer profile is no longer available.',
        code: 'profile_not_found',
      );
    }
    return comparisonProfile;
  }

  @override
  Future<MarketplaceRequestDetail> loadRequest(String requestId) async {
    await _wait();
    final request = _requests.firstWhereOrNull((item) => item.id == requestId);
    if (request == null) {
      throw const RepairerMarketplaceFailure(
        'This request is no longer available or no longer matches your services.',
        code: 'request_not_found',
      );
    }
    final isVehicle = request.id == 'demo-request-vehicle';
    final isAppliance = request.id == 'demo-request-appliance';
    final highRisk = request.safetyRisk == 'high';
    return MarketplaceRequestDetail(
      request: request,
      brand: isVehicle ? 'Ford' : (isAppliance ? 'Bosch' : null),
      model: isVehicle ? 'Focus · 2017' : (isAppliance ? 'Series 4' : null),
      previousRepairs: isVehicle
          ? 'Front tyres replaced approximately eight months ago.'
          : null,
      problemDescription: request.summary,
      repairBrief:
          'Inspect the reported area and confirm the fault in person before providing a final repair price. Check the supplied evidence and service requirements before arranging access.',
      preferredDate: DateTime.now().add(const Duration(days: 2)),
      symptoms: [
        request.summary,
        if (isVehicle) 'Sound is most noticeable during slow left turns.',
        if (isAppliance) 'The item has moved forward twice during a spin.',
      ],
      evidence: List.generate(
        request.evidenceCount,
        (index) => MarketplaceEvidence(
          id: '${request.id}-evidence-$index',
          kind: index == 0 ? 'image' : 'video',
          mimeType: index == 0 ? 'image/jpeg' : 'video/mp4',
          label: index == 0 ? 'Customer photo' : 'Short customer video',
          durationMilliseconds: index == 0 ? null : 18000,
        ),
        growable: false,
      ),
      assessment: MarketplaceAssessment(
        summary: request.summary,
        disclaimer: 'AI-assisted assessment — not a confirmed diagnosis.',
        confidence: 'medium',
        safetyRisk: request.safetyRisk,
        stopUsingItem: request.stopUsingItem,
        safetyWarning: highRisk
            ? 'Do not use the item until its safety-critical components have been inspected.'
            : 'Stop using the item if the symptoms become severe or unsafe.',
        recommendedProfessional: request.categoryName == 'Vehicles'
            ? 'Vehicle technician'
            : 'Qualified ${request.categoryName.toLowerCase()} repairer',
        inspectionRecommendation:
            'Physical inspection recommended before confirming the exact fault or final price.',
        possibleCauses: const [
          MarketplacePossibleCause(
            cause: 'Component wear or adjustment issue',
            confidence: 0.58,
            reason:
                'The reported symptoms make this a reasonable inspection area, but they do not confirm a diagnosis.',
          ),
          MarketplacePossibleCause(
            cause: 'Installation or alignment issue',
            confidence: 0.34,
            reason:
                'Alignment should be ruled out during a safe physical inspection.',
          ),
        ],
      ),
      privacyNotice:
          'Only ${request.approximateArea} is shown. The customer’s name, contact details and exact address stay private until a quote is accepted or an inspection is confirmed.',
    );
  }

  Future<void> _wait() async {
    if (simulatedDelay > Duration.zero) {
      await Future<void>.delayed(simulatedDelay);
    }
  }
}
