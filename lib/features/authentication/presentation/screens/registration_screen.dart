import 'dart:async';

import 'package:fixbrief/core/routing/app_paths.dart';
import 'package:fixbrief/core/validation/input_validators.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_button.dart';
import 'package:fixbrief/core/widgets/liquid_glass/liquid_glass_text_field.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_providers.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_feedback.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/auth_shell.dart';
import 'package:fixbrief/features/authentication/presentation/widgets/password_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionControllerProvider);
    return AuthShell(
      title: 'Create your account',
      subtitle:
          'You will verify your email, choose an account type, then complete the matching profile.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthFeedback(
                error: authState.errorMessage,
                notice: authState.noticeMessage,
              ),
              if (authState.errorMessage != null ||
                  authState.noticeMessage != null)
                const SizedBox(height: 18),
              LiquidGlassTextField(
                controller: _emailController,
                label: 'Email address',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: InputValidators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _passwordController,
                validator: InputValidators.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 10),
              Text(
                'Use at least 12 characters with uppercase, lowercase, and a number.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm password',
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                onChanged: (value) {
                  setState(() => _acceptedTerms = value ?? false);
                },
                title: const Text(
                  'I agree to the Terms and acknowledge the Privacy Notice.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 12),
              LiquidGlassButton(
                label: 'Create account',
                icon: Icons.person_add_alt_1_rounded,
                expand: true,
                isLoading: authState.isSubmitting,
                onPressed: authState.isSubmitting
                    ? null
                    : () => unawaited(_submit()),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go(AppPaths.login),
                child: const Text('Already registered? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the Terms and Privacy Notice to continue.'),
        ),
      );
      return;
    }
    await ref
        .read(authSessionControllerProvider.notifier)
        .register(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) {
      return;
    }
    final state = ref.read(authSessionControllerProvider);
    if (state.errorMessage == null && state.verificationEmail != null) {
      context.go(AppPaths.emailVerification);
    }
  }
}
