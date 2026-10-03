import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/session_storage.dart';
import 'models.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final SessionStorage _storage;

  /// [login] es el celular o el correo.
  Future<void> login({required String login, required String password}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/token',
      data: {'login': login, 'password': password, 'device_name': 'app'},
    );
    await _storage.writeToken(response.data!['token'] as String);
  }

  /// Crea la cuenta (sin organizaciones) y deja la sesión iniciada; la API
  /// manda el código por WhatsApp si hay [phone], si no por correo.
  Future<void> register({
    required String name,
    String? phone,
    String? email,
    required String password,
    required String passwordConfirmation,
    String? captchaToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'phone': ?phone,
        'email': ?email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': 'app',
        'terms': true,
        'captcha_token': ?captchaToken,
      },
    );
    await _storage.writeToken(response.data!['token'] as String);
  }

  Future<void> verify(String code) =>
      _dio.post<void>('/auth/verify', data: {'code': code});

  /// Código nuevo; con [byEmail], por correo en lugar de WhatsApp.
  Future<void> resendCode({bool byEmail = false, String? captchaToken}) =>
      _dio.post<void>(
        '/auth/verify/resend',
        data: {if (byEmail) 'channel': 'mail', 'captcha_token': ?captchaToken},
      );

  /// Pide el código para cambiar la contraseña (la API responde igual haya o
  /// no una cuenta).
  Future<void> forgotPassword(String login, {String? captchaToken}) =>
      _dio.post<void>(
        '/auth/password/forgot',
        data: {'login': login, 'captcha_token': ?captchaToken},
      );

  /// Cambia la contraseña con el código y deja la sesión iniciada.
  Future<void> resetPassword({
    required String login,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/password/reset',
      data: {
        'login': login,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': 'app',
      },
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
        phone: data['phone'] as String?,
        email: data['email'] as String?,
        organizations: organizations,
        organizationSlug: slug,
        verified: data['verified'] as bool? ?? true,
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
