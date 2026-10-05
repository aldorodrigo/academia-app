import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/cash/data/cash_form.dart';
import 'package:academia_app/features/cash/data/cash_repository.dart';
import 'package:academia_app/features/cash/data/models.dart';
import 'package:academia_app/features/cash/presentation/cash_box_screen.dart';
import 'package:academia_app/features/cash/presentation/cash_overview_screen.dart';
import 'package:academia_app/features/cash/presentation/collect_screen.dart';
import 'package:academia_app/features/cash/presentation/collect_students_screen.dart';
import 'package:academia_app/features/payment_reports/data/models.dart';

import 'dart:typed_data';

import 'package:academia_app/features/payment_reports/data/report_form.dart';
import 'package:academia_app/features/payment_reports/presentation/payment_report_tile.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';
import '../billing/account_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions)>;

/// Respuestas según el contrato (`API_V1.md`, «Cobro en efectivo y caja del técnico»).
Map<String, Object?> _collectable({
  int id = 400,
  String firstName = 'Mateo',
  String description = 'Cuota agosto 2026',
  String status = 'vencido',
  int pending = 150000,
  int? settle,
  bool underReview = false,
  bool upcoming = false,
  Map<String, Object?>? early,
}) => {
  ...chargeJson(
    id: id,
    studentId: firstName == 'Mateo' ? 12 : 13,
    firstName: firstName,
    status: status,
    description: description,
    base: pending,
    total: pending,
    adjustments: const [],
  ),
  'pending_amount': pending,
  'paid_amount': 0,
  'is_upcoming': upcoming,
  'settle_amount': settle ?? pending,
  'early_payment': early,
  'under_review': underReview,
};

Map<String, Object?> _target({
  List<Map<String, Object?>>? charges,
  Map<String, Object?>? box = const {
    'id': 9,
    'name': 'Caja de Juan Pérez',
    'balance': 300000,
    'active': true,
  },
  int credit = 0,
  bool approves = false,
}) => {
  'student': {'id': 12, 'full_name': 'Mateo Benítez'},
  'family': {
    'id': 7,
    'name': 'Familia Benítez',
    'students': ['Mateo', 'Sofía'],
  },
  'guardians': [
    {'id': 3, 'full_name': 'Ana Benítez'},
    {'id': 4, 'full_name': 'Carlos Benítez'},
  ],
  'credit': credit,
  'charges':
      charges ??
      [
        _collectable(),
        _collectable(
          id: 501,
          firstName: 'Sofía',
          description: 'Cuota octubre 2026',
          status: 'pendiente',
          pending: 150000,
          settle: 135000,
          early: {'amount': 15000, 'label': 'Pronto pago −10 %'},
        ),
        _collectable(
          id: 502,
          firstName: 'Sofía',
          description: 'Cuota septiembre 2026',
          pending: 60000,
          underReview: true,
        ),
        _collectable(
          id: 700,
          description: 'Cuota noviembre 2026',
          status: 'pendiente',
          upcoming: true,
        ),
      ],
  'cash_box': box,
  'transfer_accounts': [
    {'id': 2, 'name': 'Banco Itaú'},
    {'id': 3, 'name': 'Ueno'},
  ],
  'approves_transfers': approves,
};

/// Comprobante registrado por el club (`POST collections/transfers`).
Map<String, Object?> _staffReport({String status = 'pendiente'}) => {
  'id': 40,
  'amount': 135000,
  'paid_on': '2026-10-03',
  'reference': '99812',
  'notes': null,
  'status': status,
  'status_label': status,
  'rejection_reason': null,
  'money_account': {'id': 3, 'name': 'Ueno'},
  'charges': [
    {
      'id': 501,
      'description': 'Cuota octubre 2026',
      'student_first_name': 'Sofía',
      'pending_amount': 150000,
    },
  ],
  'proof_url': 'https://api.test/comprobantes-de-pago/40?signature=x',
  'proof_name': 'captura.jpg',
  'created_at': '2026-10-04T10:00:00-03:00',
  'reviewed_at': null,
  'receipt_number': status == 'aprobado' ? '000125' : null,
  'receipt_url': status == 'aprobado'
      ? 'https://api.test/recibos/125?signature=y'
      : null,
  'registered_by': 'Juan Pérez',
};

Map<String, Object?> _payment({int amount = 285000}) => {
  'id': 124,
  'receipt_number': '000124',
  'received_on': '2026-10-04',
  'amount': amount,
  'method': 'efectivo',
  'method_label': 'Efectivo',
  'voided': false,
  'receipt_url': 'https://api.test/recibos/124?signature=z',
  'allocations': const [],
  'credit_generated': 0,
};

Map<String, Object?> _deposit({
  int id = 4,
  String status = 'pendiente',
  String? reason,
}) => {
  'id': id,
  'amount': 300000,
  'deposited_on': '2026-10-04',
  'money_account': {'id': 2, 'name': 'Banco Itaú'},
  'reference': 'Boleta 5521',
  'notes': null,
  'status': status,
  'status_label': status,
  'rejection_reason': reason,
  'created_at': '2026-10-04T19:02:00-03:00',
  'reviewed_at': null,
  'holder': {'id': 5, 'name': 'Juan Pérez'},
};

Map<String, Object?> _cashBox({
  int balance = 585000,
  int pending = 300000,
  bool active = true,
  List<Map<String, Object?>>? deposits,
}) => {
  'id': 9,
  'name': 'Caja de Juan Pérez',
  'active': active,
  'balance': balance,
  'pending_deposits': pending,
  'available': balance - pending,
  'movements': [
    {
      'id': 77,
      'occurred_on': '2026-10-04',
      'description': 'Recibo N° 000124 · Familia Benítez',
      'amount': 285000,
      'kind': 'cobro',
      'receipt_url': 'https://api.test/recibos/124?signature=z',
    },
    {
      'id': 70,
      'occurred_on': '2026-10-01',
      'description': 'Transferencia a Banco Itaú',
      'amount': -100000,
      'kind': 'deposito',
      'receipt_url': null,
    },
  ],
  'deposits': deposits ?? [_deposit()],
  'deposit_accounts': [
    {'id': 1, 'name': 'Caja', 'type': 'caja'},
    {'id': 2, 'name': 'Banco Itaú', 'type': 'banco'},
  ],
};

Map<String, Object?> _overview() => {
  'total': 885000,
  'boxes': [
    {
      'id': 9,
      'name': 'Caja de Juan Pérez',
      'holder': {'id': 5, 'name': 'Juan Pérez', 'active': true},
      'balance': 585000,
      'pending_deposits': 300000,
      'last_movement_on': '2026-10-04',
    },
    {
      'id': 10,
      'name': 'Caja de Pedro Gómez',
      'holder': {'id': 6, 'name': 'Pedro Gómez', 'active': false},
      'balance': 300000,
      'pending_deposits': 0,
      'last_movement_on': '2026-09-20',
    },
  ],
  'deposits': [_deposit()],
};

const _students = [
  {
    'id': 12,
    'full_name': 'Mateo Benítez',
    'photo_url': null,
    'groups': ['Sub-10'],
    'family': 'Familia Benítez',
    'due_now': 300000,
    'overdue': 150000,
  },
  {
    'id': 15,
    'full_name': 'Lucía Núñez',
    'photo_url': null,
    'groups': ['Sub-10'],
    'family': 'Familia Núñez',
    'due_now': 0,
    'overdue': 0,
  },
];

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
    todayProvider.overrideWithValue(DateTime(2026, 10, 4)),
    urlLauncherProvider.overrideWithValue((uri) async {
      opened?.add(uri);
      return true;
    }),
    collectionRequestIdProvider.overrideWithValue(() => 'req-0001'),
    proofPickerProvider.overrideWithValue(() async => picked),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/cobrar',
          builder: (_, _) => const Scaffold(body: Text('Lista de cobro')),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => CollectScreen(
                studentId: int.parse(state.pathParameters['id']!),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/mi-caja',
          builder: (_, _) => const Scaffold(body: Text('Mi caja')),
        ),
        GoRoute(
          path: '/inicio',
          builder: (_, _) => const Scaffold(body: Text('Inicio')),
        ),
      ],
    ),
  ),
);

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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

/// El formulario es una lista perezosa: se desplaza hasta construirlo y
/// después lo centra para que el toque no caiga en el borde.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('modelos', () {
    test('lee el alumno a cobrar con la familia y las cuotas', () {
      final target = CollectionTarget.fromJson(_target());

      expect(target.studentName, 'Mateo Benítez');
      expect(target.familyName, 'Familia Benítez');
      expect(target.familyStudents, ['Mateo', 'Sofía']);
      expect(target.guardians.map((g) => g.fullName), [
        'Ana Benítez',
        'Carlos Benítez',
      ]);
      expect(target.cashBox?.name, 'Caja de Juan Pérez');
      expect(target.canCollect, isTrue);
      expect(target.dueCharges.map((c) => c.id), [400, 501, 502]);
      expect(target.upcomingCharges.map((c) => c.id), [700]);

      final early = target.charges[1];
      expect(early.settleAmount, 135000);
      expect(early.earlyPaymentAmount, 15000);
      expect(early.earlyPaymentLabel, 'Pronto pago −10 %');
      expect(target.charges[2].underReview, isTrue);
    });

    test('trae las cuentas para la transferencia y si se aprueba al toque', () {
      final target = CollectionTarget.fromJson(_target(approves: true));

      expect(target.transferAccounts.map((a) => a.name), [
        'Banco Itaú',
        'Ueno',
      ]);
      expect(target.approvesTransfers, isTrue);
      expect(
        CollectionTarget.fromJson({
          ..._target(),
          'transfer_accounts': null,
          'approves_transfers': null,
        }).approvesTransfers,
        isFalse,
      );
    });

    test('el comprobante dice quién lo registró', () {
      final report = PaymentReport.fromJson(_staffReport());

      expect(report.registeredBy, 'Juan Pérez');
    });

    test('sin caja todavía puede cobrar; con la caja cerrada, no', () {
      expect(CollectionTarget.fromJson(_target(box: null)).canCollect, isTrue);
      expect(
        CollectionTarget.fromJson(
          _target(
            box: {'id': 9, 'name': 'Caja', 'balance': 0, 'active': false},
          ),
        ).canCollect,
        isFalse,
      );
    });

    test('lee la caja, los movimientos y los depósitos', () {
      final box = CashBox.fromJson(_cashBox());

      expect(box.balance, 585000);
      expect(box.available, 285000);
      expect(box.canDeposit, isTrue);
      expect(box.movements.first.kind, CashMovementKind.collection);
      expect(box.movements.last.kind, CashMovementKind.deposit);
      expect(box.deposits.single.status, CashDepositStatus.pending);
      expect(box.deposits.single.status.label, 'Por confirmar');
      expect(box.deposits.single.account?.name, 'Banco Itaú');
      expect(box.depositAccounts.map((a) => a.name), ['Caja', 'Banco Itaú']);

      expect(CashBox.fromJson(_cashBox(pending: 585000)).canDeposit, isFalse);
      expect(CashDepositStatus.parse('anulado').label, 'Anulado');
      expect(CashDepositStatus.parse('raro'), CashDepositStatus.pending);
    });

    test('sin caja todavía', () {
      final box = CashBox.fromJson({
        'id': null,
        'name': null,
        'active': true,
        'balance': 0,
        'pending_deposits': 0,
        'available': 0,
        'movements': <Object>[],
        'deposits': <Object>[],
        'deposit_accounts': [
          {'id': 1, 'name': 'Caja', 'type': 'caja'},
        ],
      });

      expect(box.id, isNull);
      expect(box.canDeposit, isFalse);
    });

    test('quien valida ve las cajas y los depósitos', () {
      final overview = CashOverview.fromJson(_overview());

      expect(overview.total, 885000);
      expect(overview.boxes.first.holderName, 'Juan Pérez');
      expect(overview.boxes.last.holderActive, isFalse);
      expect(overview.boxes.first.lastMovementOn, DateTime(2026, 10, 4));
      expect(overview.deposits.single.holderName, 'Juan Pérez');
    });

    test('la búsqueda ignora mayúsculas y tildes', () {
      final student = CollectableStudent.fromJson(_students.first);

      expect(student.matches(''), isTrue);
      expect(student.matches('mateo'), isTrue);
      expect(student.matches('BENITEZ'), isTrue);
      expect(student.matches('lucía'), isFalse);
      expect(student.initials, 'MB');
    });
  });

  group('cobro', () {
    test('elige lo que hay que pagar ahora, sin lo que está en revisión ni las próximas', () {
      final target = CollectionTarget.fromJson(_target());

      expect(initialSelection(target), {400, 501});
      expect(
        suggestedCollectAmount(
          target.charges.where((c) => initialSelection(target).contains(c.id)),
        ),
        285000,
      );
    });

    test('avisa si el pago es parcial o si sobra', () {
      expect(collectHint(null, 150000), isNull);
      expect(collectHint(150000, 150000), isNull);
      expect(
        collectHint(100000, 150000),
        'Pago parcial: faltan ₲ 50.000 para saldar lo elegido.',
      );
      expect(
        collectHint(200000, 150000),
        'Sobran ₲ 50.000: quedan a favor de la familia.',
      );
      expect(collectHint(50000, 0), startsWith('Se aplica a lo que deba'));
    });

    test('validaciones', () {
      expect(validateCollectAmount(''), 'Ingresá el monto que cobraste.');
      expect(
        validateCollectAmount('0'),
        'El monto tiene que ser mayor a cero.',
      );
      expect(validateCollectAmount('150000'), isNull);

      expect(
        validateDepositAmount('', 285000),
        'Ingresá el monto que depositaste.',
      );
      expect(
        validateDepositAmount('0', 285000),
        'El monto tiene que ser mayor a cero.',
      );
      expect(
        validateDepositAmount('300000', 285000),
        'Tenés ₲ 285.000 para depositar.',
      );
      expect(validateDepositAmount('285000', 285000), isNull);
      expect(validateDepositAccount(null), 'Elegí dónde lo depositaste.');
      expect(validateDepositAccount(2), isNull);
      expect(validateDepositRejection(' '), 'Contale por qué no lo confirmás.');
      expect(validateDepositRejection('No llegó.'), isNull);
    });

    test('cada cobro tiene su identificador', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final next = container.read(collectionRequestIdProvider);

      final first = next();
      expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(next(), isNot(first));
    });
  });

  group('repositorio', () {
    test('alumnos, alumno, cobro y caja', () async {
      final requests = <RequestOptions>[];
      final repository = CashRepository(
        fakeDio({
          'GET /collections/students': (_) => {'data': _students},
          'GET /collections/students/12': (_) => {'data': _target()},
          'POST /collections': (_) => {
            'data': {
              'payment': _payment(),
              'applied': 285000,
              'credit': 0,
              'cash_box': {
                'id': 9,
                'name': 'Caja de Juan Pérez',
                'balance': 585000,
                'active': true,
              },
              'message': 'Cobrado ₲ 285.000. Recibo N° 000124.',
            },
          },
          'GET /me/cash-box': (_) => {'data': _cashBox()},
        }, requests: requests),
        InMemorySessionStorage()..organization = 'jakare',
      );

      expect(await repository.students(), hasLength(2));
      expect(requests.last.queryParameters, isEmpty);
      await repository.students(search: ' mateo ');
      expect(requests.last.queryParameters, {'search': 'mateo'});

      expect((await repository.target(12)).charges, hasLength(4));

      final result = await repository.collect(
        const CollectionDraft(
          studentId: 12,
          amount: 285000,
          requestId: 'req-0001',
          chargeIds: [400, 501],
          guardianId: 3,
          notes: '  Pagó la abuela ',
        ),
      );
      expect(result.payment.receiptNumber, '000124');
      expect(result.cashBox?.balance, 585000);
      expect(requests.last.data, {
        'student_id': 12,
        'amount': 285000,
        'charge_ids': [400, 501],
        'guardian_id': 3,
        'notes': 'Pagó la abuela',
        'request_id': 'req-0001',
      });

      await repository.collect(
        const CollectionDraft(studentId: 12, amount: 1000, requestId: 'r2'),
      );
      expect(requests.last.data, {
        'student_id': 12,
        'amount': 1000,
        'charge_ids': <int>[],
        'request_id': 'r2',
      });

      expect((await repository.cashBox()).balance, 585000);
    });

    test(
      'registra la transferencia que mandó la familia (multipart)',
      () async {
        final requests = <RequestOptions>[];
        final repository = CashRepository(
          fakeDio({
            'POST /collections/transfers': (_) => {
              'data': _staffReport(),
              'message': 'Transferencia registrada. Queda en revisión hasta que la apruebe el tesorero.',
            },
          }, requests: requests),
          InMemorySessionStorage()..organization = 'jakare',
        );

        final result = await repository.registerTransfer(
          TransferRegistrationDraft(
            studentId: 12,
            amount: 135000,
            paidOn: DateTime(2026, 10, 3),
            proof: PickedProof(name: 'captura.jpg', bytes: Uint8List(10)),
            chargeIds: const [501],
            moneyAccountId: 3,
            guardianId: 3,
            reference: ' 99812 ',
          ),
        );

        expect(result.report.isPending, isTrue);
        expect(result.message, startsWith('Transferencia registrada.'));
        final form = requests.single.data as FormData;
        expect(
          form.fields.map((f) => '${f.key}=${f.value}'),
          containsAll([
            'student_id=12',
            'amount=135000',
            'paid_on=2026-10-03',
            'charge_ids[]=501',
            'money_account_id=3',
            'guardian_id=3',
            'reference=99812',
          ]),
        );
        expect(form.files.single.key, 'proof');
      },
    );

    test('depositar, retirar, confirmar y rechazar', () async {
      final requests = <RequestOptions>[];
      final repository = CashRepository(
        fakeDio({
          'POST /me/cash-box/deposits': (_) => {'data': _deposit()},
          'DELETE /me/cash-box/deposits/4': (_) => null,
          'GET /cash-boxes': (_) => {'data': _overview()},
          'POST /cash-deposits/4/confirm': (_) => {
            'data': _deposit(status: 'confirmado'),
          },
          'POST /cash-deposits/4/reject': (_) => {
            'data': _deposit(status: 'rechazado', reason: 'No llegó.'),
          },
        }, requests: requests),
        InMemorySessionStorage()..organization = 'jakare',
      );

      await repository.deposit(
        DepositDraft(
          amount: 300000,
          moneyAccountId: 2,
          depositedOn: DateTime(2026, 10, 4),
          reference: ' Boleta 5521 ',
        ),
      );
      expect(requests.last.data, {
        'amount': 300000,
        'money_account_id': 2,
        'deposited_on': '2026-10-04',
        'reference': 'Boleta 5521',
      });

      await repository.withdrawDeposit(4);
      expect(requests.last.method, 'DELETE');

      expect((await repository.overview()).boxes, hasLength(2));
      expect(
        (await repository.confirmDeposit(4)).status,
        CashDepositStatus.confirmed,
      );
      final rejected = await repository.rejectDeposit(4, ' No llegó. ');
      expect(rejected.rejectionReason, 'No llegó.');
      expect(requests.last.data, {'reason': 'No llegó.'});
    });

    test('sin organización no pide nada', () async {
      final repository = CashRepository(fakeDio({}), InMemorySessionStorage());

      expect(await repository.students(), isEmpty);
      expect((await repository.cashBox()).id, isNull);
      expect((await repository.overview()).boxes, isEmpty);
    });
  });

  group('pantallas', () {
    testWidgets('la lista muestra lo que debe cada familia y filtra', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._session(),
          'GET /collections/students': (_) => {'data': _students},
        }, const CollectStudentsScreen()),
      );
      await _settle(tester);

      expect(find.text('Mateo Benítez'), findsOneWidget);
      expect(find.text('₲ 300.000'), findsOneWidget);
      expect(find.text('Vencido'), findsOneWidget);
      expect(find.text('Al día'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('collect-search')), 'nuñez');
      await tester.pump();
      expect(find.text('Mateo Benítez'), findsNothing);
      expect(find.text('Lucía Núñez'), findsOneWidget);
    });

    testWidgets('cobrar: cuotas elegidas, monto sugerido y recibo', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final opened = <Uri>[];
      await tester.pumpWidget(
        _app(
          {
            ..._session(),
            'GET /collections/students/12': (_) => {'data': _target()},
            'GET /collections/students': (_) => {'data': _students},
            'GET /me/cash-box': (_) => {'data': _cashBox()},
            'POST /collections': (_) => {
              'data': {
                'payment': _payment(amount: 135000),
                'applied': 135000,
                'credit': 0,
                'cash_box': {
                  'id': 9,
                  'name': 'Caja de Juan Pérez',
                  'balance': 435000,
                  'active': true,
                },
                'message': 'Cobrado ₲ 135.000. Recibo N° 000124.',
              },
            },
          },
          const CollectScreen(studentId: 12),
          requests: requests,
          opened: opened,
        ),
      );
      await _settle(tester);

      expect(find.text('Mateo · Cuota agosto 2026'), findsOneWidget);
      expect(find.text('Sofía · Cuota octubre 2026'), findsOneWidget);
      // Vencida + octubre con pronto pago: ₲ 150.000 + ₲ 135.000.
      expect(find.text('285000'), findsOneWidget);
      expect(find.textContaining('Transferencia en revisión'), findsOneWidget);
      expect(find.text('Próximas cuotas'), findsOneWidget);

      // Sin la vencida, el monto baja.
      await tester.tap(find.text('Mateo · Cuota agosto 2026'));
      await tester.pump();
      expect(find.text('135000'), findsOneWidget);

      await _scrollTo(tester, find.text('Cobrar ₲ 135.000'));
      await tester.tap(find.text('Cobrar ₲ 135.000'));
      await tester.pumpAndSettle();

      final post = requests.firstWhere((r) => r.method == 'POST');
      expect(post.data, {
        'student_id': 12,
        'amount': 135000,
        'charge_ids': [501],
        'request_id': 'req-0001',
      });
      expect(find.text('Cobrado ₲ 135.000'), findsOneWidget);
      expect(find.text('Recibo N° 000124'), findsOneWidget);
      expect(find.text('En tu caja: ₲ 435.000.'), findsOneWidget);

      await tester.tap(find.text('Ver recibo'));
      expect(opened.single.path, '/recibos/124');

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de cobro'), findsOneWidget);
    });

    testWidgets('transferencia: pide el comprobante y queda en revisión', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._session(),
            'GET /collections/students/12': (_) => {'data': _target()},
            'GET /collections/students': (_) => {'data': _students},
            'POST /collections/transfers': (_) => {
              'data': _staffReport(),
              'message': 'Transferencia registrada. Queda en revisión hasta que la apruebe el tesorero.',
            },
          },
          const CollectScreen(studentId: 12),
          requests: requests,
          picked: PickedProof(name: 'captura.jpg', bytes: Uint8List(10)),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      expect(find.text('Monto transferido'), findsOneWidget);
      // Sin la vencida: solo octubre de Sofía.
      await tester.tap(find.text('Mateo · Cuota agosto 2026'));
      await tester.pump();

      await _scrollTo(tester, find.text('Registrar transferencia'));
      expect(
        find.textContaining('Queda en revisión hasta que la apruebe'),
        findsOneWidget,
      );
      await tester.tap(find.text('Registrar transferencia'));
      await tester.pump();
      expect(
        find.text('Adjuntá el comprobante de la transferencia.'),
        findsOneWidget,
      );
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.tap(find.byKey(const Key('collect-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ueno').last);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Adjuntar comprobante'));
      await tester.tap(find.text('Adjuntar comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('captura.jpg'), findsOneWidget);

      await _scrollTo(tester, find.text('Registrar transferencia'));
      await tester.tap(find.text('Registrar transferencia'));
      await tester.pumpAndSettle();

      final form =
          requests.firstWhere((r) => r.method == 'POST').data as FormData;
      expect(
        form.fields.map((f) => '${f.key}=${f.value}'),
        containsAll([
          'student_id=12',
          'amount=135000',
          'paid_on=2026-10-04',
          'charge_ids[]=501',
          'money_account_id=3',
        ]),
      );
      expect(find.text('Enviada a revisión'), findsOneWidget);
      expect(find.text('Ver recibo'), findsNothing);

      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de cobro'), findsOneWidget);
    });

    testWidgets('transferencia del tesorero: aprobada con recibo', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          {
            ..._session(),
            'GET /collections/students/12': (_) => {
              'data': _target(approves: true),
            },
            'POST /collections/transfers': (_) => {
              'data': _staffReport(status: 'aprobado'),
              'message': 'Transferencia registrada. Recibo N° 000125.',
            },
          },
          const CollectScreen(studentId: 12),
          picked: PickedProof(name: 'captura.jpg', bytes: Uint8List(10)),
        ),
      );
      await _settle(tester);

      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Adjuntar comprobante'));
      await tester.tap(find.text('Adjuntar comprobante'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Registrar transferencia'));
      expect(
        find.text(
          'Se registra el pago con su recibo y le avisamos a la familia.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Registrar transferencia'));
      await tester.pumpAndSettle();

      expect(find.text('Transferencia registrada'), findsOneWidget);
      expect(
        find.text('Transferencia registrada. Recibo N° 000125.'),
        findsOneWidget,
      );
      expect(find.text('Ver recibo'), findsOneWidget);
    });

    testWidgets('la familia ve quién la registró y no la puede retirar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _session(),
          Scaffold(
            body: PaymentReportTile(PaymentReport.fromJson(_staffReport())),
          ),
        ),
      );
      await _settle(tester);

      expect(find.text('Registrado por Juan Pérez'), findsOneWidget);
      expect(find.text('Retirar'), findsNothing);
    });

    testWidgets('el monto cambiado a mano no se pisa y avisa lo que sobra', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._session(),
          'GET /collections/students/12': (_) => {'data': _target()},
        }, const CollectScreen(studentId: 12)),
      );
      await _settle(tester);

      await tester.enterText(find.byKey(const Key('collect-amount')), '300000');
      await tester.tap(find.text('Mateo · Cuota agosto 2026'));
      await tester.pump();

      expect(find.text('300000'), findsOneWidget);
      expect(
        find.text('Sobran ₲ 165.000: quedan a favor de la familia.'),
        findsOneWidget,
      );
    });

    testWidgets('con la caja cerrada no deja cobrar', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._session(),
          'GET /collections/students/12': (_) => {
            'data': _target(
              box: {'id': 9, 'name': 'Caja', 'balance': 0, 'active': false},
            ),
          },
        }, const CollectScreen(studentId: 12)),
      );
      await _settle(tester);

      await _scrollTo(
        tester,
        find.text('Tu caja está cerrada. Hablá con el tesorero.'),
      );
      expect(find.widgetWithText(FilledButton, 'Cobrar'), findsNothing);
    });

    testWidgets('el error de la API se muestra', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._session(),
          'GET /collections/students/12': (_) => {'data': _target()},
          'POST /collections': (o) => throw apiError(o, 422, {
            'message': 'x',
            'errors': {
              'amount': ['Tu caja está cerrada. Hablá con el tesorero.'],
            },
          }),
        }, const CollectScreen(studentId: 12)),
      );
      await _settle(tester);

      await _scrollTo(tester, find.text('Cobrar ₲ 285.000'));
      await tester.tap(find.text('Cobrar ₲ 285.000'));
      await tester.pumpAndSettle();

      expect(
        find.text('Tu caja está cerrada. Hablá con el tesorero.'),
        findsOneWidget,
      );
    });

    testWidgets('mi caja: saldo, movimientos y depositar', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._session(),
            'GET /me/cash-box': (_) => {'data': _cashBox()},
            'POST /me/cash-box/deposits': (_) => {'data': _deposit(id: 5)},
          },
          const CashBoxScreen(),
          requests: requests,
        ),
      );
      await _settle(tester);

      expect(find.text('₲ 585.000'), findsOneWidget);
      expect(
        find.text('₲ 300.000 por confirmar · ₲ 285.000 para depositar'),
        findsOneWidget,
      );
      expect(find.text('Por confirmar'), findsOneWidget);
      expect(find.text('Retirar'), findsOneWidget);
      expect(find.text('Recibo N° 000124 · Familia Benítez'), findsOneWidget);
      expect(find.text('+₲ 285.000'), findsOneWidget);

      await tester.tap(find.text('Depositar'));
      await tester.pumpAndSettle();
      expect(find.text('Tenés ₲ 285.000 para depositar.'), findsOneWidget);
      expect(find.text('285000'), findsOneWidget);

      // Sin elegir la cuenta no se manda.
      await tester.tap(find.text('Informar depósito'));
      await tester.pump();
      expect(find.text('Elegí dónde lo depositaste.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('deposit-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco Itaú').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'N° de boleta o de operación (opcional)',
        ),
        '5521',
      );
      await tester.tap(find.text('Informar depósito'));
      await tester.pumpAndSettle();

      expect(requests.firstWhere((r) => r.method == 'POST').data, {
        'amount': 285000,
        'money_account_id': 2,
        'deposited_on': '2026-10-04',
        'reference': '5521',
      });
      expect(
        find.text('Listo. Te avisamos cuando lo confirmen.'),
        findsOneWidget,
      );
    });

    testWidgets('quien valida confirma y rechaza depósitos', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._session(),
            'GET /cash-boxes': (_) => {'data': _overview()},
            'POST /cash-deposits/4/confirm': (_) => {
              'data': _deposit(status: 'confirmado'),
            },
            'POST /cash-deposits/4/reject': (_) => {
              'data': _deposit(status: 'rechazado', reason: 'No llegó.'),
            },
          },
          const CashOverviewScreen(),
          requests: requests,
        ),
      );
      await _settle(tester);

      expect(find.text('₲ 885.000'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsNWidgets(2));
      expect(find.textContaining('Ya no está en el club'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(
        requests.map((r) => '${r.method} ${r.path}'),
        contains('POST /cash-deposits/4/confirm'),
      );
      expect(find.text('Depósito confirmado. Le avisamos.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pump();
      expect(find.text('Contale por qué no lo confirmás.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('deposit-reject-reason')),
        'No llegó.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();
      final reject = requests.lastWhere(
        (r) => r.path == '/cash-deposits/4/reject',
      );
      expect(reject.data, {'reason': 'No llegó.'});
    });
  });
}
