import 'dart:typed_data';

import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/billing/data/amount_hint.dart';
import 'package:academia_app/features/billing/data/models.dart';
import 'package:academia_app/features/billing/presentation/account_summary_card.dart';
import 'package:academia_app/features/billing/presentation/balance_screen.dart';
import 'package:academia_app/features/payment_reports/data/models.dart';
import 'package:academia_app/features/payment_reports/data/payment_reports_repository.dart';
import 'package:academia_app/features/payment_reports/data/report_form.dart';
import 'package:academia_app/features/payment_reports/presentation/payment_reports_card.dart';
import 'package:academia_app/features/payment_reports/presentation/payment_reports_screen.dart';
import 'package:academia_app/features/payment_reports/presentation/report_payment_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';
import '../billing/account_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions)>;

/// Comprobante según el contrato (`API_V1.md`, «Comprobantes de transferencia»).
Map<String, Object?> reportJson({
  int id = 31,
  String status = 'pendiente',
  String? reason,
  bool forReviewer = false,
}) => {
  'id': id,
  'amount': 210000,
  'paid_on': '2026-10-02',
  'reference': 'Transf. 99812',
  'notes': null,
  'status': status,
  'status_label': status,
  'rejection_reason': reason,
  'money_account': {'id': 2, 'name': 'Banco Itaú'},
  'charges': [
    {
      'id': 501,
      'description': 'Cuota septiembre 2026',
      'student_first_name': 'Sofía',
      'pending_amount': 60000,
    },
    {
      'id': 400,
      'description': 'Cuota agosto 2026',
      'student_first_name': 'Mateo',
      'pending_amount': 150000,
    },
  ],
  'proof_url': 'https://api.test/comprobantes-de-pago/$id?signature=x',
  'proof_name': 'comprobante.jpg',
  'created_at': '2026-10-02T21:14:00-03:00',
  'reviewed_at': null,
  'receipt_number': status == 'aprobado' ? '000124' : null,
  'receipt_url': status == 'aprobado'
      ? 'https://api.test/recibos/91?signature=y'
      : null,
  if (forReviewer) ...{
    'family': {
      'id': 7,
      'name': 'Familia Benítez',
      'students': ['Sofía', 'Mateo'],
    },
    'reported_by': 'Ana Benítez',
    'pending_balance': 270000,
    'money_accounts': [
      {'id': 1, 'name': 'Caja'},
      {'id': 2, 'name': 'Banco Itaú'},
    ],
  },
};

const _transferAccounts = [
  {
    'id': 2,
    'name': 'Banco Itaú',
    'details': 'Cuenta corriente 123456\nTitular: Club Jakare',
  },
];

Map<String, Object?> _account({List<Map<String, Object?>>? reports}) => {
  ...accountJson(),
  'transfer_accounts': _transferAccounts,
  'payment_reports': reports ?? const [],
  'pending_reports_amount':
      reports?.where((r) => r['status'] == 'pendiente').length == 1
      ? 210000
      : 0,
};

Routes _routes({
  List<String> permissions = const [],
  List<Map<String, Object?>>? reports,
}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Ana',
      'email': 'ana@test.com',
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
  'GET /account': (_) => {'data': _account(reports: reports)},
};

PickedProof _proof({String name = 'comprobante.jpg', int size = 2048}) =>
    PickedProof(name: name, bytes: Uint8List(size));

Widget _app(
  Routes routes,
  Widget home, {
  List<RequestOptions>? requests,
  List<Uri>? opened,
  PickedProof? picked,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
    todayProvider.overrideWithValue(DateTime(2026, 10, 3)),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened?.add(uri);
      return true;
    }),
    proofPickerProvider.overrideWithValue(() async => picked),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/estado-de-cuenta',
          builder: (_, _) => const Scaffold(body: Text('Estado de cuenta')),
        ),
        GoRoute(
          path: '/estado-de-cuenta/informar-pago',
          builder: (_, _) => const Scaffold(body: Text('Informar pago')),
        ),
        GoRoute(
          path: '/comprobantes',
          builder: (_, _) => const Scaffold(body: Text('Comprobantes')),
        ),
      ],
    ),
  ),
);

/// Las tarjetas no dibujan nada mientras cargan: se avanza el reloj hasta
/// que terminan las peticiones encadenadas.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

/// El formulario es una lista perezosa: hay que desplazarse para construir lo de abajo.
Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  group('modelos', () {
    test('lee el comprobante y los campos nuevos de la cuenta', () {
      final account = Account.fromJson(
        _account(
          reports: [
            reportJson(),
            reportJson(id: 30, status: 'rechazado', reason: 'No se lee.'),
            reportJson(id: 29, status: 'aprobado'),
          ],
        ),
      );

      expect(account.transferAccounts.single.name, 'Banco Itaú');
      expect(account.pendingReportsAmount, 210000);
      expect(account.paymentReports, hasLength(3));
      expect(account.openReports.map((r) => r.id), [31, 30]);
      expect(account.chargesUnderReview, {501, 400});

      final report = account.paymentReports.first;
      expect(report.status, PaymentReportStatus.pending);
      expect(report.status.label, 'En revisión');
      expect(report.paidOn, DateTime(2026, 10, 2));
      expect(report.moneyAccount?.id, 2);
      expect(
        report.chargesSummary,
        'Sofía · Cuota septiembre 2026, Mateo · Cuota agosto 2026',
      );
      expect(account.paymentReports[2].receiptNumber, '000124');
    });

    test('sin los campos nuevos sigue funcionando', () {
      final account = Account.fromJson(accountJson());

      expect(account.transferAccounts, isEmpty);
      expect(account.paymentReports, isEmpty);
      expect(account.pendingReportsAmount, 0);
    });

    test('quien valida recibe la familia y las cuentas', () {
      final report = PaymentReport.fromJson(reportJson(forReviewer: true));

      expect(report.family?.name, 'Familia Benítez');
      expect(report.family?.students, ['Sofía', 'Mateo']);
      expect(report.reportedBy, 'Ana Benítez');
      expect(report.pendingBalance, 270000);
      expect(report.moneyAccounts.map((a) => a.name), ['Caja', 'Banco Itaú']);
    });

    test('las cuotas en revisión no se vuelven a informar', () {
      final account = Account.fromJson({
        ...accountJson(),
        'payment_reports': [
          {
            ...reportJson(),
            'charges': [
              {
                'id': 400,
                'description': 'Cuota agosto 2026',
                'student_first_name': 'Mateo',
                'pending_amount': 150000,
              },
            ],
          },
        ],
      });

      final charges = reportableCharges(account);
      expect(charges.map((c) => c.id), [501]);
      expect(suggestedAmount(charges), 60000);
    });

    test(
      'un rechazado ya resuelto queda como historial (lo decide la API)',
      () {
        final account = Account.fromJson(
          _account(
            reports: [
              {...reportJson(id: 32, status: 'aprobado'), 'open': false},
              {
                ...reportJson(
                  id: 31,
                  status: 'rechazado',
                  reason: 'No se lee.',
                ),
                'open': false,
              },
              {
                ...reportJson(id: 30, status: 'rechazado', reason: 'Borroso.'),
                'open': true,
              },
              {...reportJson(id: 29), 'open': true},
            ],
          ),
        );

        expect(account.openReports.map((r) => r.id), [30, 29]);
        expect(account.paymentReports, hasLength(4));
      },
    );

    test('las cuotas a informar van de la más vieja a la más nueva', () {
      final account = Account.fromJson({
        ...accountJson(),
        'charges': [
          upcomingChargeJson(),
          {...chargeJson(id: 2), 'due_on': '2026-10-10'},
          {...chargeJson(id: 1), 'due_on': '2026-08-10', 'status': 'vencido'},
        ],
      });

      expect(reportableCharges(account).map((c) => c.id), [1, 2, 700]);
    });
  });

  group('validaciones', () {
    test('monto', () {
      expect(validateReportAmount(''), 'Ingresá el monto que transferiste.');
      expect(validateReportAmount('0'), 'El monto tiene que ser mayor a cero.');
      expect(validateReportAmount('210000'), isNull);
    });

    test('comprobante', () {
      expect(
        validateProof(null),
        'Adjuntá el comprobante de la transferencia.',
      );
      expect(validateProof(_proof()), isNull);
      expect(validateProof(_proof(name: 'recibo.PDF')), isNull);
      expect(
        validateProof(_proof(name: 'planilla.xlsx')),
        'El comprobante tiene que ser una foto o un PDF.',
      );
      expect(
        validateProof(_proof(size: maxProofBytes + 1)),
        'El comprobante pesa más de 5 MB.',
      );
    });

    test('aviso del monto: parcial o lo que sobra', () {
      expect(reportAmountHint(210000, 210000), isNull);
      expect(reportAmountHint(null, 210000), isNull);
      expect(
        reportAmountHint(150000, 210000),
        'Pago parcial: faltan ₲ 60.000 para saldar lo elegido.',
      );
      expect(
        reportAmountHint(300000, 210000),
        'Sobran ₲ 90.000: quedan a favor.',
      );
      expect(reportAmountHint(50000, 0), startsWith('Sin cuotas elegidas'));
    });

    test('el monto sigue lo elegido hasta que se cambia a mano', () {
      expect(amountEditedByHand('210000', 210000), isFalse);
      expect(amountEditedByHand('', 210000), isFalse);
      expect(amountEditedByHand('300000', 210000), isTrue);
    });

    test('motivo del rechazo', () {
      expect(validateRejectionReason('  '), 'Contá por qué no lo aprobás.');
      expect(validateRejectionReason('No se lee.'), isNull);
    });
  });

  group('repositorio', () {
    test('informa el pago en multipart con las cuotas y el archivo', () async {
      final requests = <RequestOptions>[];
      final repository = PaymentReportsRepository(
        fakeDio({
          'POST /payment-reports': (_) => {'data': reportJson()},
        }, requests: requests),
        InMemorySessionStorage()..organization = 'jakare',
      );

      final report = await repository.report(
        PaymentReportDraft(
          amount: 210000,
          paidOn: DateTime(2026, 10, 2),
          proof: _proof(),
          chargeIds: const [501, 400],
          moneyAccountId: 2,
          reference: ' Transf. 99812 ',
        ),
      );

      expect(report.id, 31);
      final form = requests.single.data as FormData;
      expect(
        form.fields.map((f) => '${f.key}=${f.value}'),
        containsAll([
          'amount=210000',
          'paid_on=2026-10-02',
          'charge_ids[]=501',
          'charge_ids[]=400',
          'money_account_id=2',
          'reference=Transf. 99812',
        ]),
      );
      expect(form.files.single.key, 'proof');
      expect(form.files.single.value.filename, 'comprobante.jpg');
    });

    test('lista, aprueba, rechaza y retira', () async {
      final requests = <RequestOptions>[];
      final repository = PaymentReportsRepository(
        fakeDio({
          'GET /payment-reports': (_) => {
            'data': [reportJson(forReviewer: true)],
          },
          'POST /payment-reports/31/approve': (_) => {
            'data': reportJson(status: 'aprobado'),
          },
          'POST /payment-reports/31/reject': (_) => {
            'data': reportJson(status: 'rechazado', reason: 'No se lee.'),
          },
          'DELETE /payment-reports/31': (_) => null,
        }, requests: requests),
        InMemorySessionStorage()..organization = 'jakare',
      );

      expect(await repository.list(), hasLength(1));
      expect(requests.last.queryParameters, {'status': 'pendiente'});
      await repository.list(all: true);
      expect(requests.last.queryParameters, {'status': 'todos'});

      final approved = await repository.approve(
        31,
        moneyAccountId: 2,
        receivedOn: DateTime(2026, 10, 2),
        amount: 200000,
      );
      expect(approved.report.receiptNumber, '000124');
      expect(approved.notice, isNull);
      expect(requests.last.data, {
        'money_account_id': 2,
        'received_on': '2026-10-02',
        'amount': 200000,
      });

      await repository.approve(31);
      expect(requests.last.data, <String, Object?>{});

      final rejected = await repository.reject(31, ' No se lee. ');
      expect(rejected.rejectionReason, 'No se lee.');
      expect(requests.last.data, {'reason': 'No se lee.'});

      await repository.withdraw(31);
      expect(requests.last.method, 'DELETE');
    });

    test('sin organización no pide la lista', () async {
      final repository = PaymentReportsRepository(
        fakeDio({}),
        InMemorySessionStorage(),
      );

      expect(await repository.list(), isEmpty);
    });
  });

  group('tutor', () {
    testWidgets('el estado de cuenta ofrece informar y muestra lo informado', (
      tester,
    ) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          _routes(
            reports: [
              reportJson(),
              reportJson(id: 30, status: 'rechazado', reason: 'No se lee.'),
            ],
          ),
          const BalanceScreen(),
          opened: opened,
        ),
      );
      await _settle(tester);

      expect(find.text('En revisión ₲ 210.000'), findsOneWidget);
      expect(find.text('Comprobantes informados'), findsOneWidget);
      expect(find.text('Transferencia del 02/10/2026'), findsNWidgets(2));
      expect(find.text('Motivo: No se lee.'), findsOneWidget);
      expect(find.text('Retirar'), findsOneWidget);

      await tester.tap(find.text('Ver comprobante').first);
      expect(
        opened.single.toString(),
        'https://api.test/comprobantes-de-pago/31?signature=x',
      );

      await tester.tap(find.text('Informar transferencia'));
      await tester.pumpAndSettle();
      expect(find.text('Informar pago'), findsOneWidget);
    });

    testWidgets('retirar un comprobante en revisión', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(reports: [reportJson()]),
            'DELETE /payment-reports/31': (_) => null,
          },
          const BalanceScreen(),
          requests: requests,
        ),
      );
      await _settle(tester);

      await tester.ensureVisible(find.text('Retirar'));
      await tester.tap(find.text('Retirar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retirar'));
      await tester.pumpAndSettle();

      expect(
        requests.map((r) => '${r.method} ${r.path}'),
        contains('DELETE /payment-reports/31'),
      );
    });

    testWidgets('el inicio muestra lo que está en revisión', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._routes(),
          'GET /account': (_) => {
            'data': {
              ..._account(reports: [reportJson()]),
              'overdue': 0,
            },
          },
        }, const Scaffold(body: AccountSummaryCard())),
      );
      await _settle(tester);

      expect(find.text('En revisión ₲ 210.000'), findsOneWidget);
    });

    testWidgets('informar: datos, cuotas elegidas y monto sugerido', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(),
            'POST /payment-reports': (_) => {'data': reportJson()},
          },
          const ReportPaymentScreen(),
          requests: requests,
          picked: _proof(),
        ),
      );
      await _settle(tester);

      expect(find.text('Datos para transferir'), findsOneWidget);
      expect(
        find.text('Cuenta corriente 123456\nTitular: Club Jakare'),
        findsOneWidget,
      );
      // Las dos cuotas impagas, elegidas: ₲ 60.000 + ₲ 150.000.
      expect(find.text('Sofía · Cuota septiembre 2026'), findsOneWidget);
      expect(find.text('Mateo · Cuota agosto 2026'), findsOneWidget);
      expect(find.text('210000'), findsOneWidget);
      expect(find.text('03/10/2026'), findsOneWidget);

      // Sin la de Sofía, el monto baja.
      await tester.tap(find.text('Sofía · Cuota septiembre 2026'));
      await tester.pump();
      expect(find.text('150000'), findsOneWidget);

      // Sin comprobante no se manda.
      await _scrollTo(tester, find.text('Enviar comprobante'));
      await tester.tap(find.text('Enviar comprobante'));
      await tester.pump();
      expect(
        find.text('Adjuntá el comprobante de la transferencia.'),
        findsOneWidget,
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      await _scrollTo(tester, find.text('Adjuntar comprobante'));
      await tester.tap(find.text('Adjuntar comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('comprobante.jpg'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'N° de operación (opcional)'),
        '99812',
      );
      await _scrollTo(tester, find.text('Enviar comprobante'));
      await tester.tap(find.text('Enviar comprobante'));
      await tester.pumpAndSettle();

      final form =
          requests.firstWhere((r) => r.method == 'POST').data as FormData;
      expect(
        form.fields.map((f) => '${f.key}=${f.value}'),
        containsAll([
          'amount=150000',
          'paid_on=2026-10-03',
          'charge_ids[]=400',
          'money_account_id=2',
          'reference=99812',
        ]),
      );
      expect(form.fields.where((f) => f.key == 'charge_ids[]'), hasLength(1));
      expect(find.text('Estado de cuenta'), findsOneWidget);
      expect(
        find.text('Listo. Te avisamos cuando lo revisen.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'tildar y destildar completa el monto aunque el campo repita el valor',
      (tester) async {
        await tester.pumpWidget(
          _app(_routes(), const ReportPaymentScreen(), picked: _proof()),
        );
        await _settle(tester);

        // En la web el campo puede avisar un cambio con el mismo valor: no lo congela.
        await tester.enterText(
          find.byKey(const Key('report-amount')),
          '210000',
        );
        await tester.tap(find.text('Sofía · Cuota septiembre 2026'));
        await tester.pump();
        expect(find.text('150000'), findsOneWidget);

        await tester.tap(find.text('Sofía · Cuota septiembre 2026'));
        await tester.pump();
        expect(find.text('210000'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('report-amount')),
          '300000',
        );
        await tester.pump();
        expect(find.text('Sobran ₲ 90.000: quedan a favor.'), findsOneWidget);
      },
    );

    testWidgets('el error del monto se va cuando el monto cambia (N6)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_routes(), const ReportPaymentScreen(), picked: _proof()),
      );
      await _settle(tester);

      // Sin cuotas elegidas el monto queda vacío y "Enviar" marca el error.
      await tester.tap(find.text('Sofía · Cuota septiembre 2026'));
      await tester.tap(find.text('Mateo · Cuota agosto 2026'));
      await tester.pump();
      expect(find.text('150000'), findsNothing);
      await _scrollTo(tester, find.text('Enviar comprobante'));
      await tester.tap(find.text('Enviar comprobante'));
      await tester.pump();
      expect(find.text('Ingresá el monto que transferiste.'), findsOneWidget);

      // Al tildar una cuota el monto se completa y el error se va.
      await _scrollTo(tester, find.text('Mateo · Cuota agosto 2026'));
      await tester.tap(find.text('Mateo · Cuota agosto 2026'));
      await tester.pump();
      expect(find.text('150000'), findsOneWidget);
      expect(find.text('Ingresá el monto que transferiste.'), findsNothing);

      // Y lo mismo escribiéndolo a mano.
      await tester.enterText(find.byKey(const Key('report-amount')), '');
      await tester.pump();
      await _scrollTo(tester, find.text('Enviar comprobante'));
      await tester.tap(find.text('Enviar comprobante'));
      await tester.pump();
      expect(find.text('Ingresá el monto que transferiste.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('report-amount')), '90000');
      await tester.pump();
      expect(find.text('Ingresá el monto que transferiste.'), findsNothing);
    });

    testWidgets('el monto cambiado a mano no se pisa', (tester) async {
      await tester.pumpWidget(
        _app(_routes(), const ReportPaymentScreen(), picked: _proof()),
      );
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('report-amount')), '100000');
      await tester.tap(find.text('Sofía · Cuota septiembre 2026'));
      await tester.pump();

      expect(find.text('100000'), findsOneWidget);
    });

    testWidgets('muestra el error de la API', (tester) async {
      await tester.pumpWidget(
        _app(
          {
            ..._routes(),
            'POST /payment-reports': (options) => throw apiError(options, 422, {
              'message': 'x',
              'errors': {
                'charge_ids': [
                  'Ya informaste un pago para «Cuota agosto 2026»; esperá a que lo revisen.',
                ],
              },
            }),
          },
          const ReportPaymentScreen(),
          picked: _proof(),
        ),
      );
      await _settle(tester);

      await _scrollTo(tester, find.text('Adjuntar comprobante'));
      await tester.tap(find.text('Adjuntar comprobante'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Enviar comprobante'));
      await tester.tap(find.text('Enviar comprobante'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ya informaste un pago para «Cuota agosto 2026»; esperá a que lo revisen.',
        ),
        findsOneWidget,
      );
    });
  });

  group('quien valida', () {
    Routes reviewerRoutes({List<RequestOptions>? log}) => {
      ..._routes(permissions: const ['review_payment_reports']),
      'GET /payment-reports': (options) => {
        'data': options.queryParameters['status'] == 'todos'
            ? [
                reportJson(forReviewer: true),
                reportJson(id: 29, status: 'aprobado', forReviewer: true),
              ]
            : [reportJson(forReviewer: true)],
      },
      'POST /payment-reports/31/approve': (_) => {
        'data': reportJson(status: 'aprobado', forReviewer: true),
      },
      'POST /payment-reports/31/reject': (_) => {
        'data': reportJson(
          status: 'rechazado',
          reason: 'No se lee.',
          forReviewer: true,
        ),
      },
    };

    testWidgets('la tarjeta del inicio cuenta los pendientes', (tester) async {
      await tester.pumpWidget(
        _app(reviewerRoutes(), const Scaffold(body: PaymentReportsCard())),
      );
      await _settle(tester);

      expect(find.text('Comprobantes de pago'), findsOneWidget);
      expect(find.text('1 para revisar · ₲ 210.000'), findsOneWidget);

      await tester.tap(find.text('Comprobantes de pago'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobantes'), findsOneWidget);
    });

    testWidgets('sin el permiso no hay tarjeta', (tester) async {
      await tester.pumpWidget(
        _app(_routes(), const Scaffold(body: PaymentReportsCard())),
      );
      await _settle(tester);

      expect(find.text('Comprobantes de pago'), findsNothing);
    });

    testWidgets('aprueba con la cuenta informada y muestra el recibo', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          reviewerRoutes(),
          const PaymentReportsScreen(),
          requests: requests,
          opened: opened,
        ),
      );
      await _settle(tester);

      expect(find.text('Familia Benítez'), findsOneWidget);
      expect(find.text('Sofía, Mateo · Informó Ana Benítez'), findsOneWidget);
      expect(
        find.text(
          'Transferencia del 02/10/2026 · Banco Itaú · Ref. Transf. 99812',
        ),
        findsOneWidget,
      );
      expect(find.text('La familia debe hoy ₲ 270.000'), findsOneWidget);

      await tester.tap(find.text('Ver comprobante'));
      expect(opened.single.path, '/comprobantes-de-pago/31');

      await tester.tap(find.text('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar pago'), findsOneWidget);
      expect(find.text('Banco Itaú'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Aprobar').last);
      await tester.pumpAndSettle();

      final approve = requests.firstWhere(
        (r) => r.path == '/payment-reports/31/approve',
      );
      expect(approve.data, {
        'money_account_id': 2,
        'received_on': '2026-10-02',
        'amount': 210000,
      });
      expect(find.text('Pago aprobado: recibo N° 000124.'), findsOneWidget);
    });

    testWidgets('rechazar pide el motivo', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          reviewerRoutes(),
          const PaymentReportsScreen(),
          requests: requests,
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pump();
      expect(find.text('Contá por qué no lo aprobás.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'No se lee.');
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();

      final reject = requests.firstWhere(
        (r) => r.path == '/payment-reports/31/reject',
      );
      expect(reject.data, {'reason': 'No se lee.'});
      expect(
        find.text('Comprobante rechazado. Le avisamos al tutor.'),
        findsOneWidget,
      );
    });

    testWidgets('en "Todos" se ven los revisados con su recibo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(reviewerRoutes(), const PaymentReportsScreen()),
      );
      await _settle(tester);

      await tester.tap(find.text('Todos'));
      await _settle(tester);

      expect(find.text('Aprobado · recibo N° 000124'), findsOneWidget);
      expect(find.text('Ver recibo'), findsOneWidget);
    });
  });
}
