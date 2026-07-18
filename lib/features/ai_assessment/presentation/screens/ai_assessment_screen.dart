import 'dart:async';
import 'dart:math' as math;

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/theme/accessibility_effects_controller.dart';
import 'package:fixbrief/core/theme/liquid_glass_colors.dart';
import 'package:fixbrief/core/widgets/liquid_glass/fluid_background.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_card.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_chip.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_container.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_preview_settings.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_status_pill.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment.dart';
import 'package:fixbrief/features/ai_assessment/domain/entities/ai_assessment_request.dart';
import 'package:fixbrief/features/ai_assessment/presentation/controllers/ai_assessment_controller.dart';
import 'package:fixbrief/features/ai_assessment/presentation/controllers/ai_assessment_state.dart';
import 'package:fixbrief/features/ai_assessment/presentation/providers/ai_assessment_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/account_menu_button.dart';
import 'package:fixbrief/features/repair_requests/presentation/providers/repair_request_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AiAssessmentScreen extends ConsumerStatefulWidget {
  const AiAssessmentScreen({required this.requestId, super.key});

  final String requestId;

  @override
  ConsumerState<AiAssessmentScreen> createState() => _AiAssessmentScreenState();
}

class _AiAssessmentScreenState extends ConsumerState<AiAssessmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    final draft = ref.read(repairRequestWizardControllerProvider).draft;
    final request = aiAssessmentRequestFromDraft(widget.requestId, draft);
    unawaited(ref.read(aiAssessmentControllerProvider.notifier).start(request));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssessmentControllerProvider);
    final controller = ref.read(aiAssessmentControllerProvider.notifier);
    return Scaffold(
      body: FluidBackground(
        accent: LiquidGlassColors.appliances,
        child: CustomScrollView(
          slivers: [
            SliverSafeArea(
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AssessmentHeader(
                            onBack: () {
                              if (state.phase == AiAssessmentPhase.followUp ||
                                  state.phase == AiAssessmentPhase.review) {
                                controller.showResult();
                              } else if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(AppPaths.customerHome);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          const _AssessmentDisclaimer(),
                          if (state.errorMessage case final message?) ...[
                            const SizedBox(height: 14),
                            _FeedbackBanner(message: message, isError: true),
                          ],
                          if (state.noticeMessage case final message?) ...[
                            const SizedBox(height: 14),
                            _FeedbackBanner(message: message),
                          ],
                          const SizedBox(height: 22),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 320),
                            child: _content(state, controller),
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
    );
  }

  Widget _content(AiAssessmentState state, AiAssessmentController controller) {
    return switch (state.phase) {
      AiAssessmentPhase.idle ||
      AiAssessmentPhase.processing => _ProcessingAssessment(
        key: const ValueKey('processing'),
        statusIndex: state.processingStatusIndex,
      ),
      AiAssessmentPhase.result => _AssessmentResult(
        key: ValueKey('result-${state.assessment?.version}'),
        assessment: state.assessment!,
        onFollowUp: controller.showFollowUp,
        onReview: controller.showReview,
        onRegenerate: controller.regenerate,
      ),
      AiAssessmentPhase.followUp => _FollowUpFlow(
        key: ValueKey('follow-up-${state.assessment?.version}'),
        state: state,
        onAnswer: controller.updateAnswer,
        onSkip: controller.toggleSkipped,
        onVoice: controller.toggleVoice,
        onSubmit: controller.submitFollowUps,
        onBack: controller.showResult,
      ),
      AiAssessmentPhase.review || AiAssessmentPhase.saving => _BriefReview(
        key: ValueKey('review-${state.assessment?.version}'),
        state: state,
        onBriefChanged: controller.updateRepairBrief,
        onItemChanged: controller.updateItemName,
        onProblemChanged: controller.updateProblemDescription,
        onCauseChanged: controller.toggleCauseVisibility,
        onSave: controller.saveBrief,
        onPublish: controller.publish,
        onQuestions: controller.showFollowUp,
        onBack: controller.showResult,
      ),
      AiAssessmentPhase.published => _PublishedConfirmation(
        key: const ValueKey('published'),
        onHome: () => context.go(AppPaths.customerHome),
      ),
      AiAssessmentPhase.error => _AssessmentError(
        key: const ValueKey('error'),
        onRetry: _start,
        onHome: () => context.go(AppPaths.customerHome),
      ),
    };
  }
}

class _AssessmentHeader extends StatelessWidget {
  const _AssessmentHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 48,
          child: LiquidGlassContainer(
            radius: 16,
            showShadow: false,
            child: IconButton(
              onPressed: onBack,
              tooltip: 'Go back',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI-assisted assessment',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Prepare and approve your repair brief',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.glassColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const AccountMenuButton(),
        const SizedBox(width: 8),
        const LiquidGlassPreviewSettingsButton(),
      ],
    );
  }
}

class _AssessmentDisclaimer extends StatelessWidget {
  const _AssessmentDisclaimer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: aiAssessmentDisclaimer,
      child: LiquidGlassContainer(
        width: double.infinity,
        showShadow: false,
        radius: 20,
        tint: colorScheme.primary,
        surfaceOpacity: 0.16,
        borderColor: colorScheme.primary,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aiAssessmentDisclaimer,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is based only on the information provided. A qualified professional should inspect the item.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final color = isError ? colors.danger : colors.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          border: Border.all(color: color.withValues(alpha: .45)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ProcessingAssessment extends StatelessWidget {
  const _ProcessingAssessment({required this.statusIndex, super.key});

  final int statusIndex;

  @override
  Widget build(BuildContext context) {
    final status =
        AiAssessmentController.processingStatuses[statusIndex.clamp(
          0,
          AiAssessmentController.processingStatuses.length - 1,
        )];
    return LiquidGlassCard(
      padding: const EdgeInsets.all(28),
      semanticLabel: 'Preparing AI-assisted repair assessment',
      child: Column(
        children: [
          const _AiAssessmentOrb(),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Text(
              status,
              key: ValueKey(status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your request stays private while the brief is prepared.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.glassColors.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value:
                (statusIndex + 1) /
                AiAssessmentController.processingStatuses.length,
            borderRadius: BorderRadius.circular(999),
            semanticsLabel: status,
          ),
        ],
      ),
    );
  }
}

class _AiAssessmentOrb extends ConsumerStatefulWidget {
  const _AiAssessmentOrb();

  @override
  ConsumerState<_AiAssessmentOrb> createState() => _AiAssessmentOrbState();
}

class _AiAssessmentOrbState extends ConsumerState<_AiAssessmentOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effects = ref.watch(accessibilityEffectsControllerProvider);
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final animate =
        effects.motionAllowed(mediaQuery) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && !_controller.isAnimating) {
      unawaited(_controller.repeat());
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }
    return Semantics(
      label: 'Animated FixBrief assessment orb',
      child: SizedBox.square(
        dimension: 184,
        child: CustomPaint(painter: _AiOrbPainter(progress: _controller)),
      ),
    );
  }
}

class _AiOrbPainter extends CustomPainter {
  _AiOrbPainter({required Animation<double> progress})
    : _progress = progress,
      super(repaint: progress);

  final Animation<double> _progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final phase = _progress.value * math.pi * 2;
    final outer = Paint()
      ..shader = RadialGradient(
        colors: [
          LiquidGlassColors.cyan.withValues(alpha: .52),
          LiquidGlassColors.coolBlue.withValues(alpha: .16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, outer);
    final orbCenter =
        center + Offset(math.cos(phase) * 10, math.sin(phase) * 8);
    final orb = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          LiquidGlassColors.cyan,
          LiquidGlassColors.coolBlue,
          LiquidGlassColors.appliances,
        ],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: radius * .58));
    canvas.drawCircle(orbCenter, radius * .58, orb);
    canvas.drawCircle(
      orbCenter + Offset(-radius * .18, -radius * .2),
      radius * .11,
      Paint()..color = Colors.white.withValues(alpha: .6),
    );
  }

  @override
  bool shouldRepaint(covariant _AiOrbPainter oldDelegate) => false;
}

class _AssessmentResult extends StatelessWidget {
  const _AssessmentResult({
    required this.assessment,
    required this.onFollowUp,
    required this.onReview,
    required this.onRegenerate,
    super.key,
  });

  final AiAssessment assessment;
  final VoidCallback onFollowUp;
  final VoidCallback onReview;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assessment.isFallback) ...[
          const _FallbackNotice(),
          const SizedBox(height: 16),
        ],
        _AssessmentReveal(
          index: 0,
          child: _SectionCard(
            icon: Icons.summarize_outlined,
            title: 'Problem summary',
            child: Text(
              assessment.problemSummary,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AssessmentReveal(
          index: 1,
          child: _SectionCard(
            icon: Icons.category_outlined,
            title: 'Possible fault categories',
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final category in assessment.possibleFaultCategories)
                  LiquidGlassChip(label: category),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AssessmentReveal(
          index: 2,
          child: _SectionCard(
            icon: Icons.manage_search_rounded,
            title: 'Possible causes may include',
            subtitle:
                'Confidence indicators organise the intake information; they are not diagnostic certainty.',
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < assessment.possibleCauses.length;
                  index++
                ) ...[
                  if (index > 0) const Divider(height: 28),
                  _PossibleCause(cause: assessment.possibleCauses[index]),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AssessmentReveal(
          index: 3,
          child: _SafetyAssessment(assessment: assessment),
        ),
        const SizedBox(height: 16),
        _AssessmentReveal(
          index: 4,
          child: _SectionCard(
            icon: Icons.engineering_rounded,
            title: 'Recommended professional',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.recommendedProfessional,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in assessment.recommendedSpecialisations)
                      LiquidGlassChip(label: item),
                  ],
                ),
                const SizedBox(height: 16),
                Text(assessment.inspectionRecommendation),
              ],
            ),
          ),
        ),
        if (assessment.recommendedEvidence.isNotEmpty) ...[
          const SizedBox(height: 16),
          _AssessmentReveal(
            index: 5,
            child: _SectionCard(
              icon: Icons.add_a_photo_outlined,
              title: 'Useful evidence to add',
              child: _BulletList(items: assessment.recommendedEvidence),
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (assessment.hasQuestions) ...[
          LiquidGlassButton(
            key: const Key('answer-follow-up-questions'),
            label: 'Answer follow-up questions',
            icon: Icons.question_answer_outlined,
            expand: true,
            onPressed: onFollowUp,
          ),
          const SizedBox(height: 10),
        ],
        LiquidGlassButton(
          key: const Key('review-repair-brief'),
          label: 'Review repair brief',
          icon: Icons.edit_note_rounded,
          level: assessment.hasQuestions
              ? LiquidGlassButtonLevel.secondary
              : LiquidGlassButtonLevel.primary,
          expand: true,
          onPressed: onReview,
        ),
        const SizedBox(height: 10),
        LiquidGlassButton(
          label: 'Regenerate assessment',
          icon: Icons.refresh_rounded,
          level: LiquidGlassButtonLevel.plain,
          expand: true,
          onPressed: onRegenerate,
        ),
      ],
    );
  }
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    return Semantics(
      container: true,
      label:
          'Limited assessment. A conservative repair brief was prepared because the assessment service was unavailable.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.warningSurface.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.warning.withValues(alpha: .65)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Limited assessment: a conservative brief was prepared because the AI service was unavailable. A professional inspection is especially important.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultHeading(icon: icon, title: title),
          if (subtitle case final value?) ...[
            const SizedBox(height: 7),
            Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.glassColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}

class _PossibleCause extends StatelessWidget {
  const _PossibleCause({required this.cause});

  final AiPossibleCause cause;

  @override
  Widget build(BuildContext context) {
    final label = switch (cause.confidence) {
      >= .67 => 'Stronger indication',
      >= .4 => 'Moderate indication',
      _ => 'Limited indication',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                cause.name,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            LiquidGlassStatusPill(label: label),
          ],
        ),
        const SizedBox(height: 9),
        Text(cause.reason),
      ],
    );
  }
}

class _SafetyAssessment extends StatelessWidget {
  const _SafetyAssessment({required this.assessment});

  final AiAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final colors = context.glassColors;
    final serious = assessment.hasHighSafetyRisk;
    final riskLabel = _titleCase(assessment.safetyRisk.name);
    if (serious) {
      final warning = assessment.safetyWarning.trim().isEmpty
          ? 'Stop using the item and contact a qualified professional. Do not attempt further testing or repair.'
          : assessment.safetyWarning;
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Potential safety risk detected. $warning',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.dangerSurface.withValues(alpha: .98),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.danger, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: colors.danger, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potential safety risk detected',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(warning),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _SectionCard(
      icon: Icons.health_and_safety_outlined,
      title: 'Safety and urgency',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          LiquidGlassStatusPill(
            label: '$riskLabel safety risk',
            status: assessment.safetyRisk == AiSafetyRisk.moderate
                ? LiquidGlassStatus.warning
                : LiquidGlassStatus.success,
          ),
          LiquidGlassStatusPill(
            label: '${_titleCase(assessment.urgency.name)} urgency',
            status: assessment.urgency == AiAssessmentUrgency.high
                ? LiquidGlassStatus.warning
                : LiquidGlassStatus.info,
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 7),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FollowUpFlow extends StatefulWidget {
  const _FollowUpFlow({
    required this.state,
    required this.onAnswer,
    required this.onSkip,
    required this.onVoice,
    required this.onSubmit,
    required this.onBack,
    super.key,
  });

  final AiAssessmentState state;
  final void Function(String questionId, String value) onAnswer;
  final ValueChanged<AiFollowUpQuestion> onSkip;
  final ValueChanged<String> onVoice;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  State<_FollowUpFlow> createState() => _FollowUpFlowState();
}

class _FollowUpFlowState extends State<_FollowUpFlow> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _FollowUpFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  void _syncControllers() {
    for (final question in widget.state.assessment!.followUpQuestions) {
      final value = widget.state.answers[question.id] ?? '';
      final controller = _controllers.putIfAbsent(
        question.id,
        () => TextEditingController(text: value),
      );
      if (controller.text != value && widget.state.isListening) {
        controller.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.state.assessment!.followUpQuestions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A few useful follow-up questions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Required questions improve the brief. You can skip the others.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < questions.length; index++) ...[
          _QuestionEditor(
            index: index,
            question: questions[index],
            controller: _controllers[questions[index].id]!,
            isSkipped: widget.state.skippedQuestionIds.contains(
              questions[index].id,
            ),
            isListening:
                widget.state.listeningQuestionId == questions[index].id,
            onChanged: (value) => widget.onAnswer(questions[index].id, value),
            onSkip: () {
              _controllers[questions[index].id]!.clear();
              widget.onSkip(questions[index]);
            },
            onVoice: () => widget.onVoice(questions[index].id),
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 10),
        LiquidGlassButton(
          key: const Key('submit-follow-up-answers'),
          label: 'Update assessment',
          icon: Icons.auto_awesome_rounded,
          expand: true,
          onPressed: widget.onSubmit,
        ),
        const SizedBox(height: 10),
        LiquidGlassButton(
          label: 'Back to assessment',
          level: LiquidGlassButtonLevel.secondary,
          expand: true,
          onPressed: widget.onBack,
        ),
      ],
    );
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.question,
    required this.controller,
    required this.isSkipped,
    required this.isListening,
    required this.onChanged,
    required this.onSkip,
    required this.onVoice,
  });

  final int index;
  final AiFollowUpQuestion question;
  final TextEditingController controller;
  final bool isSkipped;
  final bool isListening;
  final ValueChanged<String> onChanged;
  final VoidCallback onSkip;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 16, child: Text('${index + 1}')),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.question,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (question.isEssential)
                const LiquidGlassStatusPill(
                  label: 'Required',
                  status: LiquidGlassStatus.info,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSkipped)
            Row(
              children: [
                const Expanded(child: Text('Skipped for now')),
                TextButton(onPressed: onSkip, child: const Text('Answer')),
              ],
            )
          else ...[
            LiquidGlassTextField(
              key: Key('follow-up-${question.id}'),
              label: 'Your answer',
              controller: controller,
              maxLines: 3,
              maxLength: 2000,
              onChanged: onChanged,
              onVoiceInput: onVoice,
              suffixIcon: isListening
                  ? const Icon(Icons.mic_rounded, color: Colors.red)
                  : null,
            ),
            if (!question.isEssential)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onSkip,
                  child: const Text('Skip this question'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BriefReview extends StatefulWidget {
  const _BriefReview({
    required this.state,
    required this.onBriefChanged,
    required this.onItemChanged,
    required this.onProblemChanged,
    required this.onCauseChanged,
    required this.onSave,
    required this.onPublish,
    required this.onQuestions,
    required this.onBack,
    super.key,
  });

  final AiAssessmentState state;
  final ValueChanged<String> onBriefChanged;
  final ValueChanged<String> onItemChanged;
  final ValueChanged<String> onProblemChanged;
  final ValueChanged<String> onCauseChanged;
  final VoidCallback onSave;
  final VoidCallback onPublish;
  final VoidCallback onQuestions;
  final VoidCallback onBack;

  @override
  State<_BriefReview> createState() => _BriefReviewState();
}

class _BriefReviewState extends State<_BriefReview> {
  late final TextEditingController _briefController;
  late final TextEditingController _itemController;
  late final TextEditingController _problemController;

  @override
  void initState() {
    super.initState();
    _briefController = TextEditingController(
      text: widget.state.editedRepairBrief,
    );
    _itemController = TextEditingController(text: widget.state.editedItemName);
    _problemController = TextEditingController(
      text: widget.state.editedProblemDescription,
    );
  }

  @override
  void dispose() {
    _briefController.dispose();
    _itemController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.state.phase == AiAssessmentPhase.saving;
    final assessment = widget.state.assessment!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review your repair brief',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'You control what is published. Correct anything that does not match your experience.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.glassColors.secondaryText,
          ),
        ),
        const SizedBox(height: 18),
        LiquidGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ResultHeading(
                icon: Icons.inventory_2_outlined,
                title: 'Item and symptoms',
              ),
              const SizedBox(height: 16),
              LiquidGlassTextField(
                key: const Key('assessment-item-name'),
                label: 'Item name',
                controller: _itemController,
                maxLength: 160,
                onChanged: widget.onItemChanged,
              ),
              const SizedBox(height: 14),
              LiquidGlassTextField(
                key: const Key('assessment-problem-description'),
                label: 'What is happening?',
                controller: _problemController,
                maxLines: 5,
                maxLength: 10000,
                onChanged: widget.onProblemChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ResultHeading(
                icon: Icons.rule_rounded,
                title: 'AI suggestions to include',
              ),
              const SizedBox(height: 8),
              Text(
                'Untick any suggestion that you believe is incorrect.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              for (final cause in assessment.possibleCauses)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: !widget.state.hiddenCauseIds.contains(cause.id),
                  onChanged: busy
                      ? null
                      : (_) => widget.onCauseChanged(cause.id),
                  title: Text(cause.name),
                  subtitle: Text(cause.reason),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ResultHeading(
                icon: Icons.description_outlined,
                title: 'Final repair brief',
              ),
              const SizedBox(height: 16),
              LiquidGlassTextField(
                key: const Key('final-repair-brief'),
                label: 'Repair brief',
                controller: _briefController,
                maxLines: 10,
                maxLength: 15000,
                onChanged: widget.onBriefChanged,
              ),
            ],
          ),
        ),
        if (assessment.hasQuestions) ...[
          const SizedBox(height: 10),
          LiquidGlassButton(
            label: 'Review follow-up answers',
            icon: Icons.question_answer_outlined,
            level: LiquidGlassButtonLevel.plain,
            expand: true,
            onPressed: busy ? null : widget.onQuestions,
          ),
        ],
        const SizedBox(height: 16),
        LiquidGlassButton(
          key: const Key('publish-repair-request'),
          label: 'Approve and publish request',
          icon: Icons.publish_rounded,
          expand: true,
          isLoading: busy,
          onPressed: busy ? null : widget.onPublish,
        ),
        const SizedBox(height: 10),
        LiquidGlassButton(
          label: 'Save without publishing',
          icon: Icons.save_outlined,
          level: LiquidGlassButtonLevel.secondary,
          expand: true,
          isLoading: busy,
          onPressed: busy ? null : widget.onSave,
        ),
        const SizedBox(height: 10),
        LiquidGlassButton(
          label: 'Back to assessment',
          level: LiquidGlassButtonLevel.plain,
          expand: true,
          onPressed: busy ? null : widget.onBack,
        ),
      ],
    );
  }
}

class _PublishedConfirmation extends StatelessWidget {
  const _PublishedConfirmation({required this.onHome, super.key});

  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.campaign_rounded,
            size: 64,
            color: context.glassColors.success,
          ),
          const SizedBox(height: 18),
          Text(
            'Repair request published',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          Text(
            'Your approved brief can now be matched with suitable repair professionals. Your exact address remains private.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          LiquidGlassButton(
            label: 'Return home',
            icon: Icons.home_outlined,
            expand: true,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}

class _AssessmentError extends StatelessWidget {
  const _AssessmentError({
    required this.onRetry,
    required this.onHome,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 56,
            color: context.glassColors.secondaryText,
          ),
          const SizedBox(height: 18),
          Text(
            'Your request is safe',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'No repair brief was published. You can retry the assessment now or return later.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          LiquidGlassButton(
            label: 'Try assessment again',
            icon: Icons.refresh_rounded,
            expand: true,
            onPressed: onRetry,
          ),
          const SizedBox(height: 10),
          LiquidGlassButton(
            label: 'Return home',
            level: LiquidGlassButtonLevel.secondary,
            expand: true,
            onPressed: onHome,
          ),
        ],
      ),
    );
  }
}

class _AssessmentReveal extends ConsumerWidget {
  const _AssessmentReveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final effects = ref.watch(accessibilityEffectsControllerProvider);
    if (!effects.motionAllowed(mediaQuery)) {
      return child;
    }
    return child
        .animate(delay: Duration(milliseconds: 70 * index))
        .fadeIn(duration: 260.ms)
        .slideY(begin: .05, end: 0, duration: 320.ms);
  }
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}
