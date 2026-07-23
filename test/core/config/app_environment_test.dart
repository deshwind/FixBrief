import 'package:fixbrief/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment release validation', () {
    test('accepts local HTTP only in development', () {
      const environment = AppEnvironment(
        flavor: AppFlavor.development,
        supabaseUrl: 'http://127.0.0.1:54321',
        supabaseAnonKey: 'local-client-key',
      );

      expect(environment.validate, returnsNormally);
    });

    test('rejects demo authentication in production', () {
      const environment = AppEnvironment(
        flavor: AppFlavor.production,
        supabaseUrl: 'https://project-ref.supabase.co',
        supabaseAnonKey: 'sb_publishable_production',
        useDemoAuthentication: true,
      );

      expect(environment.validate, throwsFormatException);
    });

    test('rejects insecure production URLs and placeholder projects', () {
      const insecure = AppEnvironment(
        flavor: AppFlavor.production,
        supabaseUrl: 'http://project-ref.supabase.co',
        supabaseAnonKey: 'sb_publishable_production',
      );
      const placeholder = AppEnvironment(
        flavor: AppFlavor.production,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'sb_publishable_production',
      );

      expect(insecure.validate, throwsFormatException);
      expect(placeholder.validate, throwsFormatException);
    });

    test('accepts a complete production environment', () {
      const environment = AppEnvironment(
        flavor: AppFlavor.production,
        supabaseUrl: 'https://fixbrief-production.supabase.co',
        supabaseAnonKey: 'sb_publishable_production',
      );

      expect(environment.validate, returnsNormally);
    });
  });
}
