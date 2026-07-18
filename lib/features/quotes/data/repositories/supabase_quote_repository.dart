import 'dart:async';

import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/domain/repositories/quote_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseQuoteRepository implements QuoteRepository {
  SupabaseQuoteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<ProvisionalQuote?> loadMyQuote(String requestId) async {
    final response = await _rpc(
      'get_repairer_quote',
      params: {'target_request_id': requestId},
    );
    if (response == null) {
      return null;
    }
    final data = _map(response);
    return data.isEmpty ? null : ProvisionalQuote.fromJson(data);
  }

  @override
  Future<List<ProvisionalQuote>> loadMyQuotes() async {
    final response = await _rpc('get_repairer_quotes');
    return _maps(
      response,
    ).map(ProvisionalQuote.fromJson).toList(growable: false);
  }

  @override
  Future<ProvisionalQuote> saveDraft(QuoteDraftInput input) async {
    final response = await _rpc(
      'save_quote_draft',
      params: {
        'target_request_id': input.requestId,
        'target_quote_id': input.quoteId,
        'quote_payload': input.toJson(),
      },
    );
    return ProvisionalQuote.fromJson(_map(response));
  }

  @override
  Future<ProvisionalQuote> submitQuote(String quoteId) async {
    final response = await _rpc(
      'submit_quote',
      params: {'target_quote_id': quoteId},
    );
    return ProvisionalQuote.fromJson(_map(response));
  }

  @override
  Future<ProvisionalQuote> withdrawQuote(String quoteId) async {
    final response = await _rpc(
      'withdraw_quote',
      params: {'target_quote_id': quoteId},
    );
    return ProvisionalQuote.fromJson(_map(response));
  }

  @override
  Future<QuoteComparison> loadComparison(String requestId) async {
    final response = await _rpc(
      'get_customer_quote_comparison',
      params: {'target_request_id': requestId},
    );
    return QuoteComparison.fromJson(_map(response));
  }

  @override
  Future<String> acceptQuote(
    String quoteId, {
    required String idempotencyKey,
  }) async {
    final response = await _rpc(
      'accept_quote',
      params: {'quote_id': quoteId, 'idempotency_key': idempotencyKey},
    );
    final id = response?.toString() ?? '';
    if (id.isEmpty) {
      throw const QuoteFailure('The accepted job could not be confirmed.');
    }
    return id;
  }

  Future<Object?> _rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    try {
      return await _client
          .rpc<Object?>(function, params: params)
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      final setupMissing =
          error.code == '42P01' ||
          error.code == '42883' ||
          error.code == 'PGRST202';
      final invalid = error.code == '22023' || error.code == '23514';
      throw QuoteFailure(
        setupMissing
            ? 'The Stage 8 quote migration has not been deployed in this environment.'
            : invalid
            ? error.message
            : error.code == '42501'
            ? 'This quote is no longer available to your account.'
            : 'We could not update quotes. Check your connection and try again.',
        code: error.code,
      );
    } on TimeoutException {
      throw const QuoteFailure(
        'The quote service is taking longer than expected. Try again.',
        code: 'timeout',
      );
    }
  }
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, Object?>> _maps(Object? value) {
  if (value is! Iterable) {
    return const [];
  }
  return value.map(_map).toList(growable: false);
}
