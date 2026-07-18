import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/authentication/domain/errors/authentication_failure.dart';
import 'package:fixbrief/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:fixbrief/features/authentication/presentation/controllers/auth_session_state.dart';
import 'package:fixbrief/features/authentication/presentation/providers/authentication_repository_provider.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:fixbrief/features/onboarding/domain/entities/repairer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/errors/onboarding_failure.dart';
import 'package:fixbrief/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:fixbrief/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthSessionController extends Notifier<AuthSessionState> {
  late AuthenticationRepository _authenticationRepository;
  late OnboardingRepository _onboardingRepository;

  @override
  AuthSessionState build() {
    _authenticationRepository = ref.watch(authenticationRepositoryProvider);
    _onboardingRepository = ref.watch(onboardingRepositoryProvider);

    final subscription = _authenticationRepository.authenticationEvents.listen(
      _handleAuthenticationEvent,
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'Your account connection was interrupted. Check your connection and try again.',
          clearNotice: true,
        );
      },
    );
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });
    unawaited(Future<void>.microtask(_restoreSession));

    return const AuthSessionState.loading();
  }

  Future<void> checkEmailVerification() async {
    _startAction();
    try {
      final user = await _authenticationRepository.refreshCurrentUser();
      if (user == null || !user.emailVerified) {
        state = state.copyWith(
          isSubmitting: false,
          noticeMessage: 'Your email is not verified yet.',
          clearError: true,
        );
        return;
      }
      await _loadUser(user);
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }

  Future<void> completeCustomerOnboarding(CustomerOnboardingData data) async {
    final user = state.user;
    if (user == null) {
      _setFailure('Your session expired. Sign in again.');
      return;
    }
    _startAction();
    try {
      final progress = await _onboardingRepository.completeCustomerOnboarding(
        userId: user.id,
        data: data,
      );
      state = state.copyWith(
        onboarding: progress,
        isSubmitting: false,
        noticeMessage: 'Your customer profile is ready.',
        clearError: true,
      );
    } on OnboardingFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    _startAction();
    try {
      final result = await _authenticationRepository.register(
        email: email,
        password: password,
      );
      if (result.hasSession && result.user.emailVerified) {
        await _loadUser(result.user);
        return;
      }
      state = state.copyWith(
        phase: AuthSessionPhase.signedOut,
        clearUser: true,
        onboarding: const OnboardingProgress.notStarted(),
        isSubmitting: false,
        pendingVerificationEmail: result.user.email,
        noticeMessage: 'Check your inbox to verify your email address.',
        clearError: true,
      );
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> resendVerification() async {
    final email = state.verificationEmail;
    if (email == null) {
      _setFailure('Enter your email again from the registration screen.');
      return;
    }
    _startAction();
    try {
      await _authenticationRepository.resendVerification(email: email);
      state = state.copyWith(
        isSubmitting: false,
        noticeMessage: 'A new verification email has been sent.',
        clearError: true,
      );
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> selectRole(UserRole role) async {
    final user = state.user;
    if (user == null) {
      _setFailure('Your session expired. Sign in again.');
      return;
    }
    _startAction();
    try {
      final progress = await _onboardingRepository.claimRole(
        userId: user.id,
        role: role,
      );
      state = state.copyWith(
        onboarding: progress,
        isSubmitting: false,
        clearError: true,
        clearNotice: true,
      );
    } on OnboardingFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    _startAction();
    try {
      await _authenticationRepository.sendPasswordReset(email: email);
      state = state.copyWith(
        isSubmitting: false,
        noticeMessage:
            'If an account exists for that email, a password-reset link is on its way.',
        clearError: true,
      );
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    _startAction();
    try {
      final user = await _authenticationRepository.signIn(
        email: email,
        password: password,
      );
      await _loadUser(user);
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> signOut() async {
    _startAction();
    try {
      await _authenticationRepository.signOut();
      state = const AuthSessionState(
        phase: AuthSessionPhase.signedOut,
        onboarding: OnboardingProgress.notStarted(),
      );
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> submitRepairerOnboarding(RepairerOnboardingData data) async {
    final user = state.user;
    if (user == null) {
      _setFailure('Your session expired. Sign in again.');
      return;
    }
    _startAction();
    try {
      final progress = await _onboardingRepository.submitRepairerOnboarding(
        userId: user.id,
        data: data,
      );
      state = state.copyWith(
        onboarding: progress,
        isSubmitting: false,
        noticeMessage: 'Your business profile has been submitted.',
        clearError: true,
      );
    } on OnboardingFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    _startAction();
    try {
      await _authenticationRepository.updatePassword(newPassword: newPassword);
      state = state.copyWith(
        isSubmitting: false,
        isPasswordRecovery: false,
        noticeMessage: 'Your password has been updated.',
        clearError: true,
      );
    } on AuthenticationFailure catch (failure) {
      _setFailure(failure.message);
    }
  }

  Future<void> _handleAuthenticationEvent(AuthenticationEvent event) async {
    if (event.type == AuthenticationEventType.signedOut ||
        event.type == AuthenticationEventType.userDeleted) {
      state = const AuthSessionState(
        phase: AuthSessionPhase.signedOut,
        onboarding: OnboardingProgress.notStarted(),
      );
      return;
    }
    await _loadUser(
      event.user,
      passwordRecovery: event.type == AuthenticationEventType.passwordRecovery,
    );
  }

  Future<void> _loadUser(
    AuthUser? user, {
    bool passwordRecovery = false,
  }) async {
    if (user == null) {
      state = AuthSessionState(
        phase: AuthSessionPhase.signedOut,
        onboarding: const OnboardingProgress.notStarted(),
        pendingVerificationEmail: state.pendingVerificationEmail,
      );
      return;
    }

    var progress = const OnboardingProgress.notStarted();
    String? profileError;
    if (user.emailVerified) {
      try {
        progress = await _onboardingRepository.fetchProgress(userId: user.id);
      } on OnboardingFailure catch (failure) {
        profileError = failure.message;
      }
    }

    state = AuthSessionState(
      phase: AuthSessionPhase.authenticated,
      user: user,
      onboarding: progress,
      isPasswordRecovery: passwordRecovery,
      errorMessage: profileError,
    );
  }

  Future<void> _restoreSession() async {
    await _loadUser(_authenticationRepository.currentUser);
  }

  void _setFailure(String message) {
    state = state.copyWith(
      isSubmitting: false,
      errorMessage: message,
      clearNotice: true,
    );
  }

  void _startAction() {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );
  }
}
