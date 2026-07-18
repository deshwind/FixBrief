import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';

enum AuthenticationEventType {
  initialSession,
  signedIn,
  signedOut,
  passwordRecovery,
  userUpdated,
  tokenRefreshed,
  userDeleted,
}

class AuthenticationEvent {
  const AuthenticationEvent({required this.type, required this.user});

  final AuthenticationEventType type;
  final AuthUser? user;
}
