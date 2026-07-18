import 'package:fixbrief/features/authentication/domain/entities/auth_user.dart';

class RegistrationResult {
  const RegistrationResult({required this.user, required this.hasSession});

  final AuthUser user;
  final bool hasSession;
}
