import 'dart:async';

import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/repositories/repairer_marketplace_repository.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/controllers/repairer_marketplace_state.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RepairerMarketplaceController extends Notifier<RepairerMarketplaceState> {
  late RepairerMarketplaceRepository _repository;
  Timer? _searchTimer;

  @override
  RepairerMarketplaceState build() {
    _repository = ref.watch(repairerMarketplaceRepositoryProvider);
    ref.onDispose(() => _searchTimer?.cancel());
    unawaited(Future<void>.microtask(loadDashboard));
    return const RepairerMarketplaceState();
  }

  Future<void> loadDashboard({bool refresh = false}) async {
    state = state.copyWith(
      phase: state.dashboard == null
          ? RepairerMarketplacePhase.loading
          : RepairerMarketplacePhase.ready,
      isRefreshing: refresh,
      clearError: true,
    );
    try {
      final dashboard = await _repository.loadDashboard();
      state = state.copyWith(
        phase: RepairerMarketplacePhase.ready,
        dashboard: dashboard,
        matches: dashboard.matches,
        isRefreshing: false,
        clearError: true,
      );
    } on RepairerMarketplaceFailure catch (failure) {
      state = state.copyWith(
        phase: state.dashboard == null
            ? RepairerMarketplacePhase.failure
            : RepairerMarketplacePhase.ready,
        isRefreshing: false,
        errorMessage: failure.message,
      );
    } on Object {
      state = state.copyWith(
        phase: state.dashboard == null
            ? RepairerMarketplacePhase.failure
            : RepairerMarketplacePhase.ready,
        isRefreshing: false,
        errorMessage:
            'The marketplace could not be loaded. Check your connection and try again.',
      );
    }
  }

  Future<void> loadMatches({bool refresh = false}) async {
    state = state.copyWith(
      phase: state.matches.isEmpty
          ? RepairerMarketplacePhase.loading
          : RepairerMarketplacePhase.ready,
      isRefreshing: refresh,
      clearError: true,
    );
    try {
      final matches = await _repository.findMatches(state.filters);
      state = state.copyWith(
        phase: RepairerMarketplacePhase.ready,
        matches: matches,
        isRefreshing: false,
        clearError: true,
      );
    } on RepairerMarketplaceFailure catch (failure) {
      state = state.copyWith(
        phase: state.matches.isEmpty
            ? RepairerMarketplacePhase.failure
            : RepairerMarketplacePhase.ready,
        isRefreshing: false,
        errorMessage: failure.message,
      );
    } on Object {
      state = state.copyWith(
        phase: state.matches.isEmpty
            ? RepairerMarketplacePhase.failure
            : RepairerMarketplacePhase.ready,
        isRefreshing: false,
        errorMessage:
            'Matching requests could not be refreshed. Check your connection and try again.',
      );
    }
  }

  void setSearch(String value) {
    state = state.copyWith(filters: state.filters.copyWith(search: value));
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), loadMatches);
  }

  Future<void> setCategory(String? categoryId) async {
    state = state.copyWith(
      filters: state.filters.copyWith(
        categoryId: categoryId,
        clearCategory: categoryId == null,
      ),
    );
    await loadMatches();
  }

  Future<void> setUrgency(MarketplaceUrgency? urgency) async {
    state = state.copyWith(
      filters: state.filters.copyWith(
        urgency: urgency,
        clearUrgency: urgency == null,
      ),
    );
    await loadMatches();
  }

  Future<void> setMaximumDistance(double? kilometres) async {
    state = state.copyWith(
      filters: state.filters.copyWith(
        maximumDistanceKilometres: kilometres,
        clearMaximumDistance: kilometres == null,
      ),
    );
    await loadMatches();
  }

  Future<void> setMobileOnly(bool value) async {
    state = state.copyWith(filters: state.filters.copyWith(mobileOnly: value));
    await loadMatches();
  }

  Future<void> setCollectionOnly(bool value) async {
    state = state.copyWith(
      filters: state.filters.copyWith(collectionOnly: value),
    );
    await loadMatches();
  }

  Future<void> setSort(MarketplaceSort sort) async {
    state = state.copyWith(filters: state.filters.copyWith(sort: sort));
    await loadMatches();
  }

  Future<void> applyFilters(MarketplaceFilters filters) async {
    _searchTimer?.cancel();
    state = state.copyWith(filters: filters);
    await loadMatches();
  }

  Future<void> clearFilters() async {
    _searchTimer?.cancel();
    state = state.copyWith(filters: const MarketplaceFilters());
    await loadMatches();
  }
}
