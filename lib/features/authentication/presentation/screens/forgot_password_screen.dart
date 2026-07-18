import 'dart:async';

import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthShell(
      title: 'Reset your password',
      subtitle:
          'Enter your account email. For privacy, the confirmation is the same whether or not the address is registered.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFeedback(
              error: state.errorMessage,
              notice: state.noticeMessage,
            ),
            if (state.errorMessage != null || state.noticeMessage != null)
              const SizedBox(height: 18),
            LiquidGlassTextField(
              controller: _emailController,
              label: 'Email address',
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: InputValidators.email,
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 18),
            LiquidGlassButton(
              label: 'Send reset link',
              icon: Icons.mark_email_read_outlined,
              expand: true,
              isLoading: state.isSubmitting,
              onPressed: state.isSubmitting ? null : () => unawaited(_submit()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(authSessionControllerProvider.notifier)
        .sendPasswordReset(_emailController.text);
  }
}
