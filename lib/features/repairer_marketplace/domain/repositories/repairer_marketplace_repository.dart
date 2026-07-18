import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';

abstract interface class RepairerMarketplaceRepository {
  Future<RepairerDashboardSummary> loadDashboard();

  Future<List<MarketplaceRequest>> findMatches(MarketplaceFilters filters);

  Future<MarketplaceRequestDetail> loadRequest(String requestId);

  Future<RepairerMarketplaceProfile> loadProfile({String? repairerId});
}

class RepairerMarketplaceFailure implements Exception {
  const RepairerMarketplaceFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
