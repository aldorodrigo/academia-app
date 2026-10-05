import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/invitations/presentation/invitation_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';
import 'invitation_repository_test.dart' show invitationJson;

Widget _app(Dio dio) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
    apiClientProvider.overrideWithValue(dio),
  ],
  child: const MaterialApp(home: InvitationScreen(token: 'abc')),
);

Map<String, Object?> _invitation({required bool userExists}) => {
  'data': {...invitationJson['data']!, 'user_exists': userExists},
};

void main() {
  testWidgets('cuenta nueva: pide nombre y valida la confirmación', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        fakeDio({
          'GET /invitations/abc': (_) => _invitation(userExists: false),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Club Jakare'), findsOneWidget);
    expect(find.text('Te invitaron como Tutor.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('password')), 'secreta12');
    await tester.enterText(find.byKey(const Key('confirmation')), 'otra');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Ingresá tu nombre.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets(
    'cuenta nueva: trae el nombre de la invitación y pide aceptar los términos',
    (tester) async {
      final requests = <RequestOptions>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const InvitationScreen(token: 'abc'),
          ),
          GoRoute(path: '/inicio', builder: (_, _) => const Text('Inicio')),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
            apiClientProvider.overrideWithValue(
              fakeDio({
                'GET /invitations/abc': (_) => {
                  'data': {...invitationJson['data']!, 'name': 'Ana Pérez'},
                },
                'POST /invitations/abc/accept': (_) => {
                  'token': 't',
                  'organization': 'jakare',
                },
                'GET /me': (_) => {
                  'data': {
                    'name': 'Ana Pérez',
                    'email': 'ana@test.com',
                    'organizations': [
                      {'slug': 'jakare', 'name': 'Club Jakare'},
                    ],
                  },
                },
              }, requests: requests),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // El nombre viene cargado y se puede corregir.
      final name = tester.widget<TextFormField>(find.byKey(const Key('name')));
      expect(name.controller!.text, 'Ana Pérez');

      await tester.enterText(find.byKey(const Key('password')), 'secreta12');
      await tester.enterText(
        find.byKey(const Key('confirmation')),
        'secreta12',
      );
      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      // Sin aceptar los términos no se crea la cuenta.
      expect(find.text('Tenés que aceptar los términos.'), findsOneWidget);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.ensureVisible(find.byKey(const Key('terms')));
      await tester.tap(find.byKey(const Key('terms')));
      await tester.pump();
      expect(find.text('Tenés que aceptar los términos.'), findsNothing);
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      final accept = requests.singleWhere((r) => r.method == 'POST');
      expect(accept.data, {
        'name': 'Ana Pérez',
        'password': 'secreta12',
        'password_confirmation': 'secreta12',
        'device_name': 'app',
        'terms': true,
      });
      expect(find.text('Inicio'), findsOneWidget);
    },
  );

  testWidgets('cuenta existente: solo pide la contraseña', (tester) async {
    await tester.pumpWidget(
      _app(
        fakeDio({'GET /invitations/abc': (_) => _invitation(userExists: true)}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('name')), findsNothing);
    expect(find.byKey(const Key('confirmation')), findsNothing);
    // Ya aceptó los términos al crear su cuenta.
    expect(find.byKey(const Key('terms')), findsNothing);
    expect(find.text('Aceptar'), findsOneWidget);
  });

  testWidgets('invitación vencida muestra el mensaje de la API', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        fakeDio({
          'GET /invitations/abc': (o) => throw apiError(o, 404, {
            'message': 'La invitación no es válida o ya venció.',
          }),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('La invitación no es válida o ya venció.'),
      findsOneWidget,
    );
  });
}
