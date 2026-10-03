import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  testWidgets('valida los campos antes de enviar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá tu celular o tu correo.'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña.'), findsOneWidget);
  });
}
