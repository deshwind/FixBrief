import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:flutter/foundation.dart';

enum RepairerMarketplacePhase { initial, loading, ready, failure }

@immutable
class RepairerMarketplaceState {
  const RepairerMarketplaceState({
    this.phase = RepairerMarketplacePhase.initial,
    this.dashboard,
    this.matches = const [],
    this.filters = const MarketplaceFilters(),
    this.errorMessage,
    this.isRefreshing = false,
  });

  final RepairerMarketplacePhase phase;
  final RepairerDashboardSummary? dashboard;
  final List<MarketplaceRequest> matches;
  final MarketplaceFilters filters;
  final String? errorMessage;
  final bool isRefreshing;

  RepairerMarketplaceState copyWith({
    RepairerMarketplacePhase? phase,
    RepairerDashboardSummary? dashboard,
    List<MarketplaceRequest>? matches,
    MarketplaceFilters? filters,
    String? errorMessage,
    bool clearError = false,
    bool? isRefreshing,
  }) {
    return RepairerMarketplaceState(
      phase: phase ?? this.phase,
      dashboard: dashboard ?? this.dashboard,
      matches: matches ?? this.matches,
      filters: filters ?? this.filters,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
