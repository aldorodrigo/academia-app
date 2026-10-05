import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/reports/data/models.dart';
import 'package:academia_app/features/reports/data/reports_repository.dart';
import 'package:academia_app/features/reports/presentation/reports_card.dart';
import 'package:academia_app/features/reports/presentation/reports_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

Map<String, Object?> balanceJson({
  String from = '2026-09-01',
  String to = '2026-09-30',
  int closing = 1850000,
}) => {
  'from': from,
  'to': to,
  'opening_balance': 1200000,
  'closing_balance': closing,
  'income': {
    'total': 2100000,
    'lines': [
      {'label': 'Cuota mensual', 'amount': 1800000},
      {'label': 'Saldo a favor', 'amount': 300000},
    ],
  },
  'expenses': {
    'total': 1450000,
    'lines': [
      {'label': 'Alquiler de cancha', 'amount': 1200000},
      {'label': 'Árbitros', 'amount': 250000},
    ],
  },
  'accounts': [
    {'name': 'Caja', 'balance': 350000},
    {'name': 'Banco Itaú', 'balance': 1500000},
  ],
  'pending_expenses': 1200000,
  'other': 500000,
  'pdf_url': 'https://api.test/informes/balance.pdf?signature=a',
  'xlsx_url': 'https://api.test/informes/balance.xlsx?signature=a',
};

const balancesJson = {
  'totals': {
    'pending': 3250000,
    'overdue': 1800000,
    'credit': 90300,
    'upcoming': 400000,
  },
  'families': [
    {
      'family': 'Familia Benítez',
      'students': ['Mateo', 'Sofía'],
      'pending': 270000,
      'overdue': 150000,
      'credit': 0,
      'upcoming': 200000,
      'withdrawn': [
        {'student_id': 7, 'student': 'Sofía', 'on': '2026-06-03'},
      ],
    },
  ],
  'pdf_url': 'https://api.test/informes/saldos.pdf',
  'xlsx_url': 'https://api.test/informes/saldos.xlsx',
};

const delinquentsJson = {
  'total': 450000,
  'families': [
    {
      'family': 'Familia Ortiz',
      'students': ['Diego'],
      'overdue': 450000,
      'oldest_due_on': '2026-07-10',
      'months_overdue': 3,
      'contact': {'name': 'Rosa Ortiz', 'phone': '0981 222 333'},
      'withdrawn': <Object>[],
    },
  ],
  'pdf_url': 'https://api.test/informes/morosos.pdf',
  'xlsx_url': 'https://api.test/informes/morosos.xlsx',
};

/// Morosos dados de baja (filtro `withdrawn=only`).
const withdrawnDelinquentsJson = {
  'total': 300000,
  'families': [
    {
      'family': 'Familia Zárate',
      'students': ['Matías'],
      'overdue': 300000,
      'oldest_due_on': '2026-05-10',
      'months_overdue': 2,
      'contact': null,
      'withdrawn': [
        {'student_id': 9, 'student': 'Matías', 'on': '2026-06-03'},
      ],
    },
  ],
  'pdf_url': 'https://api.test/informes/morosos.pdf?withdrawn=only',
  'xlsx_url': 'https://api.test/informes/morosos.xlsx?withdrawn=only',
};

Map<String, Object? Function(RequestOptions)> _routes({
  List<String> permissions = const ['view_reports'],
}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Tesorera',
      'email': 't@test.com',
      'organizations': [
        {'slug': 'jakare', 'name': 'Club Jakare'},
      ],
    },
  },
  'GET /organization': (_) => {
    'data': {
      'slug': 'jakare',
      'name': 'Club Jakare',
      'membership': {'roles': <Object>[], 'permissions': permissions},
    },
  },
  'GET /reports/balance': (options) {
    final from = options.queryParameters['from'] as String;
    return {
      'data': balanceJson(
        from: from,
        to: options.queryParameters['to'] as String,
        closing: from == '2026-08-01' ? 1200000 : 1850000,
      ),
    };
  },
  'GET /reports/balances': (_) => {'data': balancesJson},
  'GET /reports/delinquents': (options) => {
    'data': options.queryParameters['withdrawn'] == 'only'
        ? withdrawnDelinquentsJson
        : delinquentsJson,
  },
};

Widget _app(
  Widget home, {
  List<String> permissions = const ['view_reports'],
  List<Uri>? opened,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(
      fakeDio(_routes(permissions: permissions)),
    ),
    todayProvider.overrideWithValue(DateTime(2026, 9, 27)),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened?.add(uri);
      return true;
    }),
  ],
  child: MaterialApp(home: home),
);

void main() {
  test('lee los tres informes', () {
    final balance = BalanceReport.fromJson(balanceJson());
    expect(balance.result, 650000);
    expect(balance.expenses.first.label, 'Alquiler de cancha');
    expect(balance.links.xlsx, contains('xlsx'));

    final balances = BalancesReport.fromJson(balancesJson);
    expect(balances.families.single.students, ['Mateo', 'Sofía']);
    expect(balances.upcoming, 400000);
    expect(balances.families.single.upcoming, 200000);

    final delinquents = DelinquentsReport.fromJson(delinquentsJson);
    expect(delinquents.families.single.monthsOverdue, 3);
    expect(delinquents.families.single.contactPhone, '0981 222 333');
    expect(delinquents.families.single.withdrawn, isEmpty);

    final withdrawn = balances.families.single.withdrawn.single;
    expect(withdrawn.studentId, 7);
    expect(withdrawn.student, 'Sofía');
    expect(withdrawn.on, DateTime(2026, 6, 3));
  });

  test('morosos: filtro de bajas solo si se elige', () async {
    final requests = <RequestOptions>[];
    final repository = ReportsRepository(
      fakeDio(_routes(), requests: requests),
      InMemorySessionStorage()..organization = 'jakare',
    );

    await repository.delinquents();
    await repository.delinquents(withdrawn: WithdrawnFilter.only);
    await repository.delinquents(withdrawn: WithdrawnFilter.exclude);

    expect(requests.map((r) => r.queryParameters['withdrawn']), [
      null,
      'only',
      'exclude',
    ]);
  });

  test('el balance pide el mes completo', () async {
    final requests = <RequestOptions>[];
    final repository = ReportsRepository(
      fakeDio(_routes(), requests: requests),
      InMemorySessionStorage()..organization = 'jakare',
    );

    await repository.balance(DateTime(2026, 2, 15));

    expect(requests.single.queryParameters, {
      'from': '2026-02-01',
      'to': '2026-02-28',
    });
  });

  test('sin permiso la API responde 403', () async {
    final repository = ReportsRepository(
      fakeDio({
        'GET /reports/balances': (options) =>
            throw apiError(options, 403, {'message': 'No autorizado.'}),
      }),
      InMemorySessionStorage(),
    );

    expect(
      repository.balances(),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          403,
        ),
      ),
    );
  });

  testWidgets('balance del mes, cambio de mes y descargas', (tester) async {
    // Pantalla alta: el balance entra completo sin scrollear.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <Uri>[];
    await tester.pumpWidget(_app(const ReportsScreen(), opened: opened));
    await tester.pumpAndSettle();

    expect(find.text('Septiembre 2026'), findsOneWidget);
    expect(find.text('₲ 1.850.000'), findsWidgets);
    expect(find.text('Alquiler de cancha'), findsOneWidget);
    expect(find.text('Gastos pendientes de pago'), findsOneWidget);
    expect(find.text('Otros movimientos'), findsOneWidget);

    await tester.tap(find.byTooltip('Mes anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Agosto 2026'), findsOneWidget);

    // La pestaña vecina también se construye: se toca el PDF del balance.
    await tester.tap(find.text('PDF').first);
    expect(opened.single.path, '/informes/balance.pdf');
  });

  testWidgets('saldos y morosos con llamar', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(_app(const ReportsScreen(), opened: opened));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saldos'));
    await tester.pumpAndSettle();
    expect(find.text('Familia Benítez'), findsOneWidget);
    expect(
      find.text('Mateo, Sofía · Vencido ₲ 150.000 · Próximas ₲ 200.000'),
      findsOneWidget,
    );
    expect(find.text('Próximas cuotas'), findsOneWidget);
    expect(find.text('Sofía: baja el 03/06/2026'), findsOneWidget);

    await tester.tap(find.text('Morosos'));
    await tester.pumpAndSettle();
    expect(find.text('Familia Ortiz'), findsOneWidget);
    expect(
      find.text('Diego\n3 meses · desde 10/07/2026\nRosa Ortiz'),
      findsOneWidget,
    );

    await tester.tap(find.text('Llamar'));
    expect(opened.single.toString(), 'tel:0981222333');
  });

  testWidgets('morosos: solo los dados de baja, con la fecha', (tester) async {
    await tester.pumpWidget(_app(const ReportsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morosos'));
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    await tester.tap(find.text('Dados de baja'));
    await tester.pumpAndSettle();

    expect(find.text('Familia Ortiz'), findsNothing);
    expect(find.text('Familia Zárate'), findsOneWidget);
    expect(find.text('Matías: baja el 03/06/2026'), findsOneWidget);
  });

  testWidgets('sin permiso: no hay tarjeta y la pantalla lo dice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: ReportsCard()), permissions: const []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Informes'), findsNothing);

    await tester.pumpWidget(_app(const ReportsScreen(), permissions: const []));
    await tester.pumpAndSettle();
    expect(find.text('No tenés acceso a los informes.'), findsOneWidget);
  });

  testWidgets('la tarjeta del inicio resume caja y morosos', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: ReportsCard())));
    await tester.pumpAndSettle();

    expect(find.text('Informes'), findsOneWidget);
    expect(
      find.text('Caja y bancos ₲ 1.850.000 · Morosos ₲ 450.000'),
      findsOneWidget,
    );
  });
}
