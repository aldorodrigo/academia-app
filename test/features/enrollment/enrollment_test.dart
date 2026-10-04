import 'package:academia_app/app.dart';
import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/enrollment/data/enrollment_repository.dart';
import 'package:academia_app/features/enrollment/data/models.dart';
import 'package:academia_app/features/enrollment/data/request_form.dart';
import 'package:academia_app/features/enrollment/presentation/enroll_child_screen.dart';
import 'package:academia_app/features/enrollment/presentation/enrollment_requests_card.dart';
import 'package:academia_app/features/enrollment/presentation/enrollment_requests_screen.dart';
import 'package:academia_app/features/students/presentation/students_screen.dart';
import 'package:academia_app/router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';

typedef Routes = Map<String, Object? Function(RequestOptions)>;

const _season = {
  'id': 1,
  'name': '2026',
  'starts_on': '2026-02-01',
  'ends_on': '2026-11-30',
};

/// Opción según el contrato (`API_V1.md`, «Inscripción desde la app»).
Map<String, Object?> optionJson({
  int programId = 1,
  String program = 'Fútbol',
  Map<String, Object?> season = _season,
  int? suggested = 3,
  bool full = false,
}) => {
  'program': {'id': programId, 'name': program},
  'season': season,
  'suggested_group_id': suggested,
  'groups': [
    {
      'id': 2,
      'name': 'Sub-6',
      'capacity': null,
      'spots_left': null,
      'full': false,
      'schedules': <Object>[],
    },
    {
      'id': 3,
      'name': 'Sub-8',
      'capacity': 20,
      'spots_left': full ? 0 : 3,
      'full': full,
      'schedules': [
        {'weekday': 1, 'starts_at': '17:00', 'ends_at': '18:30'},
        {'weekday': 3, 'starts_at': '17:00', 'ends_at': '18:30'},
      ],
    },
  ],
};

/// Solicitud según el contrato; con [forReviewer], lo que ve quien aprueba.
Map<String, Object?> requestJson({
  int id = 18,
  String status = 'pendiente',
  String? reason,
  bool forReviewer = false,
  bool full = false,
  bool midPeriod = true,
}) => {
  'id': id,
  'status': status,
  'status_label': status,
  'child': {
    'first_name': 'Sofía',
    'last_name': 'Benítez',
    'full_name': 'Sofía Benítez',
    'birth_date': '2018-07-02',
    'document': '7123456',
  },
  'relationship': 'madre',
  'has_medical': true,
  'notes': null,
  'season': _season,
  'group': {
    'id': 3,
    'name': 'Sub-8',
    'program': {'id': 1, 'name': 'Fútbol'},
  },
  'rejection_reason': reason,
  'student_id': status == 'aprobada' ? 40 : null,
  'created_at': '2026-10-04T10:15:00-03:00',
  'reviewed_at': null,
  if (forReviewer) ...{
    'requested_by': {
      'name': 'Ana Benítez',
      'phone': '0981 123 456',
      'email': null,
    },
    'age': 8,
    'existing_student': null,
    'group_options': [
      {
        'id': 3,
        'name': 'Sub-8',
        'capacity': 20,
        'spots_left': full ? 0 : 3,
        'full': full,
        'suggested': true,
      },
      {
        'id': 4,
        'name': 'Sub-10',
        'capacity': null,
        'spots_left': null,
        'full': false,
        'suggested': false,
      },
    ],
    'mid_period': midPeriod
        ? {
            'label': 'Se inscribe a mitad de mes: se cobra',
            'default': 'completo',
            'options': [
              {'value': 'completo', 'label': 'El mes completo'},
              {
                'value': 'proporcional',
                'label': 'Lo que falta del mes (proporcional)',
              },
              {'value': 'proximo', 'label': 'Desde el mes que viene'},
            ],
          }
        : null,
  },
};

Routes _routes({
  List<String> permissions = const [],
  List<String> roles = const ['tutor'],
  List<Map<String, Object?>> options = const [],
  List<Map<String, Object?>> mine = const [],
  List<Map<String, Object?>> review = const [],
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
      'membership': {
        'roles': [
          for (final r in roles) {'name': r, 'label': r},
        ],
        'permissions': permissions,
      },
    },
  },
  'GET /students': (_) => {'data': <Object>[]},
  'GET /enrollment-requests/options': (_) => {'data': options},
  'GET /enrollment-requests': (_) => {'data': mine},
  'GET /enrollment-requests/review': (_) => {'data': review},
};

Widget _app(Routes routes, Widget home, {List<RequestOptions>? requests}) =>
    ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(
          InMemorySessionStorage()
            ..token = 't'
            ..organization = 'jakare',
        ),
        apiClientProvider.overrideWithValue(
          fakeDio(routes, requests: requests),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 10, 4)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => home),
            GoRoute(
              path: '/inicio',
              builder: (_, _) => const Scaffold(body: Text('Inicio')),
            ),
            GoRoute(
              path: '/hijos/inscribir',
              builder: (_, _) => const Scaffold(body: Text('Inscribir')),
            ),
            GoRoute(
              path: '/solicitudes',
              builder: (_, _) => const Scaffold(body: Text('Solicitudes')),
            ),
          ],
        ),
      ),
    );

/// El formulario es una lista perezosa: hay que desplazarse para construir lo de abajo.
Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  group('modelos', () {
    test('lee la solicitud del tutor y la de quien aprueba', () {
      final mine = EnrollmentRequest.fromJson(requestJson());
      expect(mine.status, EnrollmentRequestStatus.pending);
      expect(mine.status.label, 'En revisión');
      expect(mine.isPending, isTrue);
      expect(mine.child.fullName, 'Sofía Benítez');
      expect(mine.child.birthDate, DateTime(2018, 7, 2));
      expect(mine.relationship, Relationship.mother);
      expect(mine.placeLabel, 'Sub-8 · Fútbol (2026)');
      expect(mine.requestedBy, isNull);
      expect(mine.groupOptions, isEmpty);

      final review = EnrollmentRequest.fromJson(
        requestJson(forReviewer: true, full: true),
      );
      expect(review.requestedBy!.contact, '0981 123 456');
      expect(review.age, 8);
      expect(review.groupOption(3)!.full, isTrue);
      expect(review.groupOption(3)!.spotsLabel, 'Completo');
      expect(review.groupOption(4)!.spotsLabel, isNull);
      expect(review.midPeriod!.defaultValue, 'completo');
      expect(review.midPeriod!.options, hasLength(3));

      final rejected = EnrollmentRequest.fromJson(
        requestJson(status: 'rechazada', reason: 'No hay lugar.'),
      );
      expect(rejected.status.label, 'No aprobada');
      expect(rejected.rejectionReason, 'No hay lugar.');
      expect(EnrollmentRequestStatus.parse('otro'), isA<Object>());
    });

    test('la categoría que se elige sola', () {
      expect(EnrollmentOption.fromJson(optionJson()).defaultGroupId, 3);
      // Sin sugerencia y con varias: ninguna.
      expect(
        EnrollmentOption.fromJson(optionJson(suggested: null)).defaultGroupId,
        isNull,
      );
      // Sin sugerencia y con una sola: esa.
      final single = EnrollmentOption.fromJson({
        ...optionJson(suggested: null),
        'groups': [
          {'id': 9, 'name': 'Inicial'},
        ],
      });
      expect(single.defaultGroupId, 9);
      expect(single.groups.single.spotsLabel, isNull);
      expect(
        EnrollmentOption.fromJson(optionJson()).groups.last.spotsLabel,
        'Quedan 3 lugares',
      );
    });

    test('la ficha médica manda solo lo cargado', () {
      expect(const MedicalDraft(bloodType: ' ', allergies: '').isEmpty, isTrue);
      expect(
        const MedicalDraft(bloodType: 'O+ ', allergies: 'Penicilina').toJson(),
        {'blood_type': 'O+', 'allergies': 'Penicilina'},
      );
    });
  });

  group('validaciones', () {
    final today = DateTime(2026, 10, 4);

    test('fecha de nacimiento', () {
      expect(parseDayMonthYear('02/07/2018'), DateTime(2018, 7, 2));
      expect(parseDayMonthYear('2/7/2018'), DateTime(2018, 7, 2));
      expect(parseDayMonthYear('31/02/2018'), isNull);
      expect(parseDayMonthYear('2018-07-02'), isNull);

      expect(validateBirthDate('', today), 'Ingresá la fecha de nacimiento.');
      expect(
        validateBirthDate('31/02/2018', today),
        'Escribila como dd/mm/aaaa (ej. 02/07/2018).',
      );
      expect(
        validateBirthDate('04/10/2026', today),
        'La fecha de nacimiento tiene que ser pasada.',
      );
      expect(validateBirthDate('01/01/1900', today), 'Revisá el año.');
      expect(validateBirthDate('02/07/2018', today), isNull);
    });

    test('nombre, documento, categoría y motivo', () {
      expect(validateChildFirstName(' '), 'Ingresá el nombre.');
      expect(validateChildLastName(null), 'Ingresá el apellido.');
      expect(validateDocument(''), isNull);
      expect(validateDocument('7.123.456'), isNull);
      expect(
        validateDocument('71 23'),
        'Ingresá el número de documento, sin espacios.',
      );
      expect(validateGroup(null), 'Elegí la categoría.');
      expect(validateGroup(3), isNull);
      expect(
        validateRequestRejection(' '),
        'Contale a la familia por qué no la aprobás.',
      );
    });
  });

  group('repositorio', () {
    late List<RequestOptions> requests;
    late EnrollmentRepository repository;

    setUp(() {
      requests = [];
      repository = EnrollmentRepository(
        fakeDio({
          ..._routes(options: [optionJson()], mine: [requestJson()]),
          'POST /enrollment-requests': (_) => {'data': requestJson()},
          'DELETE /enrollment-requests/18': (_) => null,
          'GET /enrollment-requests/review': (_) => {
            'data': [requestJson(forReviewer: true)],
          },
          'POST /enrollment-requests/18/approve': (_) => {
            'data': requestJson(status: 'aprobada'),
          },
          'POST /enrollment-requests/18/reject': (_) => {
            'data': requestJson(status: 'rechazada', reason: 'No hay lugar.'),
          },
        }, requests: requests),
        InMemorySessionStorage()..organization = 'jakare',
      );
    });

    test('opciones por fecha de nacimiento', () async {
      final options = await repository.options(birthDate: DateTime(2018, 7, 2));
      expect(options.single.program.name, 'Fútbol');
      expect(requests.single.queryParameters, {'birth_date': '2018-07-02'});
    });

    test('pedir manda lo cargado y nada vacío', () async {
      await repository.submit(
        EnrollmentRequestDraft(
          firstName: ' Sofía ',
          lastName: 'Benítez',
          birthDate: DateTime(2018, 7, 2),
          document: ' ',
          seasonId: 1,
          groupId: 3,
          relationship: Relationship.mother,
          medical: const MedicalDraft(allergies: 'Penicilina'),
        ),
      );
      expect(requests.single.data, {
        'first_name': 'Sofía',
        'last_name': 'Benítez',
        'birth_date': '2018-07-02',
        'relationship': 'madre',
        'season_id': 1,
        'group_id': 3,
        'medical': {'allergies': 'Penicilina'},
      });
    });

    test('las propias y cancelar', () async {
      expect((await repository.mine()).single.id, 18);
      await repository.cancel(18);
      expect(requests.last.method, 'DELETE');
      expect(requests.last.path, '/enrollment-requests/18');
    });

    test('sin organización no pide nada', () async {
      final empty = EnrollmentRepository(
        fakeDio({}, requests: requests),
        InMemorySessionStorage(),
      );
      expect(await empty.mine(), isEmpty);
      expect(await empty.review(), isEmpty);
      expect(requests, isEmpty);
    });

    test('revisar, aprobar y rechazar', () async {
      await repository.review(all: true);
      expect(requests.last.queryParameters, {'status': 'todos'});

      final approved = await repository.approve(
        18,
        groupId: 4,
        midPeriod: 'proporcional',
        overCapacity: true,
      );
      expect(requests.last.data, {
        'group_id': 4,
        'mid_period': 'proporcional',
        'over_capacity': true,
      });
      expect(approved.studentId, 40);

      await repository.approve(18);
      expect(requests.last.data, isEmpty);

      final rejected = await repository.reject(18, ' No hay lugar. ');
      expect(requests.last.data, {'reason': 'No hay lugar.'});
      expect(rejected.status, EnrollmentRequestStatus.rejected);
    });
  });

  group('tutor', () {
    testWidgets('pide la inscripción con la categoría sugerida', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(options: [optionJson()]),
            'POST /enrollment-requests': (_) => {'data': requestJson()},
          },
          const EnrollChildScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Sofía',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido'),
        'Benítez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
        '02/07/2018',
      );
      await tester.pumpAndSettle();

      expect(requests.last.queryParameters, {
        'birth_date': '2018-07-02',
      }, reason: 'con la fecha se piden las opciones');
      expect(find.text('Categoría · Fútbol'), findsOneWidget);
      expect(
        find.text(
          'Le corresponde por la edad · Lun 17:00, Mié 17:00 · Quedan 3 lugares',
        ),
        findsOneWidget,
      );
      final sub8 = tester.widget<RadioListTile<int>>(
        find.widgetWithText(RadioListTile<int>, 'Sub-8'),
      );
      expect(sub8.value, 3);
      expect(
        tester.widget<RadioGroup<int>>(find.byType(RadioGroup<int>)).groupValue,
        3,
      );

      await _scrollTo(tester, find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      final sent = requests.lastWhere((r) => r.method == 'POST');
      expect(sent.data, {
        'first_name': 'Sofía',
        'last_name': 'Benítez',
        'birth_date': '2018-07-02',
        'relationship': 'madre',
        'season_id': 1,
        'group_id': 3,
      });
      expect(find.text('Solicitud enviada'), findsOneWidget);
      expect(
        find.text(
          'Pediste lugar para Sofía en Sub-8 · Fútbol (2026). Te avisamos '
          'cuando el club la apruebe.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('elige la disciplina y la categoría; cupo lleno', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(
              options: [
                optionJson(suggested: null, full: true),
                optionJson(
                  programId: 2,
                  program: 'Pádel',
                  suggested: null,
                  season: {
                    'id': 5,
                    'name': 'Colonia',
                    'starts_on': '2026-12-01',
                    'ends_on': '2027-01-31',
                  },
                ),
              ],
            ),
            'POST /enrollment-requests': (_) => {'data': requestJson()},
          },
          const EnrollChildScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Sofía',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido'),
        'Benítez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
        '02/07/2018',
      );
      await tester.pumpAndSettle();

      expect(find.text('¿En qué lo inscribís?'), findsOneWidget);
      final fullGroup = find.text(
        'Lun 17:00, Mié 17:00 · Completo: el club decide si hay lugar',
      );
      await _scrollTo(tester, fullGroup);
      expect(
        find.text(
          'Lun 17:00, Mié 17:00 · Completo: el club decide si hay lugar',
        ),
        findsOneWidget,
      );

      // Sin sugerencia: hay que elegir la categoría.
      await _scrollTo(tester, find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Elegí la categoría.'));
      expect(find.text('Elegí la categoría.'), findsOneWidget);
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      // La colonia de pádel, que todavía no empezó.
      await _scrollTo(tester, find.text('Pádel · Colonia'));
      await tester.tap(find.text('Pádel · Colonia'));
      await tester.pumpAndSettle();
      expect(find.text('Colonia: empieza el 01/12/2026'), findsOneWidget);
      await tester.tap(find.widgetWithText(RadioListTile<int>, 'Sub-6'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      final sent = requests.lastWhere((r) => r.method == 'POST');
      expect((sent.data as Map)['season_id'], 5);
      expect((sent.data as Map)['group_id'], 2);
    });

    testWidgets('valida los datos y muestra el error de la API', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._routes(options: [optionJson()]),
          'POST /enrollment-requests': (options) =>
              throw apiError(options, 422, {
                'message': 'Ya mandaste una solicitud.',
                'errors': {
                  'first_name': [
                    'Ya mandaste una solicitud para Sofía; esperá a que el club la revise.',
                  ],
                },
              }),
        }, const EnrollChildScreen()),
      );
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Ingresá el nombre.'),
        find.byType(Scrollable).first,
        const Offset(0, 200),
      );
      expect(find.text('Ingresá el nombre.'), findsOneWidget);
      expect(find.text('Ingresá la fecha de nacimiento.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Sofía',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido'),
        'Benítez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
        '02/07/2018',
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Ya mandaste una solicitud para Sofía; esperá a que el club la revise.',
        ),
        findsOneWidget,
      );
      expect(find.text('Solicitud enviada'), findsNothing);
    });

    testWidgets('sin inscripciones abiertas no se puede enviar', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_routes(), const EnrollChildScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Fecha de nacimiento'),
        '02/07/2018',
      );
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.text(
          'El club todavía no tiene inscripciones abiertas. Consultá con el club.',
        ),
      );
      await _scrollTo(tester, find.text('Enviar solicitud'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar solicitud'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('"Mis hijos" muestra las solicitudes y se cancelan', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(
              mine: [
                requestJson(),
                requestJson(
                  id: 17,
                  status: 'rechazada',
                  reason: 'No hay lugar este año.',
                ),
              ],
            ),
            'DELETE /enrollment-requests/18': (_) => null,
          },
          const StudentsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Solicitud en revisión · Sub-8 · Fútbol (2026)'),
        findsOneWidget,
      );
      expect(find.text('No aprobada: No hay lugar este año.'), findsOneWidget);
      expect(find.text('Inscribir a mi hijo'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancelar la solicitud'),
      );
      await tester.pumpAndSettle();

      expect(requests.any((r) => r.method == 'DELETE'), isTrue);
      expect(find.text('Solicitud cancelada.'), findsOneWidget);

      await tester.tap(find.text('Inscribir a mi hijo'));
      await tester.pumpAndSettle();
      expect(find.text('Inscribir'), findsOneWidget);
    });
  });

  group('quien aprueba', () {
    testWidgets('la tarjeta del inicio cuenta las pendientes', (tester) async {
      await tester.pumpWidget(
        _app(
          _routes(
            permissions: ['manage_enrollment_requests'],
            review: [requestJson(forReviewer: true)],
          ),
          const Scaffold(body: EnrollmentRequestsCard()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitudes de inscripción'), findsOneWidget);
      expect(find.text('1 para revisar'), findsOneWidget);
      await tester.tap(find.text('Solicitudes de inscripción'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitudes'), findsOneWidget);
    });

    testWidgets('sin el permiso no hay tarjeta', (tester) async {
      await tester.pumpWidget(
        _app(_routes(), const Scaffold(body: EnrollmentRequestsCard())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Solicitudes de inscripción'), findsNothing);
    });

    testWidgets('aprobar con la categoría llena pide confirmar el cupo', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(
              permissions: ['manage_enrollment_requests'],
              review: [requestJson(forReviewer: true, full: true)],
            ),
            'POST /enrollment-requests/18/approve': (_) => {
              'data': requestJson(status: 'aprobada'),
            },
          },
          const EnrollmentRequestsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sofía Benítez'), findsOneWidget);
      expect(
        find.text('8 años · Nació el 02/07/2018 · Doc. 7123456'),
        findsOneWidget,
      );
      expect(find.text('Sub-8 · Fútbol (2026) · Completo'), findsOneWidget);
      expect(
        find.text('Pidió Ana Benítez (madre) · 0981 123 456'),
        findsOneWidget,
      );
      expect(find.text('Cargó la ficha médica.'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      final approve = find.descendant(
        of: dialog,
        matching: find.widgetWithText(FilledButton, 'Aprobar'),
      );
      expect(tester.widget<FilledButton>(approve).onPressed, isNull);
      expect(find.text('Se inscribe a mitad de mes: se cobra'), findsOneWidget);

      await tester.tap(find.text('Lo que falta del mes (proporcional)'));
      await tester.tap(find.text('Sub-8 está completa. Inscribir igual.'));
      await tester.pumpAndSettle();
      await tester.tap(approve);
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'group_id': 3,
        'mid_period': 'proporcional',
        'over_capacity': true,
      });
      expect(
        find.text(
          'Inscripción aprobada: Sofía en Sub-8 · Fútbol (2026). Le avisamos a la familia.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cambiar a una categoría con lugar no pide confirmar', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(
              permissions: ['manage_enrollment_requests'],
              review: [
                requestJson(forReviewer: true, full: true, midPeriod: false),
              ],
            ),
            'POST /enrollment-requests/18/approve': (_) => {
              'data': requestJson(status: 'aprobada'),
            },
          },
          const EnrollmentRequestsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Se inscribe a mitad de mes: se cobra'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sub-10').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Aprobar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'group_id': 4,
      });
    });

    testWidgets('rechazar pide el motivo', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._routes(
              permissions: ['manage_enrollment_requests'],
              review: [requestJson(forReviewer: true)],
            ),
            'POST /enrollment-requests/18/reject': (_) => {
              'data': requestJson(status: 'rechazada', reason: 'No hay lugar.'),
            },
          },
          const EnrollmentRequestsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
      await tester.pumpAndSettle();
      final reject = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Rechazar'),
      );
      await tester.tap(reject);
      await tester.pumpAndSettle();
      expect(
        find.text('Contale a la familia por qué no la aprobás.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), 'No hay lugar.');
      await tester.tap(reject);
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'reason': 'No hay lugar.',
      });
      expect(
        find.text('Solicitud rechazada. Le avisamos a la familia.'),
        findsOneWidget,
      );
    });
  });

  group('rutas', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester,
      Routes routes,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sessionStorageProvider.overrideWithValue(
            InMemorySessionStorage()
              ..token = 't'
              ..organization = 'jakare',
          ),
          offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
          apiClientProvider.overrideWithValue(fakeDio(routes)),
          pushServiceProvider.overrideWithValue(FakePushService()),
          todayProvider.overrideWithValue(DateTime(2026, 10, 4)),
          nowProvider.overrideWithValue(DateTime(2026, 10, 4, 10)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('/hijos/inscribir y /solicitudes abren sus pantallas', (
      tester,
    ) async {
      final container = await pumpApp(
        tester,
        _routes(permissions: ['manage_enrollment_requests']),
      );

      container.read(routerProvider).go('/hijos/inscribir');
      await tester.pumpAndSettle();
      expect(find.byType(EnrollChildScreen), findsOneWidget);

      container.read(routerProvider).go('/solicitudes');
      await tester.pumpAndSettle();
      expect(find.byType(EnrollmentRequestsScreen), findsOneWidget);
    });
  });
}
