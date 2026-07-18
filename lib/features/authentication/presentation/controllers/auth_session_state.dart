import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:flutter/foundation.dart';

enum AuthSessionPhase { loading, signedOut, authenticated }

@immutable
class AuthSessionState {
  const AuthSessionState({
    required this.phase,
    required this.onboarding,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
    this.noticeMessage,
    this.pendingVerificationEmail,
    this.isPasswordRecovery = false,
  });

  const AuthSessionState.loading()
    : phase = AuthSessionPhase.loading,
      onboarding = const OnboardingProgress.notStarted(),
      user = null,
      isSubmitting = false,
      errorMessage = null,
      noticeMessage = null,
      pendingVerificationEmail = null,
      isPasswordRecovery = false;

  final AuthSessionPhase phase;
  final AuthUser? user;
  final OnboardingProgress onboarding;
  final bool isSubmitting;
  final String? errorMessage;
  final String? noticeMessage;
  final String? pendingVerificationEmail;
  final bool isPasswordRecovery;

  bool get isAuthenticated =>
      phase == AuthSessionPhase.authenticated && user != null;

  String? get verificationEmail => user?.email ?? pendingVerificationEmail;

  AuthSessionState copyWith({
    AuthSessionPhase? phase,
    AuthUser? user,
    OnboardingProgress? onboarding,
    bool? isSubmitting,
    String? errorMessage,
    String? noticeMessage,
    String? pendingVerificationEmail,
    bool? isPasswordRecovery,
    bool clearUser = false,
    bool clearError = false,
    bool clearNotice = false,
    bool clearPendingVerificationEmail = false,
  }) {
    return AuthSessionState(
      phase: phase ?? this.phase,
      user: clearUser ? null : user ?? this.user,
      onboarding: onboarding ?? this.onboarding,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      noticeMessage: clearNotice ? null : noticeMessage ?? this.noticeMessage,
      pendingVerificationEmail: clearPendingVerificationEmail
          ? null
          : pendingVerificationEmail ?? this.pendingVerificationEmail,
      isPasswordRecovery: isPasswordRecovery ?? this.isPasswordRecovery,
    );
  }
}
