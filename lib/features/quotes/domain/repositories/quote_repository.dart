import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';

abstract interface class QuoteRepository {
  Future<ProvisionalQuote?> loadMyQuote(String requestId);

  Future<List<ProvisionalQuote>> loadMyQuotes();

  Future<ProvisionalQuote> saveDraft(QuoteDraftInput input);

  Future<ProvisionalQuote> submitQuote(String quoteId);

  Future<ProvisionalQuote> withdrawQuote(String quoteId);

  Future<QuoteComparison> loadComparison(String requestId);

  Future<String> acceptQuote(String quoteId, {required String idempotencyKey});
}
