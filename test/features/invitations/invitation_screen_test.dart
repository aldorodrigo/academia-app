import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/invitations/presentation/invitation_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('cuenta existente: solo pide la contraseña', (tester) async {
    await tester.pumpWidget(
      _app(
        fakeDio({'GET /invitations/abc': (_) => _invitation(userExists: true)}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('name')), findsNothing);
    expect(find.byKey(const Key('confirmation')), findsNothing);
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
