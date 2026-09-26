import 'package:academia_app/core/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  test('agrega el token y el header X-Organization', () async {
    final storage = InMemorySessionStorage()
      ..token = 'abc'
      ..organization = 'jakare';
    final dio = buildApiClient(storage, baseUrl: 'https://api.test');

    late RequestOptions captured;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          handler.resolve(Response(requestOptions: options, statusCode: 200));
        },
      ),
    );

    await dio.get<void>('/organization');

    expect(captured.headers['Authorization'], 'Bearer abc');
    expect(captured.headers['X-Organization'], 'jakare');
    expect(captured.headers['Accept'], 'application/json');
  });

  test('traduce errores de validación de la API a un mensaje', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/auth/token'),
      response: Response(
        requestOptions: RequestOptions(path: '/auth/token'),
        statusCode: 422,
        data: {
          'message': 'Error',
          'errors': {
            'email': [
              'Estas credenciales no coinciden con nuestros registros.',
            ],
          },
        },
      ),
    );

    expect(
      apiErrorMessage(error),
      'Estas credenciales no coinciden con nuestros registros.',
    );
  });
}
