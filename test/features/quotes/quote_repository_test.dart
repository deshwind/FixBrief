import 'package:fixbrief/features/quotes/data/repositories/demo_quote_repository.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Stage 8 quote domain', () {
    test('calculates minimum and maximum totals from every component', () {
      final input = QuoteDraftInput.initial('demo-request-vehicle');

      expect(input.totalMinimumMinor, 13500);
      expect(input.totalMaximumMinor, 47500);
    });

    test('saves, submits, edits, and withdraws a repairer quote', () async {
      final repository = DemoQuoteRepository();
      final input = QuoteDraftInput.initial('demo-request-vehicle');

      final draft = await repository.saveDraft(input);
      expect(draft.status, QuoteStatus.draft);

      final submitted = await repository.submitQuote(draft.id);
      expect(submitted.status, QuoteStatus.submitted);

      final edited = await repository.saveDraft(
        QuoteDraftInput.fromQuote(submitted),
      );
      expect(edited.status, QuoteStatus.submitted);
      expect(edited.totalMaximumMinor, 47500);

      final withdrawn = await repository.withdrawQuote(edited.id);
      expect(withdrawn.status, QuoteStatus.withdrawn);
      expect(withdrawn.canAccept, isFalse);
    });

    test(
      'explains overall fit without recommending the cheapest quote',
      () async {
        final repository = DemoQuoteRepository();
        final comparison = await repository.loadComparison(
          'demo-request-vehicle',
        );

        expect(comparison.quotes, hasLength(3));
        final recommended = comparison.quotes.singleWhere(
          (quote) => quote.isRecommended,
        );
        final cheapest = comparison.quotes.reduce(
          (current, next) => current.totalMaximumMinor < next.totalMaximumMinor
              ? current
              : next,
        );

        expect(recommended.id, isNot(cheapest.id));
        expect(recommended.recommendationReasons, isNotEmpty);
        expect(
          recommended.recommendationReasons.join(' ').toLowerCase(),
          isNot(contains('cheapest')),
        );
      },
    );

    test(
      'acceptance selects one quote and creates a deterministic job',
      () async {
        final repository = DemoQuoteRepository();
        final before = await repository.loadComparison('demo-request-vehicle');
        final selected = before.quotes.singleWhere(
          (quote) => quote.isRecommended,
        );

        final jobId = await repository.acceptQuote(
          selected.id,
          idempotencyKey: 'stage8-test-acceptance',
        );
        final after = await repository.loadComparison('demo-request-vehicle');

        expect(jobId, 'demo-job-demo-request-vehicle');
        expect(after.acceptedQuoteId, selected.id);
        expect(after.jobId, jobId);
        expect(
          after.quotes.singleWhere((quote) => quote.id == selected.id).status,
          QuoteStatus.accepted,
        );
        expect(
          after.quotes
              .where((quote) => quote.id != selected.id)
              .every((quote) => quote.status == QuoteStatus.rejected),
          isTrue,
        );
      },
    );

    test('expired submitted quote cannot be accepted', () {
      final quote = ProvisionalQuote.fromJson({
        'id': 'expired',
        'request_id': 'request',
        'repairer_id': 'repairer',
        'status': 'submitted',
        'expires_at': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });

      expect(quote.isExpired, isTrue);
      expect(quote.canAccept, isFalse);
    });
  });
}
