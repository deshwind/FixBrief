import 'dart:async';

import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/repositories/repairer_marketplace_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRepairerMarketplaceRepository
    implements RepairerMarketplaceRepository {
  SupabaseRepairerMarketplaceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MarketplaceRequest>> findMatches(
    MarketplaceFilters filters,
  ) async {
    try {
      final response = await _client
          .rpc<List<dynamic>>(
            'get_ranked_marketplace_requests',
            params: <String, Object?>{
              'category_filter': filters.categoryId,
              'urgency_filter': filters.urgency?.databaseValue,
              'maximum_distance_kilometres': filters.maximumDistanceKilometres,
              'search_query': filters.search.trim().isEmpty
                  ? null
                  : filters.search.trim(),
              'mobile_only': filters.mobileOnly,
              'collection_only': filters.collectionOnly,
              'sort_mode': filters.sort.databaseValue,
              'result_limit': 50,
              'result_offset': 0,
            },
          )
          .timeout(const Duration(seconds: 20));
      return response
          .map(_map)
          .map(MarketplaceRequest.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'load matching requests');
    } on TimeoutException {
      throw const RepairerMarketplaceFailure(
        'Matching requests are taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  @override
  Future<RepairerDashboardSummary> loadDashboard() async {
    try {
      final values = await Future.wait<Object?>([
        loadProfile(),
        findMatches(const MarketplaceFilters()),
        _client
            .rpc<Object?>('get_repairer_marketplace_summary')
            .timeout(const Duration(seconds: 20)),
      ]);
      final profile = values[0] as RepairerMarketplaceProfile;
      final matches = values[1] as List<MarketplaceRequest>;
      final summary = _map(values[2]);
      return RepairerDashboardSummary(
        profile: profile,
        matches: matches.take(3).toList(growable: false),
        newMatchCount: _int(
          summary['new_match_count'],
          fallback: matches.length,
        ),
        nearbyCount: _int(
          summary['nearby_count'],
          fallback: matches.where((request) => request.isNearby).length,
        ),
        highUrgencyCount: _int(
          summary['high_urgency_count'],
          fallback: matches
              .where((request) => request.urgency.isHighPriority)
              .length,
        ),
        submittedQuoteCount: _int(summary['submitted_quote_count']),
        activeJobCount: _int(summary['active_job_count']),
        ongoingJobCount: _int(summary['ongoing_job_count']),
        waitingForPartsCount: _int(summary['waiting_for_parts_count']),
        completedJobCount: _int(
          summary['completed_job_count'],
          fallback: profile.completedJobCount,
        ),
        todayAppointmentCount: _int(summary['today_appointment_count']),
        monthEarningsMinor: _int(summary['month_earnings_minor']),
      );
    } on RepairerMarketplaceFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'load your marketplace dashboard');
    } on TimeoutException {
      throw const RepairerMarketplaceFailure(
        'The marketplace dashboard is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  @override
  Future<RepairerMarketplaceProfile> loadProfile({String? repairerId}) async {
    try {
      final response = await _client
          .rpc<Object?>(
            'get_repairer_marketplace_profile',
            params: <String, Object?>{'target_repairer_id': repairerId},
          )
          .timeout(const Duration(seconds: 20));
      final data = _map(response);
      if (data.isEmpty) {
        throw const RepairerMarketplaceFailure(
          'This repairer profile is no longer available.',
          code: 'profile_not_found',
        );
      }
      final logoPath = data['logo_path']?.toString();
      if (logoPath != null && logoPath.isNotEmpty) {
        try {
          data['logo_url'] = await _client.storage
              .from('business-logos')
              .createSignedUrl(logoPath, 300);
        } on StorageException {
          // A logo is optional; the rest of the verified profile is useful.
        }
      }
      data.remove('logo_path');
      return RepairerMarketplaceProfile.fromJson(data);
    } on RepairerMarketplaceFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'load the repairer profile');
    } on TimeoutException {
      throw const RepairerMarketplaceFailure(
        'The repairer profile is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  @override
  Future<MarketplaceRequestDetail> loadRequest(String requestId) async {
    if (requestId.trim().isEmpty || requestId.length > 100) {
      throw const RepairerMarketplaceFailure(
        'The repair request link is invalid.',
        code: 'invalid_request_id',
      );
    }
    try {
      final response = await _client
          .rpc<Object?>(
            'get_marketplace_request_detail',
            params: <String, Object?>{'target_request_id': requestId},
          )
          .timeout(const Duration(seconds: 20));
      final data = _map(response);
      if (data.isEmpty) {
        throw const RepairerMarketplaceFailure(
          'This request is no longer available or no longer matches your services.',
          code: 'request_not_found',
        );
      }
      final evidence = _mapList(data['evidence']);
      data['evidence'] = await Future.wait(
        evidence.map((item) async {
          final safeItem = Map<String, Object?>.from(item);
          final bucket = safeItem.remove('bucket_name')?.toString();
          final path = safeItem.remove('object_path')?.toString();
          if (bucket != null && path != null) {
            try {
              safeItem['signed_url'] = await _client.storage
                  .from(bucket)
                  .createSignedUrl(path, 300);
            } on StorageException {
              // Keep the evidence metadata visible if its preview expires.
            }
          }
          return safeItem;
        }),
      );
      return MarketplaceRequestDetail.fromJson(data);
    } on RepairerMarketplaceFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapFailure(error, action: 'load this repair request');
    } on TimeoutException {
      throw const RepairerMarketplaceFailure(
        'This repair request is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }

  static RepairerMarketplaceFailure _mapFailure(
    PostgrestException error, {
    required String action,
  }) {
    final setupMissing =
        error.code == '42P01' ||
        error.code == '42883' ||
        error.code == 'PGRST202';
    final forbidden = error.code == '42501';
    return RepairerMarketplaceFailure(
      setupMissing
          ? 'The Stage 7 marketplace migration has not been deployed in this environment.'
          : forbidden
          ? 'This request is outside your verified services or is no longer available.'
          : 'We could not $action. Check your connection and try again.',
      code: error.code,
    );
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.from(value);
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, Object?>{};
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}

int _int(Object? value, {int fallback = 0}) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};
