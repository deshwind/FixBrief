import 'dart:async';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_bottom_sheet.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_search_bar.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/repairer_marketplace/domain/entities/marketplace_models.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/controllers/repairer_marketplace_state.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/providers/repairer_marketplace_providers.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/marketplace_request_card.dart';
import 'package:fixbrief/features/repairer_marketplace/presentation/widgets/repairer_marketplace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MatchingRequestsScreen extends ConsumerStatefulWidget {
  const MatchingRequestsScreen({super.key});

  @override
  ConsumerState<MatchingRequestsScreen> createState() =>
      _MatchingRequestsScreenState();
}

class _MatchingRequestsScreenState
    extends ConsumerState<MatchingRequestsScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(
        repairerMarketplaceControllerProvider.notifier,
      );
      _searchController.text = ref
          .read(repairerMarketplaceControllerProvider)
          .filters
          .search;
      unawaited(controller.loadMatches());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(repairerMarketplaceControllerProvider);
    final controller = ref.read(repairerMarketplaceControllerProvider.notifier);
    return Scaffold(
      extendBody: true,
      body: FluidBackground(
        accent: LiquidGlassColors.industrial,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => controller.loadMatches(refresh: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _RequestsHeader(),
                                const SizedBox(height: 26),
                                Text(
                                  'Matching requests',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Ranked using your verified services, area, availability and marketplace performance.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color:
                                            context.glassColors.secondaryText,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                LiquidGlassSearchBar(
                                  controller: _searchController,
                                  hintText:
                                      'Search item, problem, category or area',
                                  onChanged: controller.setSearch,
                                  onClear: _searchController.text.isEmpty
                                      ? null
                                      : () {
                                          _searchController.clear();
                                          controller.setSearch('');
                                          setState(() {});
                                        },
                                ),
                                const SizedBox(height: 13),
                                _FilterToolbar(
                                  state: state,
                                  onFilters: () => _openFilters(state),
                                  onSort: controller.setSort,
                                  onClear: () {
                                    _searchController.clear();
                                    unawaited(controller.clearFilters());
                                  },
                                ),
                                if (state.errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  _ErrorNotice(
                                    message: state.errorMessage!,
                                    onRetry: controller.loadMatches,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                _ResultsHeader(state: state),
                                const SizedBox(height: 14),
                                if (state.phase ==
                                        RepairerMarketplacePhase.loading &&
                                    state.matches.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 64),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        semanticsLabel:
                                            'Loading matching requests',
                                      ),
                                    ),
                                  )
                                else if (state.matches.isEmpty)
                                  _EmptyResults(
                                    filtered: state.filters.isFiltered,
                                    onClear: () {
                                      _searchController.clear();
                                      unawaited(controller.clearFilters());
                                    },
                                  )
                                else
                                  ...state.matches.indexed.expand(
                                    (entry) => [
                                      MarketplaceRequestCard(
                                        request: entry.$2,
                                        onTap: () => context.go(
                                          AppPaths.repairerRequestFor(
                                            entry.$2.id,
                                          ),
                                        ),
                                      ),
                                      if (entry.$1 != state.matches.length - 1)
                                        const SizedBox(height: 14),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const RepairerMarketplaceNavigation(selectedIndex: 1),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilters(RepairerMarketplaceState state) async {
    final categories = <String, String>{
      for (final request in state.matches)
        request.categoryId: request.categoryName,
    };
    final selectedCategory = state.filters.categoryId;
    if (selectedCategory != null && !categories.containsKey(selectedCategory)) {
      categories[selectedCategory] = 'Selected category';
    }
    final filters = await showLiquidGlassBottomSheet<MarketplaceFilters>(
      context: context,
      builder: (context) =>
          _RequestFiltersSheet(initial: state.filters, categories: categories),
    );
    if (filters == null || !mounted) {
      return;
    }
    _searchController.text = filters.search;
    await ref
        .read(repairerMarketplaceControllerProvider.notifier)
        .applyFilters(filters);
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Back to dashboard',
          onPressed: () => context.go(AppPaths.repairerDashboard),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'FixBrief Marketplace',
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

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.state,
    required this.onFilters,
    required this.onSort,
    required this.onClear,
  });

  final RepairerMarketplaceState state;
  final VoidCallback onFilters;
  final ValueChanged<MarketplaceSort> onSort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filterCount = _filterCount(state.filters);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LiquidGlassChip(
          label: filterCount == 0 ? 'Filters' : 'Filters · $filterCount',
          icon: Icons.tune_rounded,
          selected: filterCount > 0,
          onSelected: (_) => onFilters(),
        ),
        PopupMenuButton<MarketplaceSort>(
          tooltip: 'Sort requests',
          onSelected: onSort,
          itemBuilder: (context) => [
            for (final sort in MarketplaceSort.values)
              PopupMenuItem(value: sort, child: Text(sort.label)),
          ],
          child: LiquidGlassChip(
            label: state.filters.sort.label,
            icon: Icons.swap_vert_rounded,
            selected: state.filters.sort != MarketplaceSort.bestMatch,
          ),
        ),
        if (state.filters.isFiltered)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Clear'),
          ),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({required this.state});

  final RepairerMarketplaceState state;

  @override
  Widget build(BuildContext context) {
    final total = state.matches.isEmpty
        ? 0
        : state.matches.first.totalCount > 0
        ? state.matches.first.totalCount
        : state.matches.length;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$total ${total == 1 ? 'request' : 'requests'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        if (state.isRefreshing)
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Refreshing requests',
            ),
          ),
      ],
    );
  }
}

class _RequestFiltersSheet extends StatefulWidget {
  const _RequestFiltersSheet({required this.initial, required this.categories});

  final MarketplaceFilters initial;
  final Map<String, String> categories;

  @override
  State<_RequestFiltersSheet> createState() => _RequestFiltersSheetState();
}

class _RequestFiltersSheetState extends State<_RequestFiltersSheet> {
  late MarketplaceFilters _filters = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Request filters',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Only requests inside your verified services and service area are eligible.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.glassColors.secondaryText,
            ),
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 9),
            DropdownButtonFormField<String?>(
              initialValue: _filters.categoryId,
              decoration: const InputDecoration(labelText: 'Repair category'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All eligible categories'),
                ),
                ...widget.categories.entries.map(
                  (entry) => DropdownMenuItem<String?>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) => setState(() {
                _filters = _filters.copyWith(
                  categoryId: value,
                  clearCategory: value == null,
                );
              }),
            ),
          ],
          const SizedBox(height: 22),
          Text('Urgency', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LiquidGlassChip(
                label: 'Any urgency',
                selected: _filters.urgency == null,
                onSelected: (_) => setState(() {
                  _filters = _filters.copyWith(clearUrgency: true);
                }),
              ),
              for (final urgency in MarketplaceUrgency.values)
                LiquidGlassChip(
                  label: urgency.label,
                  selected: _filters.urgency == urgency,
                  onSelected: (_) => setState(() {
                    _filters = _filters.copyWith(urgency: urgency);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('Distance', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final distance in <double?>[null, 5, 10, 25])
                LiquidGlassChip(
                  label: distance == null
                      ? 'Any distance'
                      : 'Within ${distance.round()} km',
                  selected: _filters.maximumDistanceKilometres == distance,
                  onSelected: (_) => setState(() {
                    _filters = _filters.copyWith(
                      maximumDistanceKilometres: distance,
                      clearMaximumDistance: distance == null,
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mobile repair requested'),
            subtitle: const Text(
              'Show requests requiring work at the customer area',
            ),
            value: _filters.mobileOnly,
            onChanged: (value) => setState(() {
              _filters = _filters.copyWith(mobileOnly: value);
            }),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Collection requested'),
            subtitle: const Text('Show requests requiring collection service'),
            value: _filters.collectionOnly,
            onChanged: (value) => setState(() {
              _filters = _filters.copyWith(collectionOnly: value);
            }),
          ),
          const SizedBox(height: 18),
          LiquidGlassButton(
            label: 'Apply filters',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: () => Navigator.of(context).pop(_filters),
          ),
          const SizedBox(height: 8),
          LiquidGlassButton(
            label: 'Reset filters',
            level: LiquidGlassButtonLevel.plain,
            expand: true,
            onPressed: () => setState(() {
              _filters = MarketplaceFilters(search: _filters.search);
            }),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      tint: LiquidGlassColors.amber,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.filtered, required this.onClear});

  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 42),
          const SizedBox(height: 14),
          Text(
            filtered ? 'No requests match these filters' : 'No new matches',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            filtered
                ? 'Clear or widen the filters. Your verified service eligibility still applies.'
                : 'New published requests will appear when they match your services, availability and area.',
            textAlign: TextAlign.center,
          ),
          if (filtered) ...[
            const SizedBox(height: 18),
            LiquidGlassButton(
              label: 'Clear filters',
              onPressed: onClear,
              level: LiquidGlassButtonLevel.secondary,
            ),
          ],
        ],
      ),
    );
  }
}

int _filterCount(MarketplaceFilters filters) {
  return <bool>[
    filters.search.trim().isNotEmpty,
    filters.categoryId != null,
    filters.urgency != null,
    filters.maximumDistanceKilometres != null,
    filters.mobileOnly,
    filters.collectionOnly,
  ].where((value) => value).length;
}
