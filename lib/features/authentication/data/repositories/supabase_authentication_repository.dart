import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';
import 'package:fixbrief/features/authentication/domain/entities/authentication_event.dart';
import 'package:fixbrief/features/authentication/domain/entities/registration_result.dart';
import 'package:fixbrief/features/authentication/domain/errors/authentication_failure.dart';
import 'package:fixbrief/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

class SupabaseAuthenticationRepository implements AuthenticationRepository {
  SupabaseAuthenticationRepository(this._client);

  static const _emailVerificationRedirect =
      'fixbrief://auth-callback/verify-email';
  static const _passwordRecoveryRedirect =
      'fixbrief://auth-callback/reset-password';

  final SupabaseClient _client;

  @override
  Stream<AuthenticationEvent> get authenticationEvents {
    return _client.auth.onAuthStateChange.map((data) {
      return AuthenticationEvent(
        type: _mapEvent(data.event),
        user: _mapUser(data.session?.user ?? _client.auth.currentUser),
      );
    });
  }

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<AuthUser?> refreshCurrentUser() async {
    try {
      final response = await _client.auth.getUser();
      return _mapUser(response.user);
    } on AuthException catch (error) {
      throw _mapFailure(error);
    } on Object {
      throw const AuthenticationFailure(
        'We could not refresh your account. Check your connection and try again.',
        code: 'refresh_failed',
      );
    }
  }

  @override
  Future<RegistrationResult> register({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        emailRedirectTo: _emailVerificationRedirect,
        data: const <String, Object?>{'registration_method': 'email'},
      );
      final user = _mapUser(response.user);
      if (user == null) {
        throw const AuthenticationFailure(
          'We could not create the account. Please try again.',
          code: 'missing_user',
        );
      }
      return RegistrationResult(
        user: user,
        hasSession: response.session != null,
      );
    } on AuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> resendVerification({required String email}) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim().toLowerCase(),
        emailRedirectTo: _emailVerificationRedirect,
      );
    } on AuthException catch (error) {
      throw _mapFailure(error);
    } on Object {
      throw const AuthenticationFailure(
        'We could not resend the email. Check your connection and try again.',
        code: 'resend_failed',
      );
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: _passwordRecoveryRedirect,
      );
    } on AuthException catch (error) {
      throw _mapFailure(error);
    } on Object {
      throw const AuthenticationFailure(
        'We could not send the reset email. Check your connection and try again.',
        code: 'reset_failed',
      );
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = _mapUser(response.user);
      if (user == null) {
        throw const AuthenticationFailure(
          'We could not sign you in. Please try again.',
          code: 'missing_user',
        );
      }
      return user;
    } on AuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  static AuthUser? _mapUser(User? user) {
    final email = user?.email;
    if (user == null || email == null) {
      return null;
    }
    return AuthUser(
      id: user.id,
      email: email,
      emailVerified: user.emailConfirmedAt != null,
    );
  }

  static AuthenticationEventType _mapEvent(AuthChangeEvent event) {
    return switch (event) {
      AuthChangeEvent.initialSession => AuthenticationEventType.initialSession,
      AuthChangeEvent.signedIn => AuthenticationEventType.signedIn,
      AuthChangeEvent.signedOut => AuthenticationEventType.signedOut,
      AuthChangeEvent.passwordRecovery =>
        AuthenticationEventType.passwordRecovery,
      AuthChangeEvent.tokenRefreshed => AuthenticationEventType.tokenRefreshed,
      AuthChangeEvent.userUpdated => AuthenticationEventType.userUpdated,
      AuthChangeEvent.mfaChallengeVerified =>
        AuthenticationEventType.userUpdated,
      _ => AuthenticationEventType.userDeleted,
    };
  }

  static AuthenticationFailure _mapFailure(AuthException error) {
    final message = switch (error.code) {
      'invalid_credentials' => 'The email or password is incorrect.',
      'email_not_confirmed' => 'Verify your email address before signing in.',
      'weak_password' =>
        'Use a stronger password with at least 12 characters, uppercase, lowercase, and a number.',
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        'Too many attempts. Wait a few minutes and try again.',
      'same_password' => 'Choose a password you have not used already.',
      'session_expired' ||
      'refresh_token_not_found' => 'Your session expired. Sign in again.',
      _ => 'Authentication could not be completed. Please try again.',
    };
    return AuthenticationFailure(message, code: error.code);
  }
}
