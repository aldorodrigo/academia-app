import 'package:academia_app/features/billing/data/account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'account_json.dart';

void main() {
  InMemorySessionStorage storage() => InMemorySessionStorage()
    ..token = 't'
    ..organization = 'jakare';

  test('consolidado de la familia', () async {
    final requests = <RequestOptions>[];
    final repository = AccountRepository(
      fakeDio({
        'GET /account': (_) => {'data': accountJson()},
      }, requests: requests),
      storage(),
    );

    final account = await repository.consolidated();

    expect(requests.single.path, '/account');
    expect(account.overdue, 150000);
    expect(account.charges, hasLength(3));
  });

  test('sin organización elegida no consulta la API', () async {
    final repository = AccountRepository(
      fakeDio(const {}),
      InMemorySessionStorage()..token = 't',
    );

    expect((await repository.consolidated()).charges, isEmpty);
  });

  test('estado de cuenta de un hijo', () async {
    final repository = AccountRepository(
      fakeDio({
        'GET /students/13/account': (_) => {
          'data': accountJson(
            balance: 60000,
            overdue: 0,
            students: [
              {
                'id': 13,
                'full_name': 'Sofía Benítez',
                'balance': 60000,
                'overdue': 0,
              },
            ],
            charges: [chargeJson()],
          ),
        },
      }),
      storage(),
    );

    final account = await repository.forStudent(13);

    expect(account.students.single.id, 13);
    expect(account.charges.single.finalAmount, 60000);
  });

  test('un alumno ajeno responde 404', () async {
    final repository = AccountRepository(
      fakeDio({
        'GET /students/99/account': (options) =>
            throw apiError(options, 404, {'message': 'No encontrado.'}),
      }),
      storage(),
    );

    expect(
      () => repository.forStudent(99),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
}
