import 'package:academia_app/app.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/theme/brand.dart';
import 'package:academia_app/core/theme/tuku_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  testWidgets('arranca en español y sin sesión muestra el login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.byType(TukuLogo), findsOneWidget);
  });

  testWidgets('la marca: nombre Tuku, verde y las tipografías de la marca', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(InMemorySessionStorage()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Tuku');
    expect(app.theme!.colorScheme.primary, TukuColors.verde);
    expect(app.darkTheme!.colorScheme.primary, TukuColors.verdeOscuro);
    expect(app.theme!.textTheme.bodyLarge!.fontFamily, TukuFonts.sans);
    expect(app.theme!.textTheme.headlineSmall!.fontFamily, TukuFonts.display);
  });
}
