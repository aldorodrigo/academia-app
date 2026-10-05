import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/inbox/data/inbox_repository.dart';
import 'package:academia_app/features/inbox/presentation/inbox_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';

/// Respuestas según el contrato (`API_V1.md`, «Bandeja de avisos»).
Map<String, Object?> notificationJson({
  String id = 'a1',
  String title = 'Baja de Matías',
  String? route = '/hijos/9',
  String? readAt,
}) => {
  'id': id,
  'type': 'student_withdrawn',
  'title': title,
  'body': 'Hola, te contamos que registramos la baja de Matías.',
  'route': route,
  'read_at': readAt,
  'created_at': '2026-10-05T11:32:00-03:00',
};

Map<String, Object? Function(RequestOptions)> _routes({
  int unread = 1,
  int lastPage = 1,
}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Laura',
      'email': 'l@test.com',
      'organizations': [
        {'slug': 'jakare', 'name': 'Club Jakare'},
      ],
    },
  },
  'GET /me/notifications': (options) => options.queryParameters['page'] == 2
      ? {
          'data': [notificationJson(id: 'c3', title: 'Más viejo')],
          'meta': {'current_page': 2, 'last_page': 2, 'unread': unread},
        }
      : {
          'data': [
            notificationJson(),
            notificationJson(
              id: 'b2',
              title: 'Clase suspendida',
              route: null,
              readAt: '2026-10-04T10:00:00-03:00',
            ),
          ],
          'meta': {
            'current_page': 1,
            'last_page': lastPage,
            'per_page': 20,
            'total': 2,
            'unread': unread,
          },
        },
  'POST /me/notifications/a1/read': (_) => {
    'data': notificationJson(readAt: '2026-10-05T12:00:00-03:00'),
  },
  'POST /me/notifications/read-all': (_) => {
    'data': {'unread': 0},
  },
};

Widget _app({
  required String location,
  List<RequestOptions>? requests,
  int unread = 1,
  int lastPage = 1,
}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/inicio',
        builder: (_, _) => const Scaffold(body: InboxCard()),
      ),
      GoRoute(path: '/avisos', builder: (_, _) => const InboxScreen()),
      GoRoute(
        path: '/hijos/9',
        builder: (_, _) => const Scaffold(body: Text('Ficha de Matías')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        InMemorySessionStorage()
          ..token = 't'
          ..organization = 'jakare',
      ),
      apiClientProvider.overrideWithValue(
        fakeDio(
          _routes(unread: unread, lastPage: lastPage),
          requests: requests,
        ),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  test('lee la página: hora del club, leído y sin leer', () {
    final page = InboxPage.fromJson(
      _routes()['GET /me/notifications']!(RequestOptions())
          as Map<String, dynamic>,
    );
    expect(page.unread, 1);
    expect(page.hasMore, isFalse);
    expect(page.items.first.createdAt, DateTime(2026, 10, 5, 11, 32));
    expect(page.items.first.isRead, isFalse);
    expect(page.items.last.isRead, isTrue);
    expect(page.items.last.route, isNull);
  });

  testWidgets('el inicio avisa los sin leer y lleva a la bandeja', (
    tester,
  ) async {
    await tester.pumpWidget(_app(location: '/inicio', unread: 2));
    await tester.pumpAndSettle();

    expect(find.text('Tenés 2 avisos sin leer'), findsOneWidget);
    await tester.tap(find.text('Avisos'));
    await tester.pumpAndSettle();
    expect(find.text('Baja de Matías'), findsOneWidget);
  });

  testWidgets('sin avisos sin leer no hay tarjeta', (tester) async {
    await tester.pumpWidget(_app(location: '/inicio', unread: 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-card')), findsNothing);
  });

  testWidgets('tocar un aviso lo marca leído y abre su pantalla', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    await tester.pumpWidget(_app(location: '/avisos', requests: requests));
    await tester.pumpAndSettle();

    expect(find.text('Avisos'), findsOneWidget);
    expect(find.textContaining('05/10/2026 11:32 · Sin leer'), findsOneWidget);
    expect(find.text('Marcar todos como leídos'), findsOneWidget);

    await tester.tap(find.text('Baja de Matías'));
    await tester.pumpAndSettle();

    expect(
      requests.map((r) => '${r.method} ${r.path}'),
      contains('POST /me/notifications/a1/read'),
    );
    expect(find.text('Ficha de Matías'), findsOneWidget);
  });

  testWidgets('marcar todos y ver más', (tester) async {
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(location: '/avisos', requests: requests, lastPage: 2),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver más'));
    await tester.pumpAndSettle();
    expect(find.text('Más viejo'), findsOneWidget);
    expect(find.text('Ver más'), findsNothing);

    await tester.tap(find.text('Marcar todos como leídos'));
    await tester.pumpAndSettle();
    expect(
      requests.map((r) => '${r.method} ${r.path}'),
      contains('POST /me/notifications/read-all'),
    );
    expect(find.textContaining('Sin leer'), findsNothing);
    expect(find.text('Marcar todos como leídos'), findsNothing);
  });
}
