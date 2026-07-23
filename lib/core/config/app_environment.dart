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
    const supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    const legacySupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const useDemoAuthentication = bool.fromEnvironment('AUTH_DEMO_MODE');

    return AppEnvironment(
      flavor: AppFlavor.parse(flavor),
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabasePublishableKey.isNotEmpty
          ? supabasePublishableKey
          : legacySupabaseAnonKey,
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

    final normalizedKey = supabaseAnonKey.trim();
    if (normalizedKey.isEmpty ||
        normalizedKey.startsWith('your-') ||
        normalizedKey == 'replace-with-client-safe-publishable-key') {
      throw const FormatException(
        'SUPABASE_PUBLISHABLE_KEY is missing. Pass client configuration '
        'with --dart-define-from-file.',
      );
    }

    if (isProduction &&
        (uri.host == 'example.supabase.co' ||
            uri.host == 'your-project-ref.supabase.co')) {
      throw const FormatException(
        'Production cannot use a placeholder Supabase project.',
      );
    }
  }
}
