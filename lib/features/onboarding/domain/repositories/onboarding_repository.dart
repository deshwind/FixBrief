import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:fixbrief/features/onboarding/domain/entities/repairer_onboarding_data.dart';

abstract interface class OnboardingRepository {
  Future<OnboardingProgress> fetchProgress({required String userId});

  Future<OnboardingProgress> claimRole({
    required String userId,
    required UserRole role,
  });

  Future<OnboardingProgress> completeCustomerOnboarding({
    required String userId,
    required CustomerOnboardingData data,
  });

  Future<OnboardingProgress> submitRepairerOnboarding({
    required String userId,
    required RepairerOnboardingData data,
  });
}
