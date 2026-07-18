import 'package:fixbrief/core/config/app_environment_provider.dart';
import 'package:fixbrief/core/services/supabase_provider.dart';
import 'package:fixbrief/features/quotes/data/repositories/demo_quote_repository.dart';
import 'package:fixbrief/features/quotes/data/repositories/supabase_quote_repository.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/domain/repositories/quote_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteRepositoryProvider = Provider<QuoteRepository>((ref) {
  if (ref.watch(appEnvironmentProvider).useDemoAuthentication) {
    return DemoQuoteRepository();
  }
  return SupabaseQuoteRepository(ref.watch(supabaseClientProvider));
});

final repairerQuoteProvider = FutureProvider.autoDispose
    .family<ProvisionalQuote?, String>((ref, requestId) {
      return ref.watch(quoteRepositoryProvider).loadMyQuote(requestId);
    });

final repairerQuotesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(quoteRepositoryProvider).loadMyQuotes();
});

final quoteComparisonProvider = FutureProvider.autoDispose
    .family<QuoteComparison, String>((ref, requestId) {
      return ref.watch(quoteRepositoryProvider).loadComparison(requestId);
    });
