import 'package:fixbrief/features/authentication/data/demo/demo_identity_store.dart';
import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/authentication/domain/entities/registration_result.dart';
import 'package:fixbrief/features/authentication/domain/errors/authentication_failure.dart';
import 'package:fixbrief/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:fixbrief/features/onboarding/domain/entities/onboarding_progress.dart';

class DemoAuthenticationRepository implements AuthenticationRepository {
  DemoAuthenticationRepository(this._store);

  final DemoIdentityStore _store;

  @override
  Stream<AuthenticationEvent> get authenticationEvents => _store.events;

  @override
  AuthUser? get currentUser => _store.currentUser;

  @override
  Future<AuthUser?> refreshCurrentUser() async {
    final pending = _store.pendingUser;
    if (_store.currentUser == null && pending != null) {
      final verified = pending.copyWith(emailVerified: true);
      _store.pendingUser = null;
      _store.emit(AuthenticationEventType.signedIn, verified);
      return verified;
    }
    return _store.currentUser;
  }

  @override
  Future<RegistrationResult> register({
    required String email,
    required String password,
  }) async {
    final user = AuthUser(
      id: 'demo-${email.toLowerCase().hashCode.abs()}',
      email: email.trim().toLowerCase(),
      emailVerified: false,
    );
    _store.pendingUser = user;
    return RegistrationResult(user: user, hasSession: false);
  }

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (password.length < 12) {
      throw const AuthenticationFailure(
        'The email or password is incorrect.',
        code: 'invalid_credentials',
      );
    }
    final user = AuthUser(
      id: 'demo-${email.toLowerCase().hashCode.abs()}',
      email: email.trim().toLowerCase(),
      emailVerified: true,
    );
    _store.emit(AuthenticationEventType.signedIn, user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _store.progress = const OnboardingProgress.notStarted();
    _store.emit(AuthenticationEventType.signedOut, null);
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    if (_store.currentUser == null) {
      throw const AuthenticationFailure(
        'Open a new password-reset link and try again.',
        code: 'session_missing',
      );
    }
  }
}
