import 'package:fixbrief/core/constants/user_role.dart';
import 'package:flutter/foundation.dart';

enum OnboardingStatus {
  notStarted,
  inProgress,
  submitted,
  approved,
  rejected;

  static OnboardingStatus fromDatabase(String? value) {
    return switch (value) {
      'in_progress' => OnboardingStatus.inProgress,
      'submitted' => OnboardingStatus.submitted,
      'approved' => OnboardingStatus.approved,
      'rejected' => OnboardingStatus.rejected,
      _ => OnboardingStatus.notStarted,
    };
  }
}

@immutable
class OnboardingProgress {
  const OnboardingProgress({required this.role, required this.status});

  const OnboardingProgress.notStarted()
    : role = null,
      status = OnboardingStatus.notStarted;

  final UserRole? role;
  final OnboardingStatus status;

  bool get allowsAppAccess {
    return switch (role) {
      UserRole.customer => status == OnboardingStatus.approved,
      UserRole.repairer =>
        status == OnboardingStatus.submitted ||
            status == OnboardingStatus.approved,
      null => false,
    };
  }
}
