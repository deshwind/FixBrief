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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionControllerProvider);
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in securely to continue your repair journey.',
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
                autofillHints: const [AutofillHints.email],
                validator: InputValidators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _passwordController,
                validator: (value) =>
                    InputValidators.requiredText(value, label: 'Password'),
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go(AppPaths.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 8),
              LiquidGlassButton(
                label: 'Sign in',
                icon: Icons.login_rounded,
                expand: true,
                isLoading: authState.isSubmitting,
                onPressed: authState.isSubmitting
                    ? null
                    : () => unawaited(_submit()),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => context.go(AppPaths.register),
                child: const Text('New to FixBrief? Create an account'),
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
    await ref
        .read(authSessionControllerProvider.notifier)
        .signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }
}
