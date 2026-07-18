import 'dart:async';

import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';

class DemoIdentityStore {
  final StreamController<AuthenticationEvent> _events =
      StreamController<AuthenticationEvent>.broadcast();

  AuthUser? currentUser;
  AuthUser? pendingUser;
  OnboardingProgress progress = const OnboardingProgress.notStarted();

  Stream<AuthenticationEvent> get events => _events.stream;

  void emit(AuthenticationEventType type, AuthUser? user) {
    currentUser = user;
    _events.add(AuthenticationEvent(type: type, user: user));
  }

  void selectRole(UserRole role) {
    progress = OnboardingProgress(
      role: role,
      status: OnboardingStatus.inProgress,
    );
  }

  void completeOnboarding() {
    final role = progress.role;
    if (role == null) {
      return;
    }
    progress = OnboardingProgress(
      role: role,
      status: role == UserRole.customer
          ? OnboardingStatus.approved
          : OnboardingStatus.submitted,
    );
  }

  Future<void> dispose() => _events.close();
}
