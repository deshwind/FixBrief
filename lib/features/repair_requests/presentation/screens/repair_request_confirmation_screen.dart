import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RepairRequestConfirmationScreen extends ConsumerWidget {
  const RepairRequestConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(repairRequestWizardControllerProvider);
    final requestId = state.submittedRequestId ?? state.draft?.id;
    return Scaffold(
      body: FluidBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: LiquidGlassCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.task_alt_rounded,
                          size: 46,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Repair request submitted',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your private brief is saved and is awaiting assessment. It is not visible in the repairer marketplace yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (requestId != null) ...[
                        const SizedBox(height: 18),
                        SelectableText(
                          'Reference ${requestId.substring(0, 8).toUpperCase()}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                      const SizedBox(height: 24),
                      const _NextStep(
                        number: '1',
                        title: 'Assessment',
                        body:
                            'FixBrief will organise the details, check safety rules, and prepare possible causes.',
                      ),
                      const _NextStep(
                        number: '2',
                        title: 'Your approval',
                        body:
                            'You will review the final summary and control when it is published.',
                      ),
                      const _NextStep(
                        number: '3',
                        title: 'Repairer quotes',
                        body:
                            'Eligible repairers can respond after the approved brief is published.',
                      ),
                      const SizedBox(height: 26),
                      if (requestId != null) ...[
                        LiquidGlassButton(
                          key: const Key('start-ai-assessment'),
                          label: 'Start AI assessment',
                          icon: Icons.auto_awesome_rounded,
                          expand: true,
                          onPressed: () =>
                              context.go(AppPaths.aiAssessmentFor(requestId)),
                        ),
                        const SizedBox(height: 10),
                      ],
                      LiquidGlassButton(
                        label: 'Return home',
                        level: LiquidGlassButtonLevel.secondary,
                        expand: true,
                        onPressed: () => context.go(AppPaths.customerHome),
                      ),
                      const SizedBox(height: 10),
                      LiquidGlassButton(
                        label: 'Create another request',
                        level: LiquidGlassButtonLevel.secondary,
                        expand: true,
                        onPressed: () async {
                          await ref
                              .read(
                                repairRequestWizardControllerProvider.notifier,
                              )
                              .startFreshDraft();
                          if (context.mounted) {
                            context.go(AppPaths.repairRequestCategory);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            child: Text(number, style: Theme.of(context).textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
