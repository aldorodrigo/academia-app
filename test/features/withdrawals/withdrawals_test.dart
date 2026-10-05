import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/billing/data/models.dart';
import 'package:academia_app/features/students/data/models.dart';
import 'package:academia_app/features/students/presentation/student_screen.dart';
import 'package:academia_app/features/withdrawals/data/models.dart';
import 'package:academia_app/features/withdrawals/data/withdrawals_repository.dart';
import 'package:academia_app/features/withdrawals/presentation/dropout_reports.dart';
import 'package:academia_app/features/withdrawals/presentation/manage_student_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

/// Bajas y condonación desde la app (academia-api/docs/PLAN_BAJAS.md).
Map<String, Object?> chargeJson({
  int id = 501,
  String description = 'Cuota junio 2026',
  String status = 'vencido',
  int pending = 150000,
  Map<String, Object?>? waiver,
  bool canWaive = true,
  bool canUnwaive = false,
}) => {
  'id': id,
  'student': {'id': 9, 'first_name': 'Matías'},
  'concept': 'Cuota mensual',
  'description': description,
  'due_on': '2026-06-10',
  'status': status,
  'base_amount': 150000,
  'final_amount': 150000,
  'paid_amount': 150000 - pending,
  'pending_amount': pending,
  'waiver': waiver,
  'can_waive': canWaive,
  'can_unwaive': canUnwaive,
};

Map<String, Object?> managedJson({bool withdrawn = false}) => {
  'id': 9,
  'full_name': 'Matías Zárate',
  'first_name': 'Matías',
  'enrollments': [
    {
      'id': 31,
      'program': 'Fútbol',
      'group': 'Sub-10',
      'season': '2026',
      'status': withdrawn ? 'baja' : 'activo',
      'status_label': withdrawn ? 'Baja' : 'Activo',
      'ended_on': withdrawn ? '2026-06-03' : null,
      'withdrawal_reason': withdrawn ? 'Se mudó' : null,
      'can_withdraw': !withdrawn,
      'dropout_report': withdrawn
          ? null
          : {
              'source': 'guardian',
              'reported_by': 'Rosa Zárate',
              'reported_on': '2026-06-02',
              'note': 'Nos mudamos a Encarnación',
            },
    },
  ],
  'notice': {
    'recipients': 1,
    'message':
        'Hola, te contamos que registramos la baja de Matías en Club Jakare. '
        'Las puertas siempre van a estar abiertas.',
  },
  'balance': 300000,
  'charges': [
    chargeJson(),
    chargeJson(id: 502, description: 'Cuota mayo 2026'),
    chargeJson(
      id: 503,
      description: 'Cuota abril 2026',
      status: 'condonado',
      pending: 0,
      canWaive: false,
      canUnwaive: true,
      waiver: {
        'amount': 150000,
        'reason': 'Lo decidió la comisión',
        'by': 'Laura Gómez',
        'on': '2026-06-03',
      },
    ),
  ],
};

Map<String, Object? Function(RequestOptions)> _routes({
  List<String> permissions = const ['withdraw_students', 'waive_charges'],
  Map<String, Object?>? student,
}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Admin',
      'email': 'a@test.com',
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
  'GET /staff/students/9': (_) => {'data': student ?? managedJson()},
  'GET /dropout-reports': (_) => {
    'data': [
      {
        'enrollment_id': 31,
        'student': {'id': 9, 'full_name': 'Matías Zárate'},
        'group': 'Sub-10',
        'source': 'instructor',
        'reported_by': 'Carlos Gómez',
        'reported_on': '2026-06-03',
        'note': null,
      },
    ],
  },
  'POST /enrollments/31/withdraw': (_) => {
    'data': {'notified': 1},
  },
  'DELETE /enrollments/31/dropout': (_) => null,
  'POST /charges/waive': (_) => {
    'data': {'waived': 300000},
  },
  'POST /charges/503/unwaive': (_) => {'data': chargeJson(id: 503)},
  'POST /students/9/leaving': (_) => {
    'data': {'leaving_reported_on': '2026-06-02'},
  },
  'DELETE /students/9/leaving': (_) => null,
};

Widget _app(
  Widget home, {
  List<String> permissions = const ['withdraw_students', 'waive_charges'],
  List<RequestOptions>? requests,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(
      fakeDio(_routes(permissions: permissions), requests: requests),
    ),
    todayProvider.overrideWithValue(DateTime(2026, 6, 3)),
  ],
  child: MaterialApp(home: home),
);

void main() {
  test('lee la ficha: inscripciones, aviso, mensaje y cuotas', () {
    final student = ManagedStudent.fromJson(managedJson());

    final enrollment = student.enrollments.single;
    expect(enrollment.title, 'Fútbol · Sub-10 · 2026');
    expect(enrollment.canWithdraw, isTrue);
    expect(enrollment.dropoutReport!.source, DropoutSource.guardian);
    expect(
      enrollment.dropoutReport!.summary,
      'Rosa Zárate avisó que deja el club',
    );
    expect(student.noticeRecipients, 1);
    expect(student.charges, hasLength(3));
    final waived = student.charges!.last;
    expect(waived.charge.status, ChargeStatus.waived);
    expect(waived.waiver!.by, 'Laura Gómez');
    expect(waived.canUnwaive, isTrue);
  });

  test('el repositorio arma cada pedido', () async {
    final requests = <RequestOptions>[];
    final repository = WithdrawalsRepository(
      fakeDio(_routes(), requests: requests),
      InMemorySessionStorage()..organization = 'jakare',
    );

    final notified = await repository.withdraw(
      31,
      WithdrawalDraft(
        endedOn: DateTime(2026, 6, 3),
        reason: ' Se mudó ',
        notify: true,
        message: ' ¡Gracias! ',
      ),
    );
    await repository.withdraw(
      31,
      WithdrawalDraft(
        endedOn: DateTime(2026, 6, 3),
        reason: 'Se mudó',
        message: 'no se manda',
      ),
    );
    final waived = await repository.waive([501, 502], ' Baja ');
    await repository.unwaive(503, 'Error');
    final on = await repository.reportLeaving(9, message: ' ');
    await repository.cancelLeaving(9);
    final reports = await repository.dropoutReports();

    expect(notified, 1);
    expect(requests[0].data, {
      'ended_on': '2026-06-03',
      'reason': 'Se mudó',
      'notify': true,
      'message': '¡Gracias!',
    });
    expect(requests[1].data, {
      'ended_on': '2026-06-03',
      'reason': 'Se mudó',
      'notify': false,
    });
    expect(waived, 300000);
    expect(requests[2].data, {
      'charge_ids': [501, 502],
      'reason': 'Baja',
    });
    expect(requests[3].data, {'reason': 'Error'});
    expect(requests[4].data, isEmpty);
    expect(on, DateTime(2026, 6, 2));
    expect(requests[5].method, 'DELETE');
    expect(reports.single.studentId, 9);
    expect(reports.single.summary, 'Carlos Gómez avisó que dejó de venir');
  });

  testWidgets('dar de baja con el aviso a la familia, personalizado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(const ManageStudentScreen(id: 9), requests: requests),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Rosa Zárate avisó que deja el club (02/06/2026): «Nos mudamos a Encarnación»',
      ),
      findsOneWidget,
    );
    expect(find.text('Sigue viniendo'), findsOneWidget);

    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();

    // Motivo prellenado con la nota del aviso; mensaje amable prellenado y editable.
    expect(find.text('Nos mudamos a Encarnación'), findsOneWidget);
    expect(find.textContaining('Las puertas siempre'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mensaje'),
      'Hola Rosa, ¡los esperamos cuando quieran volver!',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/enrollments/31/withdraw');
    expect(post.data, {
      'ended_on': '2026-06-03',
      'reason': 'Nos mudamos a Encarnación',
      'notify': true,
      'message': 'Hola Rosa, ¡los esperamos cuando quieran volver!',
    });
    expect(
      find.text('Baja registrada. Le avisamos a la familia.'),
      findsOneWidget,
    );
  });

  testWidgets('sin aviso a la familia y el motivo es obligatorio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(const ManageStudentScreen(id: 9), requests: requests),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar de baja'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Motivo'), ' ');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Mensaje'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await tester.pumpAndSettle();
    expect(find.text('Contanos el motivo de la baja.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Motivo'),
      'Dejó de venir',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Dar de baja'));
    await tester.pumpAndSettle();

    expect(requests.singleWhere((r) => r.method == 'POST').data, {
      'ended_on': '2026-06-03',
      'reason': 'Dejó de venir',
      'notify': false,
    });
  });

  testWidgets('condonar todo, condonar una y deshacer', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(const ManageStudentScreen(id: 9), requests: requests),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debe ₲ 300.000'), findsOneWidget);
    expect(
      find.text(
        'Condonado ₲ 150.000 por Laura Gómez el 03/06/2026: Lo decidió la comisión',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Condonar todo lo pendiente (₲ 300.000)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Condonar'));
    await tester.pumpAndSettle();
    expect(find.text('Contanos el motivo.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Dado de baja');
    await tester.tap(find.widgetWithText(FilledButton, 'Condonar'));
    await tester.pumpAndSettle();
    expect(find.text('Condonado: ₲ 300.000.'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(
      find.text('La cuota vuelve a quedar pendiente por ₲ 150.000.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Fue un error');
    await tester.tap(find.widgetWithText(FilledButton, 'Deshacer'));
    await tester.pumpAndSettle();

    final posts = requests.where((r) => r.method == 'POST').toList();
    expect(posts[0].data, {
      'charge_ids': [501, 502],
      'reason': 'Dado de baja',
    });
    expect(posts[1].path, '/charges/503/unwaive');
    expect(posts[1].data, {'reason': 'Fue un error'});
  });

  testWidgets('sin permiso de baja no aparecen los botones', (tester) async {
    await tester.pumpWidget(
      _app(
        const ManageStudentScreen(id: 9),
        permissions: const ['waive_charges'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dar de baja'), findsNothing);
    expect(find.text('Sigue viniendo'), findsNothing);
    expect(find.text('Condonar todo lo pendiente (₲ 300.000)'), findsOneWidget);
  });

  testWidgets('la tarjeta de avisos solo con permiso de baja', (tester) async {
    await tester.pumpWidget(
      _app(const Scaffold(body: DropoutReportsCard()), permissions: const []),
    );
    await tester.pumpAndSettle();
    expect(find.text('Avisos de baja'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(const Scaffold(body: DropoutReportsCard())));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(find.text('Avisos de baja'), findsOneWidget);
    expect(
      find.text('Matías Zárate · Carlos Gómez avisó que dejó de venir'),
      findsOneWidget,
    );
  });

  testWidgets('el tutor avisa que deja el club con un mensaje', (tester) async {
    final requests = <RequestOptions>[];
    final student = Student.fromJson({
      'id': 9,
      'first_name': 'Matías',
      'last_name': 'Zárate',
      'full_name': 'Matías Zárate',
      'birth_date': '2016-03-14',
      'enrollments': [
        {
          'id': 31,
          'status': 'activo',
          'season': {'id': 1, 'name': '2026'},
          'group': {
            'id': 3,
            'name': 'Sub-10',
            'program': {'id': 1, 'name': 'Fútbol'},
          },
        },
      ],
    });
    await tester.pumpWidget(
      _app(
        Scaffold(
          appBar: AppBar(actions: [LeavingMenu(student: student)]),
        ),
        requests: requests,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisar que deja el club'));
    await tester.pumpAndSettle();
    expect(find.text('¿Matías deja el club?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nos mudamos, ¡gracias!');
    await tester.tap(find.text('Avisar al club'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/students/9/leaving');
    expect(post.data, {'message': 'Nos mudamos, ¡gracias!'});
    expect(
      find.text('Listo: le avisamos al club. ¡Gracias por avisar!'),
      findsOneWidget,
    );
  });

  test('la ficha del tutor lee el aviso', () {
    final student = Student.fromJson({
      'id': 9,
      'first_name': 'Matías',
      'last_name': 'Zárate',
      'full_name': 'Matías Zárate',
      'birth_date': null,
      'enrollments': <Object>[],
      'leaving_reported_on': '2026-06-02',
    });
    expect(student.leavingReportedOn, DateTime(2026, 6, 2));
    expect(LeavingDialog(name: student.firstName).name, 'Matías');
  });
}
