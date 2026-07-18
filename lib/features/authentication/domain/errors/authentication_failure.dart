class AuthenticationFailure implements Exception {
  const AuthenticationFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'AuthenticationFailure($code)';
}
