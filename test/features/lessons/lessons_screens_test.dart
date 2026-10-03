import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/lessons/data/models.dart';
import 'package:academia_app/features/lessons/presentation/book_lesson_screen.dart';
import 'package:academia_app/features/lessons/presentation/booking_sheet.dart';
import 'package:academia_app/features/lessons/presentation/bookings_screen.dart';
import 'package:academia_app/features/lessons/presentation/lesson_profile_screen.dart';
import 'package:academia_app/features/lessons/presentation/lessons_card.dart';
import 'package:academia_app/features/lessons/presentation/teacher_students_screen.dart';
import 'package:academia_app/features/lessons/presentation/today_lessons_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';
import 'lesson_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _organization({
  List<String> permissions = const [],
  List<String> features = const ['private_lessons'],
}) => {
  'GET /me': (_) => {
    'data': {
      'name': 'Ana',
      'email': 'ana@test.com',
      'organizations': [
        {'slug': 'profe', 'name': 'Clases de Carlos'},
      ],
    },
  },
  'GET /organization': (_) => {
    'data': {
      'slug': 'profe',
      'name': 'Clases de Carlos',
      'features': features,
      'membership': {'roles': [], 'permissions': permissions},
    },
  },
};

Widget _app(
  Routes routes,
  Widget home, {
  List<RequestOptions>? requests,
  DateTime? now,
}) => ProviderScope(
  overrides: [
    sessionStorageProvider.overrideWithValue(
      InMemorySessionStorage()
        ..token = 't'
        ..organization = 'profe',
    ),
    offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
    apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
    todayProvider.overrideWithValue(DateTime(2026, 9, 28)),
    nowProvider.overrideWithValue(now ?? DateTime(2026, 9, 28, 10)),
    pushServiceProvider.overrideWithValue(FakePushService()),
  ],
  child: MaterialApp.router(
    routerConfig: GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/inicio',
          builder: (_, _) => const Scaffold(body: Text('Inicio')),
        ),
      ],
    ),
  ),
);

/// Las tarjetas no dibujan nada mientras cargan (no hay frames que esperar):
/// se avanza el reloj hasta que terminan las peticiones encadenadas.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Map<String, Object?> _slots() => {
  'data': {
    'duration_minutes': 60,
    'days': [
      {
        'date': '2026-09-29',
        'times': ['15:00', '16:00'],
      },
      {
        'date': '2026-10-01',
        'times': ['18:00'],
      },
    ],
  },
};

void main() {
  group('alumno o tutor', () {
    testWidgets('la tarjeta muestra el paquete y ofrece reservar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /lessons/teachers': (_) => {
            'data': [teacherJson()],
          },
        }, const Scaffold(body: SingleChildScrollView(child: LessonsCard()))),
      );
      await _settle(tester);

      expect(find.text('Clases con Carlos Gómez'), findsOneWidget);
      expect(
        find.text('Paquete: te quedan 3 de 4 · válido del 20/9 al 18/11'),
        findsOneWidget,
      );
      expect(find.text('Reservar clase'), findsOneWidget);
      // Le quedan 2 libres: todavía no se ofrece otro paquete.
      expect(find.text('Comprar paquete'), findsNothing);
    });

    testWidgets('sin el módulo no aparece', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(features: const []),
          'GET /lessons/teachers': (_) => {
            'data': [teacherJson()],
          },
        }, const Scaffold(body: LessonsCard())),
      );
      await _settle(tester);
      expect(find.text('Clases con Carlos Gómez'), findsNothing);
    });

    testWidgets('paquete por vencer: lo resalta y ofrece comprar otro', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /lessons/teachers': (_) => {
            'data': [
              teacherJson(
                students: [
                  {
                    'student': studentJson(),
                    'pack': packJson(
                      used: 3,
                      reserved: 0,
                      expiresOn: '2026-10-01',
                    ),
                    'next_booking': null,
                  },
                ],
              ),
            ],
          },
        }, const Scaffold(body: SingleChildScrollView(child: LessonsCard()))),
      );
      await _settle(tester);

      expect(
        find.text('Vence en 3 días: reservá las clases que te quedan.'),
        findsOneWidget,
      );
      expect(find.text('Comprar paquete'), findsOneWidget);

      await tester.tap(find.text('Comprar paquete'));
      await tester.pumpAndSettle();
      expect(find.text('4 clases · ₲ 100.000'), findsOneWidget);
      expect(
        find.text(
          '₲ 25.000 c/u, ahorrás ₲ 40.000 · vale 60 días desde que lo pagás',
        ),
        findsOneWidget,
      );
    });

    testWidgets('reserva día y hora con el resumen de lo que se cobra', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /lessons/teachers': (_) => {
              'data': [teacherJson()],
            },
            'GET /lessons/teachers/7/slots': (_) => _slots(),
            'POST /bookings': (_) => {
              'data': bookingJson(date: '2026-09-29', startsAt: '16:00'),
            },
            'GET /bookings': (_) => {
              'data': {'upcoming': [], 'past': []},
            },
          },
          const BookLessonScreen(teacherId: 7, studentId: 12),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reservar con Carlos'), findsOneWidget);
      expect(find.text('Elegí el día.'), findsOneWidget);
      // Un solo alumno a cargo: no se pregunta para quién.
      expect(find.text('¿Para quién?'), findsNothing);

      await tester.tap(find.text('Mañana'));
      await tester.pump();
      expect(find.text('Elegí la hora.'), findsOneWidget);
      await tester.tap(find.text('16:00'));
      await tester.pump();

      expect(
        find.text('Martes 29/9 a las 16:00 (hasta las 17:00) con Carlos'),
        findsOneWidget,
      );
      expect(
        find.text('Se descuenta 1 clase del paquete (te quedaría 1).'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();

      final post = requests.firstWhere((r) => r.method == 'POST');
      expect(post.data, {
        'teacher_id': 7,
        'student_id': 12,
        'date': '2026-09-29',
        'starts_at': '16:00',
      });
      expect(find.text('Reservado: mañana a las 16:00.'), findsOneWidget);
    });

    testWidgets('si otro ganó el horario, avisa y vuelve a pedir las horas', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /lessons/teachers': (_) => {
              'data': [teacherJson()],
            },
            'GET /lessons/teachers/7/slots': (_) => _slots(),
            'POST /bookings': (o) => throw apiError(o, 422, {
              'message': 'Ese horario ya se reservó. Elegí otro.',
              'errors': {
                'starts_at': ['Ese horario ya se reservó. Elegí otro.'],
              },
            }),
          },
          const BookLessonScreen(teacherId: 7, studentId: 12),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mañana'));
      await tester.pump();
      await tester.tap(find.text('15:00'));
      await tester.pump();
      await tester.tap(find.text('Reservar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ese horario ya se reservó. Elegí otro.'),
        findsOneWidget,
      );
      expect(find.text('Elegí la hora.'), findsOneWidget);
      expect(
        requests.where((r) => r.path == '/lessons/teachers/7/slots').length,
        2,
      );
    });

    testWidgets('con varios hijos pregunta para quién', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /lessons/teachers': (_) => {
            'data': [
              teacherJson(
                students: [
                  {
                    'student': studentJson(),
                    'pack': null,
                    'next_booking': null,
                  },
                  {
                    'student': studentJson(id: 13, first: 'Lucía'),
                    'pack': null,
                    'next_booking': null,
                  },
                ],
              ),
            ],
          },
          'GET /lessons/teachers/7/slots': (_) => _slots(),
        }, const BookLessonScreen(teacherId: 7)),
      );
      await tester.pumpAndSettle();

      expect(find.text('¿Para quién?'), findsOneWidget);
      expect(find.text('Elegí para quién es la clase.'), findsOneWidget);
      await tester.tap(find.text('Lucía'));
      await tester.pump();
      await tester.tap(find.text('Jue 1/10'));
      await tester.pump();
      await tester.tap(find.text('18:00'));
      await tester.pump();
      expect(
        find.text('Se cobra ₲ 35.000 el día de la clase.'),
        findsOneWidget,
      );
    });

    testWidgets('cancela una reserva con confirmación', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /bookings': (_) => {
              'data': {
                'upcoming': [bookingJson(date: '2026-09-29')],
                'past': [],
              },
            },
            'DELETE /bookings/40': (_) => {
              'data': bookingJson(status: 'cancelada_alumno', canCancel: false),
            },
          },
          const BookingsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mañana · 16:00 a 17:00'), findsOneWidget);
      expect(find.text('Con Carlos Gómez · Con el paquete'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(requests.any((r) => r.method == 'DELETE'), isTrue);
      expect(find.text('Clase cancelada.'), findsOneWidget);
    });
  });

  group('profesor', () {
    testWidgets('la tarjeta de hoy solo aparece con permiso', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /teacher/bookings': (_) => {
            'data': [bookingJson()],
          },
        }, const Scaffold(body: TodayLessonsCard())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clases particulares de hoy'), findsNothing);
    });

    testWidgets('marca "Vino" con paquete desde la ficha rápida', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
            'GET /teacher/bookings': (_) => {
              'data': [bookingJson(pack: packJson())],
            },
            'PUT /teacher/bookings/40/attendance': (_) => {
              'data': bookingJson(
                status: 'asistio',
                canCancel: false,
                pack: packJson(used: 2, reserved: 0),
              ),
            },
          },
          const Scaffold(
            body: SingleChildScrollView(child: TodayLessonsCard()),
          ),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('16:00 · Mateo Benítez'), findsOneWidget);
      expect(find.text('Paquete · le quedan 3 de 4'), findsOneWidget);

      await tester.tap(find.text('16:00 · Mateo Benítez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vino'));
      await tester.pumpAndSettle();

      final put = requests.firstWhere((r) => r.method == 'PUT');
      expect(put.data, {'attended': true});
      expect(
        find.text('Se descontó 1 clase. Le quedan 2 de 4.'),
        findsOneWidget,
      );
      // Con paquete no hay nada que cobrar.
      expect(find.textContaining('Cobrar'), findsNothing);
    });

    testWidgets('cobra la clase suelta en efectivo', (tester) async {
      final requests = <RequestOptions>[];
      final booking = bookingJson(
        payment: 'suelta',
        status: 'asistio',
        canCancel: false,
        charge: {'id': 301, 'amount': 35000, 'pending': 35000},
      );
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
            'GET /teacher/bookings': (_) => {
              'data': [booking],
            },
            'POST /teacher/payments': (_) => {
              'data': {
                'receipt_number': '000123',
                'amount': 35000,
                'applied': 35000,
                'credit': 0,
                'message': 'Cobrado ₲ 35.000.',
                'booking': {
                  ...booking,
                  'charge': {'id': 301, 'amount': 35000, 'pending': 0},
                },
                'pack': null,
              },
            },
          },
          const Scaffold(
            body: SingleChildScrollView(child: TodayLessonsCard()),
          ),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vino · Suelta · debe ₲ 35.000'), findsOneWidget);
      await tester.tap(find.text('16:00 · Mateo Benítez'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobrar ₲ 35.000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar cobro'));
      await tester.pumpAndSettle();

      final post = requests.firstWhere((r) => r.method == 'POST');
      expect(post.data, {
        'student_id': 12,
        'amount': 35000,
        'method': 'efectivo',
        'booking_id': 40,
      });
      expect(find.text('Cobrado ₲ 35.000.'), findsOneWidget);
      expect(find.text('Cobrar ₲ 35.000'), findsNothing);
    });

    testWidgets('una clase futura no se marca pero se puede cancelar', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
          },
          Scaffold(
            body: BookingSheet(
              booking: Booking.fromJson(bookingJson(date: '2026-10-02')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Vas a poder marcar si vino el día de la clase.'),
        findsOneWidget,
      );
      expect(find.text('Vino'), findsNothing);
      expect(find.text('Cancelar clase'), findsOneWidget);
    });

    testWidgets('alumnos: extender un paquete por vencer', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
            'GET /teacher/students': (_) => {
              'data': [
                {
                  'student': studentJson(),
                  'pack': packJson(expiresOn: '2026-10-01'),
                  'debt': 35000,
                  'credit': 0,
                  'last_booking': '2026-09-25',
                },
              ],
            },
            'POST /teacher/packs/5/extend': (_) => {
              'data': packJson(expiresOn: '2026-10-16'),
            },
          },
          const TeacherStudentsScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Paquete: le quedan 3 de 4 · válido del 20/9 al 1/10'),
        findsOneWidget,
      );
      expect(find.text('Vence en 3 días'), findsOneWidget);
      expect(find.text('Debe ₲ 35.000'), findsOneWidget);

      await tester.tap(find.text('Extender'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+15 días'));
      await tester.pumpAndSettle();

      final post = requests.firstWhere((r) => r.method == 'POST');
      expect(post.data, {'expires_on': '2026-10-16'});
      expect(
        find.text('Paquete extendido hasta el 16/10/2026.'),
        findsOneWidget,
      );
    });

    testWidgets('ajustes: agrega un paquete con validez y guarda', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
            'GET /me/lesson-profile': (_) => profileJson(),
            'PUT /me/lesson-profile': (o) => {'data': o.data},
          },
          const LessonProfileScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Tus alumnos van a ver: lun 15:00, 16:00, 17:00'),
        findsOneWidget,
      );

      await tester.tap(find.text('Agregar paquete'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Precio del paquete'),
        '100000',
      );
      await tester.pump();
      expect(
        find.text('₲ 25.000 por clase · ahorran ₲ 40.000'),
        findsOneWidget,
      );
      await tester.tap(find.text('Personalizado'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Cantidad de días'),
        '45',
      );
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();

      expect(find.text('4 clases · ₲ 100.000'), findsOneWidget);
      expect(
        find.text('₲ 25.000 por clase · vale 45 días desde que lo pagás'),
        findsOneWidget,
      );

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      final put = requests.firstWhere((r) => r.method == 'PUT');
      final data = put.data as Map<String, Object?>;
      expect(data['packs'], [
        {'classes': 4, 'price': 100000, 'valid_days': 45},
      ]);
      expect(find.text('Guardado.'), findsOneWidget);
    });

    testWidgets('ajustes: no guarda sin precio', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['teach_lessons']),
            'GET /me/lesson-profile': (_) => profileJson(),
          },
          const LessonProfileScreen(),
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Precio por clase'),
        '',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Poné el precio de la clase suelta.'), findsOneWidget);
      expect(requests.any((r) => r.method == 'PUT'), isFalse);
    });
  });
}
