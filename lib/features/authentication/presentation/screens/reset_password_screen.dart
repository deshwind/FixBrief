import 'dart:async';

import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authSessionControllerProvider);
    return AuthShell(
      title: 'Choose a new password',
      subtitle:
          'This reset session is temporary and tied to the link you opened.',
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
            PasswordField(
              controller: _passwordController,
              label: 'New password',
              validator: InputValidators.password,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            PasswordField(
              controller: _confirmController,
              label: 'Confirm new password',
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) => value == _passwordController.text
                  ? null
                  : 'Passwords do not match.',
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 18),
            LiquidGlassButton(
              label: 'Update password',
              icon: Icons.password_rounded,
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
        .updatePassword(_passwordController.text);
  }
}
