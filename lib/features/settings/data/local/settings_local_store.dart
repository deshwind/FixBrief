import 'dart:convert';

import 'package:fixbrief/features/settings/domain/entities/settings_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SettingsLocalStore {
  Future<UserSettings> read();

  Future<void> write(UserSettings settings);
}

class SecureSettingsLocalStore implements SettingsLocalStore {
  SecureSettingsLocalStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'fixbrief.settings.appearance.v1';
  final FlutterSecureStorage _storage;
  String? _memoryFallback;

  @override
  Future<UserSettings> read() async {
    try {
      final value = await _storage.read(key: _key) ?? _memoryFallback;
      if (value == null) {
        return const UserSettings();
      }
      final decoded = jsonDecode(value);
      return decoded is Map
          ? UserSettings.fromLocalJson(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const UserSettings();
    } on Object {
      if (_memoryFallback == null) {
        return const UserSettings();
      }
      final decoded = jsonDecode(_memoryFallback!);
      return UserSettings.fromLocalJson(
        (decoded as Map).map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  }

  @override
  Future<void> write(UserSettings settings) async {
    final encoded = jsonEncode(settings.toLocalJson());
    _memoryFallback = encoded;
    try {
      await _storage.write(key: _key, value: encoded);
    } on Object {
      // The in-memory fallback keeps preview and test environments usable.
    }
  }
}
