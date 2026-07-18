import 'dart:async';
import 'dart:io';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_category.dart';
import 'package:fixbrief/features/repair_requests/domain/entities/repair_request_draft.dart';
import 'package:fixbrief/features/repair_requests/presentation/controllers/repair_request_wizard_controller.dart';
import 'package:fixbrief/features/repair_requests/presentation/controllers/repair_request_wizard_state.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:fixbrief/features/repair_requests/presentation/widgets/draft_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

enum RepairWizardStep {
  category('Category', 'What needs fixing?'),
  item('Item', 'Tell us about the item'),
  problem('Problem', 'Describe what is happening'),
  evidence('Evidence', 'Add useful evidence'),
  review('Review', 'Check your repair brief'),
  publish('Submit', 'Availability and location');

  const RepairWizardStep(this.shortLabel, this.title);
  final String shortLabel;
  final String title;
}

class RepairRequestWizardScreen extends ConsumerStatefulWidget {
  const RepairRequestWizardScreen({required this.step, super.key});

  final RepairWizardStep step;

  @override
  ConsumerState<RepairRequestWizardScreen> createState() =>
      _RepairRequestWizardScreenState();
}

class _RepairRequestWizardScreenState
    extends ConsumerState<RepairRequestWizardScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<RepairRequestWizardState>(
      repairRequestWizardControllerProvider,
      (previous, next) {
        final feedback = next.errorMessage ?? next.noticeMessage;
        final previousFeedback =
            previous?.errorMessage ?? previous?.noticeMessage;
        if (feedback != null && feedback != previousFeedback) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(feedback)));
        }
      },
    );

    final state = ref.watch(repairRequestWizardControllerProvider);
    final controller = ref.read(repairRequestWizardControllerProvider.notifier);
    final draft = state.draft;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_goBack(controller));
        }
      },
      child: Scaffold(
        body: FluidBackground(
          child: SafeArea(
            child: state.isLoading || draft == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _WizardHeader(
                        step: widget.step,
                        isOnline: state.isOnline,
                        isSaving: state.isSaving,
                        onClose: () async {
                          await controller.finishActiveInput();
                          await controller.saveNow();
                          if (context.mounted) {
                            context.go(AppPaths.customerHome);
                          }
                        },
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: _StepContent(
                                step: widget.step,
                                draft: draft,
                                state: state,
                                controller: controller,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _WizardActions(
                        step: widget.step,
                        state: state,
                        onBack: () => unawaited(_goBack(controller)),
                        onNext: () => unawaited(_goNext(controller)),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _goBack(RepairRequestWizardController controller) async {
    await controller.finishActiveInput();
    await controller.saveNow();
    if (!mounted) {
      return;
    }
    final index = widget.step.index;
    if (index == 0) {
      context.go(AppPaths.customerHome);
      return;
    }
    await controller.setCurrentStep(index - 1);
    if (mounted) {
      context.go(AppPaths.repairRequestStep(index - 1));
    }
  }

  Future<void> _goNext(RepairRequestWizardController controller) async {
    await controller.finishActiveInput();
    final index = widget.step.index;
    if (controller.validateStep(index) != null) {
      return;
    }
    if (widget.step == RepairWizardStep.publish) {
      final submitted = await controller.submit();
      if (submitted && mounted) {
        context.go(AppPaths.repairRequestConfirmation);
      }
      return;
    }
    await controller.setCurrentStep(index + 1);
    if (mounted) {
      context.go(AppPaths.repairRequestStep(index + 1));
    }
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.isOnline,
    required this.isSaving,
    required this.onClose,
  });

  final RepairWizardStep step;
  final bool isOnline;
  final bool isSaving;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Save and close',
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        step.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Icon(
                        isSaving
                            ? Icons.sync_rounded
                            : Icons.cloud_done_outlined,
                        semanticLabel: isSaving
                            ? 'Saving draft'
                            : 'Draft saved',
                      ),
                    ),
                  ],
                ),
                if (!isOnline)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: context.glassColors.warningSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Offline — text is saved here; uploads and submission need internet.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                  child: Row(
                    children: [
                      for (
                        var index = 0;
                        index < RepairWizardStep.values.length;
                        index++
                      ) ...[
                        Expanded(
                          child: Semantics(
                            label:
                                '${RepairWizardStep.values[index].shortLabel}, step ${index + 1} of 6',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: index <= step.index
                                    ? Theme.of(context).colorScheme.primary
                                    : context.glassColors.glassBorder,
                              ),
                            ),
                          ),
                        ),
                        if (index != 5) const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WizardActions extends StatelessWidget {
  const _WizardActions({
    required this.step,
    required this.state,
    required this.onBack,
    required this.onNext,
  });

  final RepairWizardStep step;
  final RepairRequestWizardState state;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .94),
          border: Border(
            top: BorderSide(color: context.glassColors.glassBorder),
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              children: [
                Expanded(
                  child: LiquidGlassButton(
                    label: step == RepairWizardStep.category
                        ? 'Save & exit'
                        : 'Back',
                    level: LiquidGlassButtonLevel.secondary,
                    onPressed: state.isSubmitting ? null : onBack,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: LiquidGlassButton(
                    key: const Key('repair-wizard-next'),
                    label: step == RepairWizardStep.publish
                        ? 'Submit for assessment'
                        : step == RepairWizardStep.review
                        ? 'Add availability'
                        : 'Continue',
                    icon: step == RepairWizardStep.publish
                        ? Icons.send_rounded
                        : Icons.arrow_forward_rounded,
                    isLoading: state.isSubmitting,
                    onPressed: state.isSubmitting ? null : onNext,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.step,
    required this.draft,
    required this.state,
    required this.controller,
  });

  final RepairWizardStep step;
  final RepairRequestDraft draft;
  final RepairRequestWizardState state;
  final RepairRequestWizardController controller;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      RepairWizardStep.category => _CategoryStep(
        draft: draft,
        controller: controller,
      ),
      RepairWizardStep.item => _ItemStep(draft: draft, controller: controller),
      RepairWizardStep.problem => _ProblemStep(
        draft: draft,
        state: state,
        controller: controller,
      ),
      RepairWizardStep.evidence => _EvidenceStep(
        draft: draft,
        state: state,
        controller: controller,
      ),
      RepairWizardStep.review => _ReviewStep(draft: draft),
      RepairWizardStep.publish => _PublishStep(
        draft: draft,
        controller: controller,
      ),
    };
  }
}

class _CategoryStep extends StatefulWidget {
  const _CategoryStep({required this.draft, required this.controller});

  final RepairRequestDraft draft;
  final RepairRequestWizardController controller;

  @override
  State<_CategoryStep> createState() => _CategoryStepState();
}

class _CategoryStepState extends State<_CategoryStep> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final categories = RepairCategoryCatalogue.categories
        .where(
          (item) => item.label.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose the closest category',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'This helps us ask relevant questions. You can change it later.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 22),
        DraftTextField(
          label: 'Search categories',
          value: _query,
          prefixIcon: Icons.search_rounded,
          onChanged: (value) => setState(() => _query = value),
        ),
        if (_query.isEmpty) ...[
          const SizedBox(height: 24),
          Text('Recently used', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category in RepairCategoryCatalogue.categories.where(
                (item) => item.slug == 'appliances' || item.slug == 'vehicles',
              ))
                ActionChip(
                  avatar: Icon(category.icon, size: 18),
                  label: Text(category.label),
                  onPressed: () => widget.controller.selectCategory(category),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Suggested', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final category
                  in RepairCategoryCatalogue.categories.skip(2).take(3))
                ActionChip(
                  avatar: Icon(category.icon, size: 18),
                  label: Text(category.label),
                  onPressed: () => widget.controller.selectCategory(category),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 720
                ? 3
                : constraints.maxWidth >= 460
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 3.25 : 1.65,
              ),
              itemBuilder: (context, index) {
                final category = categories[index];
                final selected = widget.draft.categorySlug == category.slug;
                return LiquidGlassCard(
                  key: Key('category-${category.slug}'),
                  semanticLabel:
                      '${category.label} category${selected ? ', selected' : ''}',
                  tint: selected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .3)
                      : null,
                  onTap: () => widget.controller.selectCategory(category),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        category.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 13),
                      Expanded(child: Text(category.label)),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (widget.draft.categorySlug == 'other') ...[
          const SizedBox(height: 18),
          DraftTextField(
            label: 'What type of repair is it?',
            value: widget.draft.customCategory ?? '',
            maxLength: 120,
            onChanged: (value) => widget.controller.update(
              (draft) => draft.copyWith(customCategory: value),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemStep extends StatelessWidget {
  const _ItemStep({required this.draft, required this.controller});

  final RepairRequestDraft draft;
  final RepairRequestWizardController controller;

  @override
  Widget build(BuildContext context) {
    final category = RepairCategoryCatalogue.bySlug(draft.categorySlug);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIntro(
          title: 'Identify the item',
          body:
              'Only the item name is essential. Extra details help repairers quote accurately.',
        ),
        _SectionCard(
          title: 'Basics',
          children: [
            _ResponsiveFields(
              children: [
                DraftTextField(
                  key: const Key('item-name'),
                  label: 'Item name *',
                  value: draft.itemName,
                  hintText: 'e.g. washing machine',
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(itemName: value),
                  ),
                ),
                _GlassDropdown<String>(
                  label: 'Subcategory',
                  value: draft.subcategory,
                  items: category?.subcategories ?? const <String>[],
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(subcategory: value),
                  ),
                ),
                DraftTextField(
                  label: 'Brand',
                  value: draft.brand,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(brand: value),
                  ),
                ),
                DraftTextField(
                  label: 'Model',
                  value: draft.model,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(model: value),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (draft.isVehicle)
          _VehicleFields(draft: draft, controller: controller),
        _SectionCard(
          title: 'Useful details',
          children: [
            _ResponsiveFields(
              children: [
                DraftTextField(
                  label: 'Approximate age in years',
                  value: draft.approximateAgeYears?.toString() ?? '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      approximateAgeYears: double.tryParse(value),
                      clearAge: value.trim().isEmpty,
                    ),
                  ),
                ),
                DraftTextField(
                  label: 'Serial number',
                  value: draft.serialNumber,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(serialNumber: value),
                  ),
                ),
                _DateField(
                  label: 'Purchase date',
                  value: draft.purchaseDate,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      purchaseDate: value,
                      clearPurchaseDate: value == null,
                    ),
                  ),
                ),
                _GlassDropdown<String>(
                  label: 'Warranty status',
                  value: draft.warrantyStatus.isEmpty
                      ? null
                      : draft.warrantyStatus,
                  items: const ['In warranty', 'Out of warranty', 'Not sure'],
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(warrantyStatus: value ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DraftTextField(
              label: 'Previous repairs',
              value: draft.previousRepairs,
              maxLines: 3,
              maxLength: 1000,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(previousRepairs: value),
              ),
            ),
            const SizedBox(height: 14),
            DraftTextField(
              label: 'Where is the item?',
              hintText: 'e.g. utility room, driveway, workshop',
              value: draft.itemLocation,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(itemLocation: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleFields extends StatelessWidget {
  const _VehicleFields({required this.draft, required this.controller});

  final RepairRequestDraft draft;
  final RepairRequestWizardController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Vehicle details',
      children: [
        _ResponsiveFields(
          children: [
            DraftTextField(
              label: 'Registration *',
              value: draft.vehicleRegistration,
              textInputAction: TextInputAction.next,
              onChanged: (value) => controller.update(
                (draft) =>
                    draft.copyWith(vehicleRegistration: value.toUpperCase()),
              ),
            ),
            DraftTextField(
              label: 'Make',
              value: draft.vehicleMake,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(vehicleMake: value),
              ),
            ),
            DraftTextField(
              label: 'Vehicle model',
              value: draft.vehicleModel,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(vehicleModel: value),
              ),
            ),
            DraftTextField(
              label: 'Year',
              value: draft.vehicleYear?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(
                  vehicleYear: int.tryParse(value),
                  clearVehicleYear: value.trim().isEmpty,
                ),
              ),
            ),
            DraftTextField(
              label: 'Mileage',
              value: draft.vehicleMileage?.toString() ?? '',
              keyboardType: TextInputType.number,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(
                  vehicleMileage: int.tryParse(value),
                  clearVehicleMileage: value.trim().isEmpty,
                ),
              ),
            ),
            _GlassDropdown<String>(
              label: 'Fuel type',
              value: draft.vehicleFuelType.isEmpty
                  ? null
                  : draft.vehicleFuelType,
              items: const ['Petrol', 'Diesel', 'Electric', 'Hybrid', 'Other'],
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(vehicleFuelType: value ?? ''),
              ),
            ),
            _GlassDropdown<String>(
              label: 'Transmission',
              value: draft.vehicleTransmission.isEmpty
                  ? null
                  : draft.vehicleTransmission,
              items: const ['Manual', 'Automatic', 'Other'],
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(vehicleTransmission: value ?? ''),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProblemStep extends StatefulWidget {
  const _ProblemStep({
    required this.draft,
    required this.state,
    required this.controller,
  });

  final RepairRequestDraft draft;
  final RepairRequestWizardState state;
  final RepairRequestWizardController controller;

  @override
  State<_ProblemStep> createState() => _ProblemStepState();
}

class _ProblemStepState extends State<_ProblemStep> {
  var _kind = SymptomKind.other;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions =
        RepairCategoryCatalogue.bySlug(
          widget.draft.categorySlug,
        )?.suggestedSymptoms ??
        const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Describe it in your own words',
          body:
              'Say what you see, hear, feel or smell. Include warning lights, timing, and what changed.',
        ),
        _SectionCard(
          title: 'Problem description',
          children: [
            DraftTextField(
              key: const Key('problem-description'),
              label: 'What is happening?',
              value: widget.draft.problemDescription,
              hintText:
                  'Example: It makes a loud knocking sound during the spin cycle and has become worse this week.',
              maxLines: 7,
              maxLength: 10000,
              onVoiceInput: widget.controller.toggleSpeechInput,
              suffixIcon: Icon(
                widget.state.isListening
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_none_rounded,
              ),
              onChanged: (value) => widget.controller.update(
                (draft) => draft.copyWith(problemDescription: value),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LiquidGlassButton(
                    label: widget.state.isListening
                        ? 'Stop voice-to-text'
                        : 'Speak description',
                    icon: widget.state.isListening
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_rounded,
                    level: LiquidGlassButtonLevel.secondary,
                    onPressed: widget.controller.toggleSpeechInput,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LiquidGlassButton(
                    label: widget.state.isRecording
                        ? 'Stop recording'
                        : 'Record audio note',
                    icon: widget.state.isRecording
                        ? Icons.stop_rounded
                        : Icons.fiber_manual_record_rounded,
                    level: LiquidGlassButtonLevel.secondary,
                    onPressed: widget.controller.toggleAudioRecording,
                  ),
                ),
              ],
            ),
            if (widget.state.isRecording) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                semanticsLabel: 'Audio recording in progress',
              ),
              const SizedBox(height: 6),
              const Text('Recording privately on this device…'),
            ],
          ],
        ),
        _SectionCard(
          title: 'Suggested symptoms',
          children: [
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final suggestion in suggestions)
                  FilterChip(
                    label: Text(suggestion),
                    selected: widget.draft.symptoms.any(
                      (item) =>
                          item.source == SymptomSource.suggested &&
                          item.description == suggestion,
                    ),
                    onSelected: (_) =>
                        widget.controller.toggleSuggestedSymptom(suggestion),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 150,
                  child: _GlassDropdown<SymptomKind>(
                    label: 'Type',
                    value: _kind,
                    items: SymptomKind.values,
                    labelFor: (item) => item.label,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _kind = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customController,
                    decoration: const InputDecoration(
                      labelText: 'Add your own symptom',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Add symptom',
                  onPressed: () {
                    widget.controller.addTypedSymptom(
                      _kind,
                      _customController.text,
                    );
                    _customController.clear();
                  },
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (widget.draft.symptoms.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final symptom in widget.draft.symptoms)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline_rounded),
                  title: Text(symptom.description),
                  subtitle: Text(symptom.kind.label),
                  trailing: IconButton(
                    tooltip: 'Remove ${symptom.description}',
                    onPressed: () =>
                        widget.controller.removeSymptom(symptom.id),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
          ],
        ),
        _SectionCard(
          title: 'When and how it happens',
          children: [
            _ResponsiveFields(
              children: [
                DraftTextField(
                  label: 'When did it start?',
                  value: widget.draft.problemStarted,
                  hintText: 'e.g. yesterday, after a service',
                  onChanged: (value) => widget.controller.update(
                    (draft) => draft.copyWith(problemStarted: value),
                  ),
                ),
                _GlassDropdown<String>(
                  label: 'How often?',
                  value: widget.draft.problemOccurrence.isEmpty
                      ? null
                      : widget.draft.problemOccurrence,
                  items: const [
                    'Constant',
                    'Intermittent',
                    'Only at startup',
                    'Under load',
                    'Not sure',
                  ],
                  onChanged: (value) => widget.controller.update(
                    (draft) => draft.copyWith(problemOccurrence: value ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DraftTextField(
              label: 'What happened immediately before it started?',
              value: widget.draft.immediatePriorEvent,
              maxLines: 3,
              onChanged: (value) => widget.controller.update(
                (draft) => draft.copyWith(immediatePriorEvent: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('The problem is getting worse'),
              value: widget.draft.isWorsening,
              onChanged: (value) => widget.controller.update(
                (draft) => draft.copyWith(isWorsening: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('The item is still usable'),
              value: widget.draft.isStillUsable,
              onChanged: (value) => widget.controller.update(
                (draft) => draft.copyWith(isStillUsable: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EvidenceStep extends StatelessWidget {
  const _EvidenceStep({
    required this.draft,
    required this.state,
    required this.controller,
  });

  final RepairRequestDraft draft;
  final RepairRequestWizardState state;
  final RepairRequestWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Show repairers what you can',
          body:
              'Evidence is private. It is shared only with eligible repairers after assessment and can be deleted before submission.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _EvidenceAction(
              label: 'Photos (${draft.imageCount}/8)',
              icon: Icons.add_photo_alternate_outlined,
              onTap: controller.pickPhotos,
            ),
            _EvidenceAction(
              label: 'Video (${draft.videoCount}/2)',
              icon: Icons.video_library_outlined,
              onTap: controller.pickVideo,
            ),
            _EvidenceAction(
              label: 'Audio (${draft.audioCount}/3)',
              icon: state.isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.mic_none_rounded,
              onTap: controller.toggleAudioRecording,
            ),
            _EvidenceAction(
              label: 'Error code',
              icon: Icons.warning_amber_rounded,
              onTap: () =>
                  controller.pickDocument(RepairEvidenceKind.errorCode),
            ),
            _EvidenceAction(
              label: 'Receipt',
              icon: Icons.receipt_long_outlined,
              onTap: () => controller.pickDocument(RepairEvidenceKind.receipt),
            ),
            _EvidenceAction(
              label: 'Warranty',
              icon: Icons.verified_user_outlined,
              onTap: () => controller.pickDocument(RepairEvidenceKind.warranty),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Photos are resized for upload. Limits: images 12 MB, video 100 MB, audio 25 MB, documents 15 MB.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 22),
        if (draft.evidence.isEmpty)
          LiquidGlassCard(
            padding: const EdgeInsets.all(28),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 38),
                  SizedBox(height: 10),
                  Text('No evidence added — this step is optional.'),
                ],
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  '${draft.evidence.length} files',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Text('Drag to reorder'),
            ],
          ),
          const SizedBox(height: 10),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: draft.evidence.length,
            onReorderItem: controller.reorderEvidence,
            itemBuilder: (context, index) {
              final evidence = draft.evidence[index];
              return Padding(
                key: ValueKey(evidence.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      _EvidencePreview(evidence: evidence),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              evidence.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${evidence.kind.label} · ${_formatBytes(evidence.byteSize)} · ${_uploadLabel(evidence.uploadStatus)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (evidence.failureReason != null)
                              Text(
                                evidence.failureReason!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (evidence.uploadStatus == EvidenceUploadStatus.failed)
                        IconButton(
                          tooltip: 'Retry upload',
                          onPressed: () =>
                              controller.retryEvidence(evidence.id),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      IconButton(
                        tooltip: 'Delete ${evidence.filename}',
                        onPressed: () => controller.removeEvidence(evidence.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.drag_handle_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  static String _uploadLabel(EvidenceUploadStatus status) => switch (status) {
    EvidenceUploadStatus.local => 'saved on device',
    EvidenceUploadStatus.pending => 'queued',
    EvidenceUploadStatus.uploading => 'uploading',
    EvidenceUploadStatus.ready => 'uploaded',
    EvidenceUploadStatus.failed => 'failed',
  };
}

class _EvidencePreview extends StatelessWidget {
  const _EvidencePreview({required this.evidence});

  final RepairEvidence evidence;

  @override
  Widget build(BuildContext context) {
    final file = File(evidence.localPath);
    if (evidence.isImage && file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          file,
          width: 58,
          height: 58,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _icon(),
        ),
      );
    }
    return _icon();
  }

  Widget _icon() {
    final icon = evidence.isVideo
        ? Icons.videocam_outlined
        : evidence.isAudio
        ? Icons.audio_file_outlined
        : Icons.description_outlined;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: LiquidGlassColors.coolBlue.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon),
    );
  }
}

class _EvidenceAction extends StatelessWidget {
  const _EvidenceAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 19),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.draft});

  final RepairRequestDraft draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Your repair brief',
          body:
              'Check the facts before adding availability. You can return to any section without losing changes.',
        ),
        _ReviewCard(
          title: 'Category',
          step: 0,
          lines: [
            draft.categoryLabel ?? 'Not selected',
            if (draft.subcategory != null) draft.subcategory!,
          ],
        ),
        _ReviewCard(
          title: 'Item details',
          step: 1,
          lines: [
            draft.itemName,
            [
              draft.brand,
              draft.model,
            ].where((item) => item.isNotEmpty).join(' '),
            if (draft.isVehicle && draft.vehicleRegistration.isNotEmpty)
              'Registration ${draft.vehicleRegistration}',
            if (draft.previousRepairs.isNotEmpty)
              'Previous repairs: ${draft.previousRepairs}',
          ],
        ),
        _ReviewCard(
          title: 'Problem and symptoms',
          step: 2,
          lines: [
            if (draft.problemDescription.isNotEmpty) draft.problemDescription,
            for (final symptom in draft.symptoms) '• ${symptom.description}',
            if (draft.problemStarted.isNotEmpty)
              'Started: ${draft.problemStarted}',
            if (draft.problemOccurrence.isNotEmpty)
              'Frequency: ${draft.problemOccurrence}',
          ],
        ),
        _ReviewCard(
          title: 'Private evidence',
          step: 3,
          lines: [
            '${draft.imageCount} images, ${draft.videoCount} videos, ${draft.audioCount} audio files',
            '${draft.evidence.length} files total',
          ],
        ),
        LiquidGlassCard(
          padding: const EdgeInsets.all(18),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'After submission, this request will wait for the Stage 6 assessment and follow-up flow before it is published to repairers.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.title,
    required this.step,
    required this.lines,
  });

  final String title;
  final int step;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final visible = lines.where((line) => line.trim().isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => context.go(AppPaths.repairRequestStep(step)),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
            for (final line in visible) ...[
              const SizedBox(height: 6),
              Text(line),
            ],
          ],
        ),
      ),
    );
  }
}

class _PublishStep extends StatelessWidget {
  const _PublishStep({required this.draft, required this.controller});

  final RepairRequestDraft draft;
  final RepairRequestWizardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'When and where?',
          body:
              'Your exact address stays private. Repairers see only the town or postcode area until access is authorised.',
        ),
        _SectionCard(
          title: 'Timing and urgency',
          children: [
            _ResponsiveFields(
              children: [
                _DateField(
                  label: 'Preferred date',
                  value: draft.preferredRepairDate,
                  firstDate: DateTime.now(),
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      preferredRepairDate: value,
                      clearPreferredDate: value == null,
                    ),
                  ),
                ),
                _TimeField(
                  label: 'From',
                  value: draft.preferredTimeStart,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      preferredTimeStart: value,
                      clearPreferredTimeStart: value == null,
                    ),
                  ),
                ),
                _TimeField(
                  label: 'Until',
                  value: draft.preferredTimeEnd,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      preferredTimeEnd: value,
                      clearPreferredTimeEnd: value == null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GlassDropdown<RepairUrgency>(
              label: 'Urgency',
              value: draft.urgency,
              items: RepairUrgency.values,
              labelFor: (item) => item.label,
              onChanged: (value) {
                if (value != null) {
                  controller.update((draft) => draft.copyWith(urgency: value));
                }
              },
            ),
            if (draft.urgency == RepairUrgency.emergency) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.glassColors.warningSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'If there is immediate danger, fire, gas, flooding, or a medical risk, stop using the item and contact the emergency services or the appropriate emergency provider.',
                ),
              ),
            ],
          ],
        ),
        _SectionCard(
          title: 'Location',
          children: [
            _ResponsiveFields(
              children: [
                DraftTextField(
                  key: const Key('approximate-area'),
                  label: 'Town or postcode area *',
                  value: draft.approximateArea,
                  hintText: 'Shown to eligible repairers',
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(approximateArea: value),
                  ),
                ),
                DraftTextField(
                  key: const Key('exact-address'),
                  label: 'Exact address *',
                  value: draft.exactAddress,
                  hintText: 'Stored privately',
                  prefixIcon: Icons.lock_outline_rounded,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(exactAddress: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DraftTextField(
              label: 'Private access instructions',
              value: draft.accessInstructions,
              maxLines: 3,
              maxLength: 1000,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(accessInstructions: value),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Repairer travel distance: ${draft.travelDistanceKilometres.round()} km',
            ),
            Slider(
              value: draft.travelDistanceKilometres,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${draft.travelDistanceKilometres.round()} km',
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(travelDistanceKilometres: value),
              ),
            ),
          ],
        ),
        _SectionCard(
          title: 'Repair options',
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Collection required'),
              value: draft.collectionRequired,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(collectionRequired: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mobile repair required'),
              value: draft.mobileRepairRequired,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(mobileRepairRequired: value),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Inspection required before quoting'),
              value: draft.inspectionRequired,
              onChanged: (value) => controller.update(
                (draft) => draft.copyWith(inspectionRequired: value),
              ),
            ),
          ],
        ),
        _SectionCard(
          title: 'Optional budget',
          children: [
            _ResponsiveFields(
              children: [
                _MoneyField(
                  label: 'Maximum callout fee',
                  value: draft.maximumCalloutFee,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      maximumCalloutFee: value,
                      clearCalloutFee: value == null,
                    ),
                  ),
                ),
                _MoneyField(
                  label: 'Budget minimum',
                  value: draft.budgetMinimum,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      budgetMinimum: value,
                      clearBudgetMinimum: value == null,
                    ),
                  ),
                ),
                _MoneyField(
                  label: 'Budget maximum',
                  value: draft.budgetMaximum,
                  onChanged: (value) => controller.update(
                    (draft) => draft.copyWith(
                      budgetMaximum: value,
                      clearBudgetMaximum: value == null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        LiquidGlassCard(
          padding: const EdgeInsets.all(18),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Submitting stores the brief securely with status “submitted”. It will not appear in the marketplace until assessment and your later approval.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LiquidGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 620;
        final width = twoColumns
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _GlassDropdown<T> extends StatelessWidget {
  const _GlassDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelFor,
  });

  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T value)? labelFor;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(labelFor?.call(item) ?? item.toString()),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? (firstDate ?? now),
          firstDate: firstDate ?? DateTime(1950),
          lastDate: DateTime(now.year + 5),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Clear $label',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(
          value == null ? 'Not specified' : DateFormat.yMMMd().format(value!),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final parts = value?.split(':');
        final initial = parts?.length == 2
            ? TimeOfDay(
                hour: int.tryParse(parts![0]) ?? 9,
                minute: int.tryParse(parts[1]) ?? 0,
              )
            : const TimeOfDay(hour: 9, minute: 0);
        final selected = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (selected != null) {
          onChanged(
            '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.schedule_rounded)
              : IconButton(
                  tooltip: 'Clear $label',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(value ?? 'Not specified'),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DraftTextField(
      label: label,
      value: value?.toStringAsFixed(0) ?? '',
      prefixIcon: Icons.currency_pound_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (text) => onChanged(double.tryParse(text)),
    );
  }
}
