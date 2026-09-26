import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el token de Sanctum y la organización elegida.
abstract class SessionStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<String?> readOrganization();
  Future<void> writeOrganization(String slug);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token';
  static const _organizationKey = 'organization_slug';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<String?> readOrganization() => _storage.read(key: _organizationKey);

  @override
  Future<void> writeOrganization(String slug) =>
      _storage.write(key: _organizationKey, value: slug);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _organizationKey);
  }
}

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);
