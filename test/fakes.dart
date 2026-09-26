import 'package:dio/dio.dart';
import 'package:academia_app/core/storage/session_storage.dart';

class InMemorySessionStorage implements SessionStorage {
  String? token;
  String? organization;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String token) async => this.token = token;

  @override
  Future<String?> readOrganization() async => organization;

  @override
  Future<void> writeOrganization(String slug) async => organization = slug;

  @override
  Future<void> clear() async {
    token = null;
    organization = null;
  }
}

/// Dio que responde sin red: [routes] mapea "MÉTODO /ruta" a una función que
/// devuelve el cuerpo, o lanza para simular un error. Guarda cada petición.
Dio fakeDio(
  Map<String, Object? Function(RequestOptions options)> routes, {
  List<RequestOptions>? requests,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        requests?.add(options);
        final route = routes['${options.method} ${options.path}'];
        if (route == null) {
          return handler.reject(
            DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: 404),
            ),
          );
        }
        try {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: route(options),
            ),
          );
        } on DioException catch (e) {
          handler.reject(e);
        }
      },
    ),
  );
  return dio;
}

/// Error HTTP con cuerpo JSON, como los que devuelve la API.
DioException apiError(RequestOptions options, int status, Object? data) =>
    DioException(
      requestOptions: options,
      response: Response(
        requestOptions: options,
        statusCode: status,
        data: data,
      ),
    );
