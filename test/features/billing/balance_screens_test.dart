import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/billing/presentation/account_summary_card.dart';
import 'package:academia_app/features/billing/presentation/balance_screen.dart';
import 'package:academia_app/features/billing/presentation/student_account_section.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'account_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _routes({Map<String, Object?>? account}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Ana',
      'email': 'ana@test.com',
      'organizations': [
        {'slug': 'jakare', 'name': 'Club Jakare'},
      ],
    },
  },
  'GET /account': (_) => {'data': account ?? accountJson()},
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
      charges: [
        chargeJson(),
        chargeJson(id: 200, status: 'pagado', description: 'Cuota marzo 2026'),
      ],
    ),
  },
};

Widget _app(Routes routes, Widget home) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(fakeDio(routes)),
    todayProvider.overrideWithValue(DateTime(2026, 9, 26)),
  ],
  child: MaterialApp(
    home: Scaffold(body: ListView(children: [home])),
  ),
);

void main() {
  testWidgets('la tarjeta del inicio muestra el total y lo vencido', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_routes(), const AccountSummaryCard()));
    await tester.pumpAndSettle();

    expect(find.text('Total a pagar ₲ 270.000'), findsOneWidget);
    expect(find.text('Vencido ₲ 150.000'), findsOneWidget);
  });

  testWidgets('al día no muestra vencido', (tester) async {
    await tester.pumpWidget(
      _app(
        _routes(account: accountJson(balance: 0, overdue: 0, charges: [])),
        const AccountSummaryCard(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estás al día'), findsOneWidget);
    expect(find.textContaining('Vencido'), findsNothing);
  });

  testWidgets('estado de cuenta: saldos, filtro y detalle del cargo', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(
            InMemorySessionStorage()
              ..token = 't'
              ..organization = 'jakare',
          ),
          apiClientProvider.overrideWithValue(fakeDio(_routes())),
        ],
        child: const MaterialApp(home: BalanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('₲ 270.000'), findsOneWidget);
    expect(find.text('Mateo Benítez'), findsOneWidget);
    // Pendientes: el pagado no aparece.
    expect(find.text('Cuota septiembre 2026'), findsOneWidget);
    expect(find.text('Cuota agosto 2026'), findsOneWidget);
    expect(find.text('Inscripción 2026'), findsNothing);
    expect(find.text('Sofía · Vence 10/09/2026'), findsOneWidget);

    await tester.tap(find.text('Cuota septiembre 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Beca 50 %'), findsOneWidget);
    expect(find.text('−₲ 75.000'), findsOneWidget);
    expect(find.text('Hermanos (2º hijo) −20 %'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Inscripción 2026'), 200);
    expect(find.text('Inscripción 2026'), findsOneWidget);
  });

  testWidgets('sin pendientes muestra el mensaje vacío', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(
            InMemorySessionStorage()
              ..token = 't'
              ..organization = 'jakare',
          ),
          apiClientProvider.overrideWithValue(
            fakeDio(
              _routes(
                account: accountJson(
                  balance: 0,
                  overdue: 0,
                  charges: [chargeJson(status: 'pagado')],
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: BalanceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tenés cargos pendientes.'), findsOneWidget);
  });

  testWidgets('la ficha del hijo muestra su saldo y sus impagos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_routes(), const StudentAccountSection(studentId: 13)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saldo ₲ 60.000'), findsOneWidget);
    expect(find.text('Cuota septiembre 2026'), findsOneWidget);
    expect(find.text('Cuota marzo 2026'), findsNothing);
    expect(find.text('Vence 10/09/2026'), findsOneWidget);
  });
}
