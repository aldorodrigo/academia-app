import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/attendance/data/models.dart';
import 'package:academia_app/features/attendance/presentation/class_attendance_screen.dart';
import 'package:academia_app/features/attendance/presentation/group_screen.dart';
import 'package:academia_app/features/enrollment/data/models.dart';
import 'package:academia_app/features/enrollment/presentation/add_student_screen.dart';
import 'package:academia_app/features/enrollment/presentation/enroll_child_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import '../attendance/class_json.dart';
import 'enrollment_test.dart' show optionJson, requestJson;

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _base({List<String> permissions = const []}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Carlos',
      'email': 'carlos@test.com',
      'organizations': [
        {'slug': 'jakare', 'name': 'Club Jakare'},
      ],
    },
  },
  'GET /organization': (_) => {
    'data': {
      'slug': 'jakare',
      'name': 'Club Jakare',
      'terminology': {'student': 'Alumno'},
      'membership': {'roles': [], 'permissions': permissions},
    },
  },
  'GET /students': (_) => {'data': <Object>[]},
  'GET /enrollment-requests': (_) => {'data': <Object>[]},
  'GET /enrollment-requests/review': (_) => {'data': <Object>[]},
  'GET /enrollment-requests/options': (_) => {
    'data': [optionJson()],
  },
};

Widget _app(
  Routes routes,
  Widget home, {
  List<RequestOptions>? requests,
  List<Uri>? launched,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
    apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
    todayProvider.overrideWithValue(DateTime(2026, 10, 4)),
    nowProvider.overrideWithValue(DateTime(2026, 10, 4, 10)),
    pushServiceProvider.overrideWithValue(FakePushService()),
    urlLauncherProvider.overrideWithValue((uri) async {
      launched?.add(uri);
      return true;
    }),
  ],
  child: MaterialApp(home: home),
);

/// Sofía pidió lugar desde la app: va a clases mientras el club confirma.
Map<String, Object?> _sofia({bool canReview = true}) => {
  ...classStudentJson(id: 40, name: 'Sofía Benítez'),
  'enrollment_request': {'id': 18, 'can_review': canReview},
};

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  test('la planilla lee a los nuevos por confirmar', () {
    final student = ClassStudent.fromJson(_sofia());
    expect(student.isPendingConfirmation, isTrue);
    expect(student.enrollmentRequestId, 18);
    expect(student.canConfirm, isTrue);
    expect(
      ClassStudent.fromJson(classStudentJson(id: 1, name: 'A'))
          .isPendingConfirmation,
      isFalse,
    );
  });

  group('planilla del técnico', () {
    testWidgets('el nuevo dice "por confirmar" y se confirma con un toque', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      var full = true;
      await tester.pumpWidget(
        _app(
          {
            ..._base(
              permissions: ['take_attendance', 'manage_enrollment_requests'],
            ),
            'GET /classes/81': (_) => {
              'data': classJson(
                date: '2026-10-04',
                students: [
                  classStudentJson(id: 12, name: 'Mateo Benítez'),
                  _sofia(),
                ],
              ),
            },
            'POST /enrollment-requests/18/approve': (options) {
              final data = options.data as Map;
              if (full && data['over_capacity'] != true) {
                throw apiError(options, 422, {
                  'message': 'Completa',
                  'errors': {
                    'over_capacity': [
                      'Sub-8 está completa (20 de 20). Confirmá para inscribirla igual.',
                    ],
                  },
                });
              }
              return {'data': requestJson(status: 'aprobada')};
            },
          },
          const ClassAttendanceScreen(id: 81),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo, por confirmar'), findsOneWidget);
      await tester.tap(find.text('Confirmar inscripción'));
      await tester.pumpAndSettle();

      // Está completa: pregunta antes de inscribirla igual.
      expect(
        find.text(
          'Sub-8 está completa (20 de 20). Confirmá para inscribirla igual.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Inscribir igual'));
      await tester.pumpAndSettle();

      final approvals = requests.where((r) => r.path.endsWith('/approve'));
      expect(approvals.map((r) => r.data), [
        <String, Object?>{},
        {'over_capacity': true},
      ]);
      expect(find.text('Nuevo, por confirmar'), findsNothing);
      expect(find.text('Confirmar inscripción'), findsNothing);
      expect(
        find.text('Inscripción de Sofía Benítez confirmada.'),
        findsOneWidget,
      );
      full = false;
    });

    testWidgets('rechazar pide el motivo y lo saca de la lista', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      var rejected = false;
      await tester.pumpWidget(
        _app(
          {
            ..._base(permissions: ['take_attendance']),
            'GET /classes/81': (_) => {
              'data': classJson(
                date: '2026-10-04',
                students: [
                  classStudentJson(id: 12, name: 'Mateo Benítez'),
                  if (!rejected) _sofia(),
                ],
              ),
            },
            'POST /enrollment-requests/18/reject': (_) {
              rejected = true;
              return {
                'data': requestJson(
                  status: 'rechazada',
                  reason: 'No hay lugar.',
                ),
              };
            },
          },
          const ClassAttendanceScreen(id: 81),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'No hay lugar.');
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'reason': 'No hay lugar.',
      });
      expect(find.text('Sofía Benítez'), findsNothing);
      expect(find.text('Mateo Benítez'), findsOneWidget);
    });

    testWidgets('quien no puede confirmar solo ve el aviso', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._base(permissions: ['take_attendance']),
          'GET /classes/81': (_) => {
            'data': classJson(
              date: '2026-10-04',
              students: [_sofia(canReview: false)],
            ),
          },
        }, const ClassAttendanceScreen(id: 81)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo, por confirmar'), findsOneWidget);
      expect(find.text('Confirmar inscripción'), findsNothing);
    });
  });

  group('lista del mes del grupo', () {
    Map<String, Object?> groupJson({required bool pending}) => {
      'data': {
        'id': 3,
        'name': 'Sub-8',
        'program': {'id': 1, 'name': 'Fútbol'},
        'month': '2026-10',
        'classes': <Object>[],
        'students': [
          {
            'id': 12,
            'full_name': 'Mateo Benítez',
            'present': 3,
            'absent': 0,
            'justified': 0,
            'rate': 100,
          },
          if (pending)
            {
              'id': 40,
              'full_name': 'Sofía Benítez',
              'present': 1,
              'absent': 0,
              'justified': 0,
              'rate': 100,
              'enrollment_request': {'id': 18, 'can_review': true},
            },
        ],
      },
    };

    testWidgets('muestra al nuevo por confirmar y se confirma desde ahí', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      var confirmed = false;
      await tester.pumpWidget(
        _app(
          {
            ..._base(permissions: ['take_attendance']),
            'GET /groups/3': (_) => groupJson(pending: !confirmed),
            'POST /enrollment-requests/18/approve': (_) {
              confirmed = true;
              return {'data': requestJson(status: 'aprobada')};
            },
          },
          const GroupScreen(id: 3),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nuevo, por confirmar'), findsOneWidget);
      final summary = StudentAttendanceSummary.fromJson(
        (groupJson(pending: true)['data']! as Map)['students'][1]
            as Map<String, dynamic>,
      );
      expect(summary.isPendingConfirmation, isTrue);

      await tester.tap(find.text('Confirmar inscripción'));
      await tester.pumpAndSettle();

      expect(
        requests.where((r) => r.path == '/enrollment-requests/18/approve'),
        hasLength(1),
      );
      expect(find.text('Nuevo, por confirmar'), findsNothing);
      expect(find.text('Sofía Benítez'), findsNothing);
    });

    testWidgets('rechazar pide el motivo', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._base(permissions: ['take_attendance']),
            'GET /groups/3': (_) => groupJson(pending: true),
            'POST /enrollment-requests/18/reject': (_) => {
              'data': requestJson(status: 'rechazada', reason: 'Sin lugar.'),
            },
          },
          const GroupScreen(id: 3),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Sin lugar.');
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'reason': 'Sin lugar.',
      });
    });
  });

  testWidgets('si quien la pide puede confirmar, queda confirmada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app({
        ..._base(),
        'POST /enrollment-requests': (_) => {
          'data': {
            ...requestJson(status: 'aprobada'),
            'reviewed_by': 'Laura Gómez',
            'self_approved': true,
          },
        },
      }, const EnrollChildScreen()),
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
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de documento'),
      '7123456',
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Enviar solicitud'));
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.text('Inscripción confirmada'), findsOneWidget);
    expect(
      find.text(
        'Sofía ya está en Sub-8 · Fútbol (2026). Sus cuotas ya aparecen en el '
        'estado de cuenta.',
      ),
      findsOneWidget,
    );
  });

  group('cargar alumno', () {
    test('lee el resultado con la invitación', () {
      final done = RegisteredStudent.fromJson({
        'student': {
          'id': 41,
          'full_name': 'Sofía Benítez',
          'place': 'Sub-8 · Fútbol (2026)',
        },
        'guardian': {'name': 'Rosa Aquino', 'has_account': false},
        'invitation': {
          'link': 'https://app.test/invitacion/abc',
          'whatsapp_url': 'https://wa.me/595981222333?text=hola',
        },
      });
      expect(done.guardianName, 'Rosa Aquino');
      expect(done.whatsappUrl, startsWith('https://wa.me/'));
    });

    Future<void> fill(WidgetTester tester) async {
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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de documento'),
        '7123456',
      );
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.widgetWithText(TextFormField, 'Nombre de la tutora'),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la tutora'),
        'Rosa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido de la tutora'),
        'Aquino',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Celular (WhatsApp)'),
        '0981 222 333',
      );
    }

    testWidgets('da de alta y manda la invitación por WhatsApp', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final launched = <Uri>[];
      await tester.pumpWidget(
        _app(
          {
            ..._base(permissions: ['create_students']),
            'POST /students': (_) => {
              'data': {
                'student': {
                  'id': 41,
                  'full_name': 'Sofía Benítez',
                  'place': 'Sub-8 · Fútbol (2026)',
                },
                'guardian': {'name': 'Rosa Aquino', 'has_account': false},
                'invitation': {
                  'link': 'https://app.test/invitacion/abc',
                  'whatsapp_url': 'https://wa.me/595981222333?text=hola',
                  'expires_on': '2026-10-18',
                },
              },
            },
          },
          const AddStudentScreen(),
          requests: requests,
          launched: launched,
        ),
      );
      await tester.pumpAndSettle();

      // Sin datos no se manda nada.
      await _scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Cargar alumno'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar alumno'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await fill(tester);
      await _scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Cargar alumno'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar alumno'));
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.method == 'POST').data, {
        'first_name': 'Sofía',
        'last_name': 'Benítez',
        'birth_date': '2018-07-02',
        'document': '7123456',
        'season_id': 1,
        'group_id': 3,
        'guardian': {
          'first_name': 'Rosa',
          'last_name': 'Aquino',
          'phone': '0981 222 333',
          'relationship': 'madre',
        },
      });
      expect(find.text('Alumno cargado'), findsOneWidget);
      expect(
        find.text('Sofía Benítez quedó en Sub-8 · Fútbol (2026).'),
        findsOneWidget,
      );

      await tester.tap(find.text('Mandar por WhatsApp'));
      expect(
        launched.single.toString(),
        'https://wa.me/595981222333?text=hola',
      );

      await tester.tap(find.text('Cargar otro'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Nombre'), findsOneWidget);
    });

    testWidgets('si el tutor ya usa la app no hay invitación', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._base(permissions: ['create_students']),
          'POST /students': (_) => {
            'data': {
              'student': {
                'id': 41,
                'full_name': 'Sofía Benítez',
                'place': 'Sub-8 · Fútbol (2026)',
              },
              'guardian': {'name': 'Ana Benítez', 'has_account': true},
              'invitation': null,
            },
          },
        }, const AddStudentScreen()),
      );
      await tester.pumpAndSettle();

      await fill(tester);
      await _scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Cargar alumno'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar alumno'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ana Benítez ya usa Tuku: lo ve en la app.'),
        findsOneWidget,
      );
      expect(find.text('Mandar por WhatsApp'), findsNothing);
    });

    testWidgets('con género: lo manda y la nombra ("Alumna cargada")', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._base(permissions: ['create_students']),
            'POST /students': (_) => {
              'data': {
                'student': {
                  'id': 41,
                  'full_name': 'Sofía Benítez',
                  'place': 'Sub-8 · Fútbol (2026)',
                },
                'guardian': {'name': 'Ana Benítez', 'has_account': true},
                'invitation': null,
              },
            },
          },
          const AddStudentScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await fill(tester);
      await _scrollTo(tester, find.byKey(const Key('gender-female')));
      await tester.tap(find.byKey(const Key('gender-female')));
      await _scrollTo(
        tester,
        find.widgetWithText(FilledButton, 'Cargar alumno'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cargar alumno'));
      await tester.pumpAndSettle();

      expect(
        (requests.lastWhere((r) => r.method == 'POST').data as Map)['gender'],
        'female',
      );
      expect(find.text('Alumna cargada'), findsOneWidget);
    });

    testWidgets('los datos del tutor siguen al parentesco', (tester) async {
      await tester.pumpWidget(
        _app(_base(permissions: ['create_students']), const AddStudentScreen()),
      );
      await tester.pumpAndSettle();

      Future<void> choose(String relationship) async {
        await _scrollTo(tester, find.widgetWithText(ChoiceChip, relationship));
        await tester.tap(find.widgetWithText(ChoiceChip, relationship));
        await tester.pumpAndSettle();
      }

      // Madre (elegida de entrada): "de la tutora".
      await _scrollTo(
        tester,
        find.widgetWithText(TextFormField, 'Nombre de la tutora'),
      );
      expect(
        find.widgetWithText(TextFormField, 'Apellido de la tutora'),
        findsOneWidget,
      );

      await choose('Padre');
      expect(
        find.widgetWithText(TextFormField, 'Nombre del tutor'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Apellido del tutor'),
        findsOneWidget,
      );

      await choose('Abuela');
      expect(
        find.widgetWithText(TextFormField, 'Nombre de la tutora'),
        findsOneWidget,
      );

      // Otro: la palabra de la organización, sin género.
      await choose('Otro');
      expect(
        find.widgetWithText(TextFormField, 'Nombre del tutor'),
        findsOneWidget,
      );
    });
  });
}
