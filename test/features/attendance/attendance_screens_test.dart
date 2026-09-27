import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/attendance/presentation/class_attendance_screen.dart';
import 'package:academia_app/features/attendance/presentation/next_class_card.dart';
import 'package:academia_app/features/attendance/presentation/today_classes_card.dart';
import 'package:academia_app/features/students/presentation/student_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import '../students/student_json.dart';
import 'class_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _organization({List<String> permissions = const []}) => {
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
      'membership': {'roles': [], 'permissions': permissions},
    },
  },
};

Widget _app(
  Routes routes,
  Widget home, {
  List<RequestOptions>? requests,
  DateTime? now,
  PushService? push,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'jakare',
    ),
    apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
    todayProvider.overrideWithValue(DateTime(2026, 9, 28)),
    nowProvider.overrideWithValue(now ?? DateTime(2026, 9, 28, 10)),
    pushServiceProvider.overrideWithValue(push ?? FakePushService()),
  ],
  child: MaterialApp(home: home),
);

void main() {
  group('técnico', () {
    testWidgets('la tarjeta "Hoy" solo aparece con permiso', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /classes': (_) => {
            'data': [classJson()],
          },
        }, const Scaffold(body: TodayClassesCard())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hoy'), findsNothing);
    });

    testWidgets('lista las clases de hoy con las respuestas', (tester) async {
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['take_attendance']),
            'GET /classes': (_) => {
              'data': [
                classJson(),
                classJson(
                  id: 82,
                  attendanceTaken: true,
                  counts: {'present': 16, 'absent': 3, 'justified': 0},
                ),
              ],
            },
          },
          const Scaffold(
            body: SingleChildScrollView(child: TodayClassesCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('1 van · 1 no van · 1 sin responder'), findsOneWidget);
      expect(find.text('Tomar asistencia'), findsOneWidget);
      expect(find.text('Tomada: 16 presentes · 3 ausentes'), findsOneWidget);
      expect(find.text('Ver o corregir asistencia'), findsOneWidget);
    });

    testWidgets('marca ausentes con un toque y guarda', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['take_attendance']),
            'GET /classes/81': (_) => {
              'data': classJson(students: threeStudents()),
            },
            'PUT /classes/81/attendance': (_) => {
              'data': classJson(
                attendanceTaken: true,
                students: [
                  classStudentJson(
                    id: 12,
                    name: 'Mateo Benítez',
                    status: 'justificado',
                    response: 'no_va',
                  ),
                  classStudentJson(
                    id: 13,
                    name: 'Lucas Ortiz',
                    status: 'presente',
                  ),
                  classStudentJson(
                    id: 14,
                    name: 'Tomás Villalba',
                    status: 'ausente',
                  ),
                ],
              ),
            },
          },
          const ClassAttendanceScreen(id: 81),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avisó que no va'), findsOneWidget);
      expect(find.text('2 presentes'), findsOneWidget);
      expect(find.text('1 justificado'), findsOneWidget);
      expect(find.text('Guardar asistencia (2 de 3)'), findsOneWidget);

      await tester.tap(find.text('Tomás Villalba'));
      await tester.pump();
      expect(find.text('1 presente'), findsOneWidget);
      expect(find.text('1 ausente'), findsOneWidget);

      await tester.tap(find.text('Guardar asistencia (1 de 3)'));
      await tester.pumpAndSettle();

      final marks = (requests.last.data as Map)['marks'] as List;
      expect(marks.map((m) => m['status']), [
        'justificado',
        'presente',
        'ausente',
      ]);
      expect(find.text('Asistencia guardada.'), findsOneWidget);
      expect(find.text('Asistencia guardada'), findsOneWidget);
    });

    testWidgets('si no se pudo guardar, ofrece reintentar', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /classes/81': (_) => {
            'data': classJson(students: threeStudents()),
          },
          'PUT /classes/81/attendance': (options) =>
              throw apiError(options, 503, {'message': 'Sin conexión.'}),
        }, const ClassAttendanceScreen(id: 81)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tomás Villalba'));
      await tester.pump();
      await tester.tap(find.text('Guardar asistencia (1 de 3)'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No se pudo guardar: Sin conexión.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('1 ausente'), findsOneWidget);
    });

    testWidgets('justificar con motivo desde las opciones', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /classes/81': (_) => {
            'data': classJson(students: threeStudents()),
          },
        }, const ClassAttendanceScreen(id: 81)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Más opciones').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Justificado').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Viaje');
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(find.text('Viaje'), findsOneWidget);
      expect(find.text('2 justificados'), findsOneWidget);
    });

    testWidgets('suspender la clase avisa y bloquea la planilla', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /classes/81': (_) => {
              'data': classJson(students: threeStudents()),
            },
            'POST /classes/81/suspension': (_) => {
              'data': classJson(
                status: 'suspendida',
                suspensionReason: 'Lluvia',
              ),
            },
          },
          const ClassAttendanceScreen(id: 81),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspender clase'));
      await tester.pumpAndSettle();
      expect(find.text('Se avisa a los tutores del grupo.'), findsOneWidget);
      await tester.tap(find.text('Suspender'));
      await tester.pumpAndSettle();

      expect(requests.last.data, {'reason': 'Lluvia'});
      expect(find.text('Clase suspendida: Lluvia.'), findsOneWidget);
      expect(find.textContaining('Guardar asistencia'), findsNothing);
    });

    testWidgets('pasados los días de corrección es solo lectura', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /classes/81': (_) => {
            'data': classJson(
              editable: false,
              attendanceTaken: true,
              students: [
                classStudentJson(
                  id: 12,
                  name: 'Mateo Benítez',
                  status: 'presente',
                ),
              ],
            ),
          },
        }, const ClassAttendanceScreen(id: 81)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Ya no se puede corregir desde la app.'),
        findsOneWidget,
      );
      expect(find.textContaining('Guardar asistencia'), findsNothing);
    });
  });

  group('tutor', () {
    Widget card(
      Routes routes, {
      List<RequestOptions>? requests,
      DateTime? now,
      PushService? push,
    }) => _app(
      {..._organization(), ...routes},
      const Scaffold(body: SingleChildScrollView(child: NextClassesList())),
      requests: requests,
      now: now,
      push: push,
    );

    testWidgets('responde "No va" y ve la respuesta', (tester) async {
      final requests = <RequestOptions>[];
      String? response;
      await tester.pumpWidget(
        card({
          'GET /agenda': (_) => {
            'data': [agendaItemJson(response: response, classReminders: true)],
          },
          'PUT /classes/81/students/12/response': (options) {
            response = (options.data as Map)['going'] == true ? 'va' : 'no_va';
            return {'data': agendaItemJson(response: response)};
          },
        }, requests: requests),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mateo tiene Fútbol hoy a las 17:00'), findsOneWidget);
      expect(find.text('¿Lo llevás hoy?'), findsOneWidget);

      await tester.tap(find.text('No va'));
      await tester.pumpAndSettle();

      expect(requests.firstWhere((r) => r.method == 'PUT').data, {
        'going': false,
      });
      expect(find.text('Avisaste que no va.'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);
    });

    testWidgets('después de que empezó ya no se puede responder', (
      tester,
    ) async {
      await tester.pumpWidget(
        card({
          'GET /agenda': (_) => {
            'data': [agendaItemJson(classReminders: true)],
          },
        }, now: DateTime(2026, 9, 28, 17, 5)),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Lo llevás hoy?'), findsNothing);
      expect(find.text('No respondiste.'), findsOneWidget);
    });

    testWidgets('clase suspendida', (tester) async {
      await tester.pumpWidget(
        card({
          'GET /agenda': (_) => {
            'data': [
              {
                ...agendaItemJson(classReminders: true, canRespond: false),
                'class': classJson(
                  status: 'suspendida',
                  suspensionReason: 'Lluvia',
                ),
              },
            ],
          },
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clase suspendida: Lluvia.'), findsOneWidget);
      expect(find.text('No va'), findsNothing);
    });

    testWidgets('pregunta una vez si quiere el aviso y pide permiso', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final push = FakePushService();
      bool? reminders;
      await tester.pumpWidget(
        card(
          {
            'GET /agenda': (_) => {
              'data': [
                agendaItemJson(date: '2026-10-01', classReminders: reminders),
              ],
            },
            'PUT /students/12/reminders': (options) {
              reminders = (options.data as Map)['enabled'] as bool;
              return {
                'data': {'class_reminders': reminders},
              };
            },
          },
          requests: requests,
          push: push,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Mateo tiene Fútbol el jueves 1/10 a las 17:00'),
        findsOneWidget,
      );
      expect(
        find.text('¿Querés que te avise los días de clase de Mateo?'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sí, avisame'));
      await tester.pumpAndSettle();

      expect(requests.firstWhere((r) => r.method == 'PUT').data, {
        'enabled': true,
      });
      expect(push.enabled, 1);
      expect(
        find.text('Listo: te avisamos los días de clase de Mateo.'),
        findsOneWidget,
      );
      expect(find.text('Sí, avisame'), findsNothing);
    });

    testWidgets('"Ahora no" no vuelve a preguntar ni pide permiso', (
      tester,
    ) async {
      final push = FakePushService();
      bool? reminders;
      await tester.pumpWidget(
        card({
          'GET /agenda': (_) => {
            'data': [agendaItemJson(classReminders: reminders)],
          },
          'PUT /students/12/reminders': (options) {
            reminders = (options.data as Map)['enabled'] as bool;
            return {
              'data': {'class_reminders': reminders},
            };
          },
        }, push: push),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();

      expect(reminders, isFalse);
      expect(push.enabled, 0);
      expect(find.text('Ahora no'), findsNothing);
    });
  });

  testWidgets('la ficha muestra la asistencia del mes y el aviso', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    final push = FakePushService(allow: false);
    await tester.pumpWidget(
      _app(
        {
          ..._organization(),
          'GET /students/12': (_) => {
            'data': {...studentDetailJson(), 'class_reminders': false},
          },
          'GET /students/12/account': (_) => {
            'data': {'balance': 0, 'overdue': 0, 'students': [], 'charges': []},
          },
          'GET /students/12/attendance': (_) => {
            'data': {
              'month': '2026-09',
              'present': 7,
              'absent': 1,
              'justified': 1,
              'rate': 78,
              'classes': [
                {...classJson(date: '2026-09-21'), 'attendance': 'ausente'},
              ],
            },
          },
          'PUT /students/12/reminders': (_) => {
            'data': {'class_reminders': true},
          },
        },
        const StudentScreen(id: 12),
        requests: requests,
        push: push,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Ausente'), 200);
    expect(
      find.text(
        'Septiembre 2026: vino al 78% de las clases '
        '(7 presentes, 1 ausente, 1 justificado).',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Avisarme los días de clase'));
    await tester.pumpAndSettle();

    expect(requests.firstWhere((r) => r.method == 'PUT').data, {
      'enabled': true,
    });
    expect(push.enabled, 1);
    expect(find.textContaining('permití las notificaciones'), findsOneWidget);
  });
}
