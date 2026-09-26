import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import 'models.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token',
      data: {'email': email, 'password': password, 'device_name': 'app'},
    );
    await _storage.writeToken(response.data!['token'] as String);
  }

  /// Sesión actual o null si no hay token válido.
  Future<Session?> restore() async {
    if (await _storage.readToken() == null) return null;

    try {
      final response = await _dio.get<Map<String, dynamic>>('/me');
      final data = response.data!['data'] as Map<String, dynamic>;
      final organizations = (data['organizations'] as List)
          .map((o) => Organization.fromJson(o as Map<String, dynamic>))
          .toList();

      var slug = await _storage.readOrganization();
      if (!organizations.any((o) => o.slug == slug)) {
        slug = organizations.length == 1 ? organizations.first.slug : null;
        if (slug != null) await _storage.writeOrganization(slug);
      }

      return Session(
        name: data['name'] as String,
        email: data['email'] as String,
        organizations: organizations,
        organizationSlug: slug,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<void> selectOrganization(String slug) =>
      _storage.writeOrganization(slug);

  Future<void> logout() async {
    try {
      await _dio.delete<void>('/auth/token');
    } on DioException {
      // Si el token ya no es válido, igual cerramos la sesión local.
    }
    await _storage.clear();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);
