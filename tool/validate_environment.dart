import 'dart:convert';
import 'dart:io';

import 'package:fixbrief/core/config/app_environment.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/validate_environment.dart <environment.json>',
    );
    exitCode = 64;
    return;
  }

  final file = File(arguments.single);
  if (!await file.exists()) {
    stderr.writeln('Environment file not found: ${file.path}');
    exitCode = 66;
    return;
  }

  try {
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, Object?>) {
      throw const FormatException(
        'The environment file must be a JSON object.',
      );
    }

    final appEnvironmentValue = value['APP_ENV'];
    final demoModeValue = value['AUTH_DEMO_MODE'];
    final supabaseUrlValue = value['SUPABASE_URL'];
    final publishableKeyValue =
        value['SUPABASE_PUBLISHABLE_KEY'] ?? value['SUPABASE_ANON_KEY'];
    if (appEnvironmentValue is! String ||
        demoModeValue is! bool ||
        supabaseUrlValue is! String ||
        publishableKeyValue is! String) {
      throw const FormatException(
        'APP_ENV, AUTH_DEMO_MODE, SUPABASE_URL, and '
        'SUPABASE_PUBLISHABLE_KEY must have the expected JSON types.',
      );
    }

    final environment = AppEnvironment(
      flavor: AppFlavor.parse(appEnvironmentValue),
      supabaseUrl: supabaseUrlValue,
      supabaseAnonKey: publishableKeyValue,
      useDemoAuthentication: demoModeValue,
    )..validate();

    stdout.writeln(
      'Environment is valid: ${environment.flavor.name} '
      '(${Uri.parse(environment.supabaseUrl).host}).',
    );
  } on FormatException catch (error) {
    stderr.writeln('Invalid environment: ${error.message}');
    exitCode = 65;
  } on ArgumentError catch (error) {
    stderr.writeln('Invalid environment: ${error.message}');
    exitCode = 65;
  }
}
