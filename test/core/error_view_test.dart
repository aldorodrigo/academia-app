import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/cash/presentation/cash_overview_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _session() => {
  'GET /me': (_) => {
    'data': {
      'name': 'Juan',
      'email': 'juan@test.com',
      'organizations': [
        {'slug': 'jakare', 'name': 'Club Jakare'},
      ],
    },
  },
};

/// Como en main.dart: `ProviderScope(retry: apiRetry)`.
Widget _app(Routes routes, Widget home, {List<RequestOptions>? requests}) =>
    ProviderScope(
      retry: apiRetry,
      overrides: [
        sessionStorageProvider.overrideWithValue(
          InMemorySessionStorage()
            ..token = 't'
            ..organization = 'jakare',
        ),
        apiClientProvider.overrideWithValue(
          fakeDio(routes, requests: requests),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => home),
            GoRoute(
              path: '/inicio',
              builder: (_, _) => const Scaffold(body: Text('Inicio')),
            ),
          ],
        ),
      ),
    );

void main() {
  RequestOptions options() => RequestOptions(path: '/cash-boxes');

  test('un 4xx no se reintenta; sin conexión o un 5xx, sí', () {
    expect(apiRetry(0, apiError(options(), 403, {})), isNull);
    expect(apiRetry(0, apiError(options(), 404, {})), isNull);
    expect(apiRetry(0, apiError(options(), 500, {})), isNotNull);
    expect(apiRetry(0, networkError(options())), isNotNull);
    expect(isForbidden(apiError(options(), 403, {})), isTrue);
    expect(isForbidden(apiError(options(), 500, {})), isFalse);
  });

  testWidgets('/efectivo sin permiso no queda cargando', (tester) async {
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(
        {
          ..._session(),
          'GET /cash-boxes': (o) => throw apiError(o, 403, {
            'message': 'No tenés permiso para confirmar depósitos.',
          }),
        },
        const CashOverviewScreen(),
        requests: requests,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No tenés permiso para ver esto'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    // Una sola vez: un 403 no se reintenta.
    expect(requests.where((r) => r.path == '/cash-boxes'), hasLength(1));

    await tester.tap(find.widgetWithText(FilledButton, 'Volver al inicio'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('otro error muestra el mensaje y se puede reintentar', (
    tester,
  ) async {
    var fail = true;
    await tester.pumpWidget(
      _app({
        ..._session(),
        'GET /cash-boxes': (o) => fail
            ? throw apiError(o, 422, {'message': 'Algo salió mal.'})
            : {
                'data': {'boxes': [], 'deposits': []},
              },
      }, const CashOverviewScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Algo salió mal.'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Algo salió mal.'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
  });
}
