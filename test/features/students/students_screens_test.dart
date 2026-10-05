import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/home/presentation/home_screen.dart';
import 'package:academia_app/features/students/presentation/student_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'student_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _routes({
  List<String> roles = const ['tutor'],
  List<Map<String, Object?>>? students,
  Map<String, Object?>? student,
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
      'terminology': {'program': 'Deporte', 'group': 'Categoría'},
      'features': <String>[],
      'membership': {
        'roles': [
          for (final role in roles) {'name': role, 'label': role},
        ],
      },
    },
  },
  'GET /students': (_) => {
    'data': students ?? [studentSummaryJson()],
  },
  'GET /students/12': (_) => {'data': student ?? studentDetailJson()},
  'GET /account': (_) => {
    'data': {'balance': 0, 'overdue': 0, 'students': [], 'charges': []},
  },
  'GET /students/12/account': (_) => {
    'data': {'balance': 0, 'overdue': 0, 'students': [], 'charges': []},
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
  child: MaterialApp(home: home),
);

void main() {
  group('inicio', () {
    testWidgets('el tutor ve a sus hijos con grupo y estado', (tester) async {
      await tester.pumpWidget(
        _app(
          _routes(
            students: [
              studentSummaryJson(),
              studentSummaryJson(
                id: 13,
                firstName: 'Sofía',
                status: 'suspendido',
              ),
            ],
          ),
          const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis hijos'), findsOneWidget);
      expect(find.text('Mateo Benítez'), findsOneWidget);
      expect(find.text('10 años · Sub-10 · Fútbol'), findsNWidgets(2));
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Suspendido'), findsOneWidget);
    });

    testWidgets('tutor sin hijos cargados', (tester) async {
      await tester.pumpWidget(
        _app(_routes(students: const []), const HomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay hijos cargados.'), findsOneWidget);
      expect(find.text('Inscribir a mi hijo'), findsOneWidget);
    });

    testWidgets('sin rol de tutor ni alumnos no muestra la sección', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _routes(roles: const ['tesorero'], students: const []),
          const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis hijos'), findsNothing);
    });

    testWidgets('el alumno adulto ve sus inscripciones', (tester) async {
      await tester.pumpWidget(
        _app(
          _routes(
            roles: const [],
            students: [studentSummaryJson(isSelf: true)],
          ),
          const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis inscripciones'), findsOneWidget);
    });
  });

  group('ficha', () {
    testWidgets('muestra grupo, horarios, tutores y ficha médica', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_routes(), const StudentScreen(id: 12)));
      await tester.pumpAndSettle();

      expect(find.text('Mateo Benítez'), findsOneWidget);
      expect(find.text('Categoría: Sub-10'), findsOneWidget);
      expect(find.text('Deporte: Fútbol · Temporada 2026'), findsOneWidget);
      expect(find.text('Becado'), findsOneWidget);
      expect(find.text('Lun 17:00–18:30 · Cancha 1'), findsOneWidget);
      expect(find.text('Técnico: Carlos Gómez'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Ana Benítez (vos)'), 200);
      expect(find.text('Ana Benítez (vos)'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Penicilina'), 200);
      expect(find.text('Ficha médica'), findsOneWidget);
      expect(find.text('Penicilina'), findsOneWidget);
      expect(find.text('Vigente hasta 01/03/2027'), findsOneWidget);
    });

    testWidgets('muestra las fechas y marca la temporada que no empezó', (
      tester,
    ) async {
      final detail = studentDetailJson();
      final enrollment =
          (detail['enrollments']! as List).first as Map<String, Object?>;
      await tester.pumpWidget(
        _app(
          _routes(
            student: {
              ...detail,
              'enrollments': [
                {
                  ...enrollment,
                  'season': {
                    'id': 1,
                    'name': '2026',
                    'starts_on': '2026-01-01',
                    'ends_on': '2026-12-31',
                  },
                },
                {
                  ...enrollment,
                  'id': 41,
                  'status': 'activo',
                  'season': {
                    'id': 3,
                    'name': 'Colonia de verano 2027',
                    'starts_on': '2027-01-04',
                    'ends_on': '2027-01-17',
                  },
                },
              ],
            },
          ),
          const StudentScreen(id: 12),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Del 01/01/2026 al 31/12/2026'), findsOneWidget);
      expect(find.text('Becado'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Empieza el 04/01/2027'), 200);
      await tester.pumpAndSettle();
      expect(
        find.text('Deporte: Fútbol · Temporada Colonia de verano 2027'),
        findsOneWidget,
      );
      expect(find.text('Empieza el 04/01/2027'), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
    });

    testWidgets('sin permiso no muestra la ficha médica', (tester) async {
      await tester.pumpWidget(
        _app(
          _routes(
            student: studentDetailJson(
              withMedical: false,
              canViewMedical: false,
            ),
          ),
          const StudentScreen(id: 12),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ficha médica'), findsNothing);
      expect(find.text('Penicilina'), findsNothing);
    });

    testWidgets('avisa si el apto médico venció', (tester) async {
      await tester.pumpWidget(
        _app(
          _routes(student: studentDetailJson(fitUntil: '2026-03-01')),
          const StudentScreen(id: 12),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('El apto médico venció el 01/03/2026.'),
        200,
      );

      expect(find.text('El apto médico venció el 01/03/2026.'), findsOneWidget);
    });

    testWidgets('un alumno ajeno muestra el error de la API', (tester) async {
      await tester.pumpWidget(
        _app({
          ..._routes(),
          'GET /students/12': (options) =>
              throw apiError(options, 404, {'message': 'No encontrado.'}),
        }, const StudentScreen(id: 12)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No encontrado.'), findsOneWidget);
    });
  });
}
