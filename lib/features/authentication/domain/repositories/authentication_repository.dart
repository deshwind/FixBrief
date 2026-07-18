import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/authentication/domain/entities/registration_result.dart';

abstract interface class AuthenticationRepository {
  AuthUser? get currentUser;

  Stream<AuthenticationEvent> get authenticationEvents;

  Future<AuthUser> signIn({required String email, required String password});

  Future<RegistrationResult> register({
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset({required String email});

  Future<void> updatePassword({required String newPassword});

  Future<void> resendVerification({required String email});

  Future<AuthUser?> refreshCurrentUser();

  Future<void> signOut();
}
