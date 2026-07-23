import 'package:fixbrief/core/constants/user_role.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_authentication_repository.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_identity_store.dart';
import 'package:fixbrief/features/onboarding/data/demo/demo_onboarding_repository.dart';
import 'package:fixbrief/features/onboarding/domain/entities/customer_onboarding_data.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:fixbrief/features/onboarding/domain/errors/onboarding_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Role permissions', () {
    late DemoIdentityStore store;
    late DemoAuthenticationRepository authentication;
    late DemoOnboardingRepository onboarding;
    late String userId;

    setUp(() async {
      store = DemoIdentityStore();
      authentication = DemoAuthenticationRepository(store);
      onboarding = DemoOnboardingRepository(store);
      userId = (await authentication.signIn(
        email: 'role@example.com',
        password: 'FixBriefDemo123',
      )).id;
    });

    tearDown(() async {
      await store.dispose();
    });

    test('role claim is idempotent but cannot switch account type', () async {
      final first = await onboarding.claimRole(
        userId: userId,
        role: UserRole.customer,
      );
      final repeated = await onboarding.claimRole(
        userId: userId,
        role: UserRole.customer,
      );

      expect(first.role, UserRole.customer);
      expect(repeated, first);
      expect(
        () => onboarding.claimRole(userId: userId, role: UserRole.repairer),
        throwsA(
          isA<OnboardingFailure>().having(
            (value) => value.code,
            'code',
            'role_immutable',
          ),
        ),
      );
    });

    test('customer onboarding is rejected for a repairer account', () async {
      await onboarding.claimRole(userId: userId, role: UserRole.repairer);

      expect(
        () => onboarding.completeCustomerOnboarding(
          userId: userId,
          data: const CustomerOnboardingData(
            fullName: 'Alex Morgan',
            phoneNumber: '+44 7700 900000',
            location: 'Manchester',
            preferredContactMethod: PreferredContactMethod.inApp,
            pushNotifications: true,
            emailNotifications: true,
          ),
        ),
        throwsA(isA<OnboardingFailure>()),
      );
      expect(store.progress.status, OnboardingStatus.inProgress);
    });
  });
}
