import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_dialog.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/quotes/domain/entities/quote_models.dart';
import 'package:fixbrief/features/quotes/presentation/providers/quote_providers.dart';
import 'package:fixbrief/features/quotes/presentation/widgets/provisional_warning_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class QuoteEditorScreen extends ConsumerStatefulWidget {
  const QuoteEditorScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<QuoteEditorScreen> createState() => _QuoteEditorScreenState();
}

class _QuoteEditorScreenState extends ConsumerState<QuoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _inspection = TextEditingController();
  final _callout = TextEditingController();
  final _labourMin = TextEditingController();
  final _labourMax = TextEditingController();
  final _partsMin = TextEditingController();
  final _partsMax = TextEditingController();
  final _otherMin = TextEditingController();
  final _otherMax = TextEditingController();
  final _durationHours = TextEditingController();
  final _warrantyDays = TextEditingController();
  final _comments = TextEditingController();
  final _assumptions = TextEditingController();
  final _exclusions = TextEditingController();
  late DateTime _earliest;
  late DateTime _expiry;
  var _collection = false;
  var _mobile = true;
  var _saving = false;
  String? _loadedQuoteId;
  ProvisionalQuote? _quote;

  @override
  void initState() {
    super.initState();
    _setInput(QuoteDraftInput.initial(widget.requestId));
  }

  @override
  void dispose() {
    for (final controller in [
      _inspection,
      _callout,
      _labourMin,
      _labourMax,
      _partsMin,
      _partsMax,
      _otherMin,
      _otherMax,
      _durationHours,
      _warrantyDays,
      _comments,
      _assumptions,
      _exclusions,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(repairerQuoteProvider(widget.requestId));
    existing.whenData((quote) {
      final marker = quote?.id ?? 'new';
      if (_loadedQuoteId == null && marker != _loadedQuoteId) {
        _loadedQuoteId = marker;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _quote = quote;
            if (quote != null) {
              _setInput(QuoteDraftInput.fromQuote(quote));
            }
          });
        });
      }
    });

    return Scaffold(
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: SafeArea(
          child: existing.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading provisional quote',
              ),
            ),
            error: (error, stackTrace) => _LoadError(
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(repairerQuoteProvider(widget.requestId)),
            ),
            data: (_) => _buildEditor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final quote = _quote;
    final locked = quote != null && !quote.canEdit;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 54),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EditorHeader(requestId: widget.requestId),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              quote == null
                                  ? 'Prepare a quote'
                                  : 'Your provisional quote',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          if (quote != null)
                            LiquidGlassStatusPill(
                              label: quote.status.label,
                              status: _status(quote.status),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        locked
                            ? 'This quote is locked because its lifecycle has finished.'
                            : 'Give a transparent range. You can edit it until the customer accepts a quote.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: context.glassColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const ProvisionalWarningCard(),
                      const SizedBox(height: 18),
                      AbsorbPointer(
                        absorbing: locked,
                        child: Opacity(
                          opacity: locked ? 0.72 : 1,
                          child: Column(
                            children: [
                              _PriceSection(
                                controllers: [
                                  _inspection,
                                  _callout,
                                  _labourMin,
                                  _labourMax,
                                  _partsMin,
                                  _partsMax,
                                  _otherMin,
                                  _otherMax,
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              _TotalCard(
                                minimumMinor: _currentMinimum,
                                maximumMinor: _currentMaximum,
                              ),
                              const SizedBox(height: 16),
                              _ScheduleSection(
                                earliest: _earliest,
                                expiry: _expiry,
                                durationController: _durationHours,
                                warrantyController: _warrantyDays,
                                collection: _collection,
                                mobile: _mobile,
                                onEarliest: () => _pickDate(expiry: false),
                                onExpiry: () => _pickDate(expiry: true),
                                onCollection: (value) =>
                                    setState(() => _collection = value),
                                onMobile: (value) =>
                                    setState(() => _mobile = value),
                              ),
                              const SizedBox(height: 16),
                              _ScopeSection(
                                comments: _comments,
                                assumptions: _assumptions,
                                exclusions: _exclusions,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!locked) ...[
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final save = LiquidGlassButton(
                              label: 'Save draft',
                              icon: Icons.save_outlined,
                              level: LiquidGlassButtonLevel.secondary,
                              isLoading: _saving,
                              expand: constraints.maxWidth < 620,
                              onPressed: _saving ? null : () => _save(false),
                            );
                            final submit = LiquidGlassButton(
                              label: quote?.status == QuoteStatus.submitted
                                  ? 'Save quote changes'
                                  : 'Submit provisional quote',
                              icon: Icons.send_rounded,
                              isLoading: _saving,
                              expand: constraints.maxWidth < 620,
                              onPressed: _saving ? null : () => _save(true),
                            );
                            if (constraints.maxWidth < 620) {
                              return Column(
                                children: [
                                  submit,
                                  const SizedBox(height: 10),
                                  save,
                                ],
                              );
                            }
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                save,
                                const SizedBox(width: 12),
                                submit,
                              ],
                            );
                          },
                        ),
                        if (quote != null) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: _saving ? null : _withdraw,
                              icon: const Icon(Icons.undo_rounded),
                              label: const Text('Withdraw quote'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save(bool submit) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final input = _readInput();
    if (input.labourMinimumMinor > input.labourMaximumMinor ||
        input.partsMinimumMinor > input.partsMaximumMinor ||
        input.otherChargesMinimumMinor > input.otherChargesMaximumMinor) {
      _message(
        'Each minimum must be no greater than its maximum.',
        error: true,
      );
      return;
    }
    if (!input.expiresAt.isAfter(DateTime.now())) {
      _message('Choose a future quote expiry date.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      var saved = await ref.read(quoteRepositoryProvider).saveDraft(input);
      if (submit && saved.status == QuoteStatus.draft) {
        saved = await ref.read(quoteRepositoryProvider).submitQuote(saved.id);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = saved;
        _loadedQuoteId = saved.id;
        _saving = false;
      });
      ref
        ..invalidate(repairerQuoteProvider(widget.requestId))
        ..invalidate(repairerQuotesProvider);
      _message(
        saved.status == QuoteStatus.submitted
            ? 'Provisional quote submitted. The customer can now compare it.'
            : 'Draft saved privately.',
      );
    } on QuoteFailure catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(error.message, error: true);
      }
    } on Exception catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _message('We could not save this quote. Try again.', error: true);
      }
    }
  }

  Future<void> _withdraw() async {
    final quote = _quote;
    if (quote == null) {
      return;
    }
    final confirmed = await showLiquidGlassDialog<bool>(
      context: context,
      destructive: true,
      builder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Withdraw this quote?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          const Text(
            'The customer will no longer be able to accept it. This cannot be undone.',
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep quote'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Withdraw'),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    try {
      final withdrawn = await ref
          .read(quoteRepositoryProvider)
          .withdrawQuote(quote.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _quote = withdrawn;
        _saving = false;
      });
      ref
        ..invalidate(repairerQuoteProvider(widget.requestId))
        ..invalidate(repairerQuotesProvider);
      _message('Quote withdrawn.');
    } on QuoteFailure catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message(error.message, error: true);
      }
    }
  }

  Future<void> _pickDate({required bool expiry}) async {
    final current = expiry ? _expiry : _earliest;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: expiry ? 'Quote expiry date' : 'Earliest availability',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      if (expiry) {
        _expiry = DateTime(selected.year, selected.month, selected.day, 23, 59);
      } else {
        _earliest = DateTime(selected.year, selected.month, selected.day, 9);
      }
    });
  }

  QuoteDraftInput _readInput() => QuoteDraftInput(
    requestId: widget.requestId,
    quoteId: _quote?.id,
    inspectionFeeMinor: _minor(_inspection.text),
    calloutFeeMinor: _minor(_callout.text),
    labourMinimumMinor: _minor(_labourMin.text),
    labourMaximumMinor: _minor(_labourMax.text),
    partsMinimumMinor: _minor(_partsMin.text),
    partsMaximumMinor: _minor(_partsMax.text),
    otherChargesMinimumMinor: _minor(_otherMin.text),
    otherChargesMaximumMinor: _minor(_otherMax.text),
    earliestAvailability: _earliest,
    estimatedDurationMinutes: ((double.tryParse(_durationHours.text) ?? 1) * 60)
        .round(),
    collectionAvailable: _collection,
    mobileRepairAvailable: _mobile,
    warrantyDays: int.tryParse(_warrantyDays.text) ?? 0,
    expiresAt: _expiry,
    additionalComments: _comments.text,
    assumptions: _lines(_assumptions.text),
    exclusions: _lines(_exclusions.text),
  );

  void _setInput(QuoteDraftInput input) {
    _inspection.text = _pounds(input.inspectionFeeMinor);
    _callout.text = _pounds(input.calloutFeeMinor);
    _labourMin.text = _pounds(input.labourMinimumMinor);
    _labourMax.text = _pounds(input.labourMaximumMinor);
    _partsMin.text = _pounds(input.partsMinimumMinor);
    _partsMax.text = _pounds(input.partsMaximumMinor);
    _otherMin.text = _pounds(input.otherChargesMinimumMinor);
    _otherMax.text = _pounds(input.otherChargesMaximumMinor);
    _durationHours.text = (input.estimatedDurationMinutes / 60).toStringAsFixed(
      1,
    );
    _warrantyDays.text = input.warrantyDays.toString();
    _comments.text = input.additionalComments;
    _assumptions.text = input.assumptions.join('\n');
    _exclusions.text = input.exclusions.join('\n');
    _earliest = input.earliestAvailability;
    _expiry = input.expiresAt;
    _collection = input.collectionAvailable;
    _mobile = input.mobileRepairAvailable;
  }

  int get _currentMinimum =>
      _minor(_inspection.text) +
      _minor(_callout.text) +
      _minor(_labourMin.text) +
      _minor(_partsMin.text) +
      _minor(_otherMin.text);

  int get _currentMaximum =>
      _minor(_inspection.text) +
      _minor(_callout.text) +
      _minor(_labourMax.text) +
      _minor(_partsMax.text) +
      _minor(_otherMax.text);

  void _message(String value, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(value),
          backgroundColor: error ? context.glassColors.danger : null,
        ),
      );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back to request',
          onPressed: () => context.go(AppPaths.repairerRequestFor(requestId)),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Provisional quote',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _PriceSection extends StatelessWidget {
  const _PriceSection({required this.controllers, required this.onChanged});

  final List<TextEditingController> controllers;
  final ValueChanged<String> onChanged;

  static const _labels = [
    'Inspection fee',
    'Call-out fee',
    'Labour minimum',
    'Labour maximum',
    'Parts minimum',
    'Parts maximum',
    'Other minimum',
    'Other maximum',
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimated costs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'Enter pounds and pence. Ranges make uncertainty visible.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.glassColors.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 650
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < controllers.length; index++)
                    SizedBox(
                      width: width,
                      child: LiquidGlassTextField(
                        label: '${_labels[index]} (£)',
                        controller: controllers[index],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        prefixIcon: Icons.currency_pound_rounded,
                        onChanged: onChanged,
                        validator: _moneyValidator,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.minimumMinor, required this.maximumMinor});

  final int minimumMinor;
  final int maximumMinor;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.coolBlue,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(
            Icons.calculate_outlined,
            color: LiquidGlassColors.coolBlue,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live estimated total',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_money(minimumMinor)}–${_money(maximumMinor)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.earliest,
    required this.expiry,
    required this.durationController,
    required this.warrantyController,
    required this.collection,
    required this.mobile,
    required this.onEarliest,
    required this.onExpiry,
    required this.onCollection,
    required this.onMobile,
  });

  final DateTime earliest;
  final DateTime expiry;
  final TextEditingController durationController;
  final TextEditingController warrantyController;
  final bool collection;
  final bool mobile;
  final VoidCallback onEarliest;
  final VoidCallback onExpiry;
  final ValueChanged<bool> onCollection;
  final ValueChanged<bool> onMobile;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability and cover',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 15),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 650
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _DateButton(
                      label: 'Earliest availability',
                      date: earliest,
                      onTap: onEarliest,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _DateButton(
                      label: 'Quote expires',
                      date: expiry,
                      onTap: onExpiry,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: LiquidGlassTextField(
                      label: 'Estimated duration (hours)',
                      controller: durationController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: Icons.schedule_rounded,
                      validator: _positiveValidator,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: LiquidGlassTextField(
                      label: 'Warranty period (days)',
                      controller: warrantyController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.verified_user_outlined,
                      validator: _wholeNumberValidator,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mobile repair available'),
            subtitle: const Text(
              'You can attend the customer’s approximate area',
            ),
            value: mobile,
            onChanged: onMobile,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Collection available'),
            subtitle: const Text('You can collect and return the item'),
            value: collection,
            onChanged: onCollection,
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_outlined),
      label: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            Text(DateFormat('EEE, d MMM yyyy').format(date)),
          ],
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(62),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.comments,
    required this.assumptions,
    required this.exclusions,
  });

  final TextEditingController comments;
  final TextEditingController assumptions;
  final TextEditingController exclusions;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scope and conditions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 15),
          LiquidGlassTextField(
            label: 'Additional comments',
            controller: comments,
            maxLines: 4,
            maxLength: 5000,
            hintText: 'Explain what the estimate covers.',
          ),
          const SizedBox(height: 12),
          LiquidGlassTextField(
            label: 'Assumptions (one per line)',
            controller: assumptions,
            maxLines: 4,
            hintText: 'Evidence matches the reported symptom',
          ),
          const SizedBox(height: 12),
          LiquidGlassTextField(
            label: 'Exclusions (one per line)',
            controller: exclusions,
            maxLines: 4,
            hintText: 'Unrelated damage or additional parts',
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LiquidGlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              LiquidGlassButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

LiquidGlassStatus _status(QuoteStatus status) => switch (status) {
  QuoteStatus.accepted => LiquidGlassStatus.success,
  QuoteStatus.expired ||
  QuoteStatus.withdrawn ||
  QuoteStatus.rejected => LiquidGlassStatus.warning,
  QuoteStatus.draft || QuoteStatus.submitted => LiquidGlassStatus.info,
};

String? _moneyValidator(String? value) {
  final amount = double.tryParse(value?.trim() ?? '');
  if (amount == null || amount < 0) {
    return 'Enter a valid non-negative amount';
  }
  if (amount > 1000000) {
    return 'Amount is too large';
  }
  return null;
}

String? _positiveValidator(String? value) {
  final amount = double.tryParse(value?.trim() ?? '');
  return amount == null || amount <= 0
      ? 'Enter a duration greater than zero'
      : null;
}

String? _wholeNumberValidator(String? value) {
  final amount = int.tryParse(value?.trim() ?? '');
  return amount == null || amount < 0 || amount > 3650
      ? 'Enter 0–3650 days'
      : null;
}

int _minor(String text) => ((double.tryParse(text.trim()) ?? 0) * 100).round();
String _pounds(int minor) => (minor / 100).toStringAsFixed(2);
String _money(int minor) => NumberFormat.simpleCurrency(
  locale: 'en_GB',
  decimalDigits: minor % 100 == 0 ? 0 : 2,
).format(minor / 100);

List<String> _lines(String value) => value
    .split(RegExp(r'[\n,]'))
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .take(12)
    .toList(growable: false);
