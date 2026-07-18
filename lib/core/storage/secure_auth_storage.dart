import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureAuthSessionStorage extends LocalStorage {
  const SecureAuthSessionStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _sessionKey = 'fixbrief.supabase.session';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<bool> hasAccessToken() async {
    return await accessToken() != null;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() {
    return _storage.delete(key: _sessionKey);
  }
}

class SecurePkceStorage extends GotrueAsyncStorage {
  const SecurePkceStorage([this._storage = const FlutterSecureStorage()]);

  static const _keyPrefix = 'fixbrief.pkce.';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> getItem({required String key}) {
    return _storage.read(key: '$_keyPrefix$key');
  }

  @override
  Future<void> removeItem({required String key}) {
    return _storage.delete(key: '$_keyPrefix$key');
  }

  @override
  Future<void> setItem({required String key, required String value}) {
    return _storage.write(key: '$_keyPrefix$key', value: value);
  }
}
