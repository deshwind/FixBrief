import 'package:fixbrief/features/repairer_marketplace/data/repositories/demo_repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('marketplace models', () {
    test('maps a ranked privacy-safe request response', () {
      final request = MarketplaceRequest.fromJson(<String, Object?>{
        'id': 'request-1',
        'category_id': 'vehicles',
        'category_name': 'Vehicles',
        'subcategory_name': 'Steering',
        'item_name': 'Family car',
        'problem_summary': 'Clicking while turning',
        'approximate_area': 'Chorlton area',
        'distance_kilometres': '2.45',
        'urgency': 'within_24_hours',
        'published_at': '2026-07-18T12:00:00Z',
        'match_score': '94.25',
        'match_reasons': <String>['Exact specialisation', 'Nearby'],
        'evidence_count': 2,
        'total_count': 6,
      });

      expect(request.urgency, MarketplaceUrgency.within24Hours);
      expect(request.distanceKilometres, 2.45);
      expect(request.matchScore, 94.25);
      expect(request.categoryLine, 'Vehicles · Steering');
      expect(request.totalCount, 6);
    });

    test('detail model has no customer identity or exact-address field', () {
      final detail = MarketplaceRequestDetail.fromJson(<String, Object?>{
        'request': <String, Object?>{
          'id': 'request-1',
          'category_id': 'vehicles',
          'category_name': 'Vehicles',
          'item_name': 'Family car',
          'problem_summary': 'Clicking while turning',
          'problem_description': 'Clicking while turning',
          'structured_brief': 'Inspect before pricing.',
          'approximate_area': 'Chorlton area',
          'urgency': 'within_3_days',
          'published_at': '2026-07-18T12:00:00Z',
          'match_score': 80,
          'match_reasons': <String>['Category match'],
        },
        'symptoms': <String>['Clicking sound'],
        'evidence': <Object?>[],
        'privacy_notice': 'Exact address remains private.',
      });

      expect(detail.request.approximateArea, 'Chorlton area');
      expect(detail.privacyNotice, contains('Exact address'));
    });
  });

  group('demo marketplace repository', () {
    late DemoRepairerMarketplaceRepository repository;

    setUp(() {
      repository = DemoRepairerMarketplaceRepository();
    });

    test('ranks best matches in descending score order', () async {
      final matches = await repository.findMatches(const MarketplaceFilters());

      expect(matches, hasLength(6));
      expect(matches.first.id, 'demo-request-vehicle');
      for (var index = 1; index < matches.length; index++) {
        expect(
          matches[index - 1].matchScore,
          greaterThanOrEqualTo(matches[index].matchScore),
        );
      }
    });

    test('combines category, distance, and service filters', () async {
      final matches = await repository.findMatches(
        const MarketplaceFilters(
          categoryId: 'appliances',
          maximumDistanceKilometres: 5,
          mobileOnly: true,
        ),
      );

      expect(matches, hasLength(1));
      expect(matches.single.id, 'demo-request-appliance');
    });

    test(
      'request detail keeps customer identity and address private',
      () async {
        final detail = await repository.loadRequest('demo-request-vehicle');

        expect(detail.privacyNotice, contains('name'));
        expect(detail.privacyNotice, contains('exact address'));
        expect(
          detail.assessment?.disclaimer,
          contains('not a confirmed diagnosis'),
        );
        expect(detail.request.approximateArea, 'Chorlton area');
      },
    );
  });
}
