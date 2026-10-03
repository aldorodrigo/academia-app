import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/session_storage.dart';

/// Agrega el token y la organización activa a cada petición.
class SessionInterceptor extends Interceptor {
  SessionInterceptor(this._storage);

  static const organizationHeader = 'X-Organization';

  final SessionStorage _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.readToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final organization = await _storage.readOrganization();
    if (organization != null) {
      options.headers[organizationHeader] = organization;
    }

    handler.next(options);
  }
}

Dio buildApiClient(SessionStorage storage, {String? baseUrl}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(SessionInterceptor(storage));
  return dio;
}

final apiClientProvider = Provider<Dio>(
  (ref) => buildApiClient(ref.watch(sessionStorageProvider)),
);

/// Error de red (sin señal, servidor inalcanzable o tiempo agotado), no una
/// respuesta de la API.
bool isNetworkError(Object error) =>
    error is DioException &&
    error.response == null &&
    error.type != DioExceptionType.cancel &&
    error.type != DioExceptionType.badCertificate;

/// Mensaje de error legible para mostrar al usuario.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['errors'] is Map) {
      final errors = (data['errors'] as Map).values;
      if (errors.isNotEmpty && errors.first is List) {
        return (errors.first as List).first.toString();
      }
    }
    if (data is Map &&
        data['message'] is String &&
        data['message'] != 'Too Many Attempts.') {
      return data['message'] as String;
    }
    if (error.response?.statusCode == 429) {
      return 'Esperá un momento antes de volver a intentar.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'No se pudo conectar con el servidor.';
    }
  }
  return 'Ocurrió un error inesperado.';
}
