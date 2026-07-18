import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String email;
  final bool emailVerified;

  AuthUser copyWith({bool? emailVerified}) {
    return AuthUser(
      id: id,
      email: email,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}
