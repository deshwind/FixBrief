import 'package:fixbrief/features/authentication/data/demo/demo_authentication_repository.dart';
import 'package:fixbrief/features/authentication/data/demo/demo_identity_store.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/authentication/domain/errors/authentication_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoAuthenticationRepository', () {
    late DemoIdentityStore store;
    late DemoAuthenticationRepository repository;

    setUp(() {
      store = DemoIdentityStore();
      repository = DemoAuthenticationRepository(store);
    });

    tearDown(() async {
      await store.dispose();
    });

    test('normalizes email and emits a signed-in event', () async {
      final event = expectLater(
        repository.authenticationEvents,
        emits(
          isA<AuthenticationEvent>().having(
            (value) => value.type,
            'type',
            AuthenticationEventType.signedIn,
          ),
        ),
      );

      final user = await repository.signIn(
        email: '  Alex@Example.COM ',
        password: 'FixBriefDemo123',
      );

      expect(user.email, 'alex@example.com');
      expect(repository.currentUser, user);
      await event;
    });

    test('does not expose credential details for a short password', () async {
      expect(
        () => repository.signIn(email: 'alex@example.com', password: 'short'),
        throwsA(
          isA<AuthenticationFailure>()
              .having(
                (value) => value.message,
                'message',
                'The email or password is incorrect.',
              )
              .having((value) => value.code, 'code', 'invalid_credentials'),
        ),
      );
    });

    test(
      'registration requires verification before creating a session',
      () async {
        final registration = await repository.register(
          email: 'alex@example.com',
          password: 'FixBriefDemo123',
        );

        expect(registration.hasSession, isFalse);
        expect(registration.user.emailVerified, isFalse);
        expect(repository.currentUser, isNull);

        final verified = await repository.refreshCurrentUser();
        expect(verified?.emailVerified, isTrue);
        expect(repository.currentUser, verified);
      },
    );
  });
}
