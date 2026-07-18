import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_identity_store.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:fixbrief/features/onboarding/domain/entities/repairer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/errors/onboarding_failure.dart';
import 'package:fixbrief/features/onboarding/domain/repositories/onboarding_repository.dart';

class DemoOnboardingRepository implements OnboardingRepository {
  DemoOnboardingRepository(this._store);

  final DemoIdentityStore _store;

  @override
  Future<OnboardingProgress> claimRole({
    required String userId,
    required UserRole role,
  }) async {
    _ensureCurrentUser(userId);
    _store.selectRole(role);
    return _store.progress;
  }

  @override
  Future<OnboardingProgress> completeCustomerOnboarding({
    required String userId,
    required CustomerOnboardingData data,
  }) async {
    _ensureCurrentUser(userId);
    if (_store.progress.role != UserRole.customer) {
      throw const OnboardingFailure('This account is not a customer account.');
    }
    _store.completeOnboarding();
    return _store.progress;
  }

  @override
  Future<OnboardingProgress> fetchProgress({required String userId}) async {
    _ensureCurrentUser(userId);
    return _store.progress;
  }

  @override
  Future<OnboardingProgress> submitRepairerOnboarding({
    required String userId,
    required RepairerOnboardingData data,
  }) async {
    _ensureCurrentUser(userId);
    if (_store.progress.role != UserRole.repairer) {
      throw const OnboardingFailure('This account is not a repairer account.');
    }
    _store.completeOnboarding();
    return _store.progress;
  }

  void _ensureCurrentUser(String userId) {
    if (_store.currentUser?.id != userId) {
      throw const OnboardingFailure(
        'Your session expired. Sign in again.',
        code: 'session_missing',
      );
    }
  }
}
