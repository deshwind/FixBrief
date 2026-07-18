enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' || 'dev' => AppFlavor.development,
      'staging' || 'stage' => AppFlavor.staging,
      'production' || 'prod' => AppFlavor.production,
      _ => throw ArgumentError.value(value, 'APP_ENV', 'Unsupported flavor'),
    };
  }
}

class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.useDemoAuthentication = false,
  });

  factory AppEnvironment.fromDartDefines() {
    const flavor = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const useDemoAuthentication = bool.fromEnvironment('AUTH_DEMO_MODE');

    return AppEnvironment(
      flavor: AppFlavor.parse(flavor),
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      useDemoAuthentication: useDemoAuthentication,
    );
  }

  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool useDemoAuthentication;

  bool get isProduction => flavor == AppFlavor.production;

  void validate() {
    if (isProduction && useDemoAuthentication) {
      throw const FormatException(
        'AUTH_DEMO_MODE cannot be enabled in production.',
      );
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' &&
            !(flavor == AppFlavor.development && uri.scheme == 'http'))) {
      throw const FormatException(
        'SUPABASE_URL must be an absolute HTTPS URL. HTTP is allowed only '
        'for local development.',
      );
    }

    if (supabaseAnonKey.trim().isEmpty || supabaseAnonKey.startsWith('your-')) {
      throw const FormatException(
        'SUPABASE_ANON_KEY is missing. Pass client configuration with '
        '--dart-define-from-file.',
      );
    }
  }
}
