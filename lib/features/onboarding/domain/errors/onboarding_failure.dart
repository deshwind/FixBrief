class OnboardingFailure implements Exception {
  const OnboardingFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'OnboardingFailure($code)';
}
