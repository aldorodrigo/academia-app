import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/calendar/data/models.dart';
import 'package:academia_app/features/calendar/presentation/calendar_screen.dart';
import 'package:academia_app/features/calendar/presentation/calendar_sync_screen.dart';
import 'package:academia_app/features/calendar/presentation/event_form_screen.dart';
import 'package:academia_app/features/calendar/presentation/event_screen.dart';
import 'package:academia_app/features/calendar/presentation/upcoming_events_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes.dart';
import '../students/student_json.dart';
import 'calendar_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

Routes _organization({
  List<String> permissions = const [],
  List<String> features = const [],
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
      'features': features,
      'membership': {'roles': [], 'permissions': permissions},
    },
  },
};

Routes _students(List<Map<String, Object?>> students) => {
  'GET /students': (_) => {'data': students},
};

/// La app con el calendario y las pantallas a las que lleva.
Widget _app(
  Routes routes, {
  String initial = '/calendario',
  List<RequestOptions>? requests,
  List<Uri>? launched,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/calendario',
        builder: (_, state) => CalendarScreen(
          initialDate: DateTime.tryParse(
            state.uri.queryParameters['fecha'] ?? '',
          ),
        ),
        routes: [
          GoRoute(
            path: 'sincronizar',
            builder: (_, _) => const CalendarSyncScreen(),
          ),
          GoRoute(
            path: 'nuevo',
            builder: (_, state) => EventFormScreen(
              kind: EventKind.parse(state.uri.queryParameters['tipo']),
              date: DateTime.tryParse(state.uri.queryParameters['fecha'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/eventos/:id',
        builder: (_, state) =>
            EventScreen(id: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/clases/:id',
        builder: (_, state) =>
            Scaffold(body: Text('Clase ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/inicio',
        builder: (_, _) => const Scaffold(body: UpcomingEventsCard()),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        InMemorySessionStorage()
          ..token = 't'
          ..organization = 'jakare',
      ),
      offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
      apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
      todayProvider.overrideWithValue(DateTime(2026, 10, 5)),
      nowProvider.overrideWithValue(DateTime(2026, 10, 5, 10)),
      pushServiceProvider.overrideWithValue(FakePushService()),
      urlLauncherProvider.overrideWithValue((uri) async {
        launched?.add(uri);
        return true;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Para ver el formulario entero (la lista no dibuja lo que no se ve).
const _tall = Size(400, 2000);

/// Pantalla de teléfono (alta, para ver el mes entero).
void _phone(WidgetTester tester, {Size size = const Size(400, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('tutor', () {
    testWidgets('mes con marcas, día elegido y "¿Lo llevás?" desde la clase', (
      tester,
    ) async {
      _phone(tester);
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app({
          ..._organization(),
          ..._students([studentSummaryJson()]),
          'GET /calendar': (_) => calendarJson(
            classes: [
              calendarClassJson(
                date: '2026-10-05',
                students: [calendarStudentJson()],
              ),
              calendarClassJson(
                id: 82,
                date: '2026-10-07',
                status: 'suspendida',
                suspensionReason: 'Día del Docente',
                dayOffId: 9,
                students: [calendarStudentJson()],
              ),
            ],
            events: [eventJson(), dayOffJson()],
          ),
          'PUT /classes/81/students/12/response': (_) => {
            'data': {
              'student': {'id': 12, 'first_name': 'Mateo'},
              'class': calendarClassJson(),
              'response': 'va',
              'can_respond': true,
            },
          },
          'GET /agenda': (_) => {'data': []},
        }, requests: requests),
      );
      await tester.pumpAndSettle();

      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(find.text('Hoy, lunes 5 de octubre'), findsOneWidget);
      expect(find.text('Fútbol · Sub-10 — Mateo'), findsOneWidget);
      expect(find.text('¿Lo llevás?'), findsOneWidget);
      expect(
        find.bySemanticsLabel('lunes 5 de octubre, hoy, 1 clase'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'miércoles 7 de octubre, 1 clase suspendida, sin clases',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('domingo 11 de octubre, 1 evento'),
        findsOneWidget,
      );
      final calendar = requests.firstWhere((r) => r.path == '/calendar');
      expect(calendar.queryParameters, {
        'from': '2026-09-28',
        'to': '2026-11-08',
      });

      // La clase: el tutor responde desde la hoja.
      await tester.tap(find.text('Fútbol · Sub-10 — Mateo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, va'));
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (r) =>
              r.method == 'PUT' &&
              r.path == '/classes/81/students/12/response' &&
              (r.data as Map)['going'] == true,
        ),
        isTrue,
      );
    });

    testWidgets('día sin clase arriba y evento tachado si se canceló', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app({
          ..._organization(),
          ..._students([studentSummaryJson()]),
          'GET /calendar': (_) => calendarJson(
            classes: [
              calendarClassJson(
                date: '2026-10-07',
                status: 'suspendida',
                suspensionReason: 'Día del Docente',
                dayOffId: 9,
              ),
            ],
            events: [
              dayOffJson(),
              eventJson(id: 8, startsOn: '2026-10-07', cancelled: true),
            ],
          ),
        }, initial: '/calendario?fecha=2026-10-07'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin clases: Día del Docente'), findsOneWidget);
      expect(find.text('Para: Sub-10'), findsOneWidget);
      expect(find.text('Suspendida: Día del Docente'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
    });

    testWidgets('elegir un hijo filtra el calendario', (tester) async {
      _phone(tester);
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app({
          ..._organization(),
          ..._students([
            studentSummaryJson(),
            studentSummaryJson(id: 13, firstName: 'Sofía'),
          ]),
          'GET /calendar': (_) => calendarJson(),
        }, requests: requests),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no hay clases ni eventos este mes.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sofía'));
      await tester.pumpAndSettle();
      expect(
        requests.where((r) => r.path == '/calendar').last.queryParameters,
        containsPair('student_id', 13),
      );
    });

    testWidgets('error con reintentar', (tester) async {
      _phone(tester);
      var fail = true;
      await tester.pumpWidget(
        _app({
          ..._organization(),
          ..._students([]),
          'GET /calendar': (options) {
            if (fail) {
              throw apiError(options, 500, {'message': 'Se cayó el servidor.'});
            }
            return calendarJson(classes: [calendarClassJson()]);
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Se cayó el servidor.'), findsOneWidget);

      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Fútbol · Sub-10'), findsOneWidget);
    });
  });

  group('técnico', () {
    testWidgets('la clase abre la asistencia y puede publicar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app({
          ..._organization(permissions: ['take_attendance', 'publish_events']),
          ..._students([]),
          'GET /groups': (_) => {'data': []},
          'GET /calendar': (_) => calendarJson(
            classes: [calendarClassJson(canTakeAttendance: true)],
          ),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Publicar'), findsOneWidget);

      await tester.tap(find.text('Fútbol · Sub-10'));
      await tester.pumpAndSettle();
      expect(find.text('Clase 81'), findsOneWidget);
    });

    testWidgets(
      'sin permiso no hay "Publicar"; en pantalla ancha, dos paneles',
      (tester) async {
        _phone(tester, size: const Size(1100, 800));
        await tester.pumpWidget(
          _app({
            ..._organization(),
            ..._students([]),
            'GET /calendar': (_) => calendarJson(
              classes: [calendarClassJson()],
              events: [eventJson()],
            ),
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('Publicar'), findsNothing);
        // La celda grande muestra los títulos del día.
        expect(find.text('Apertura Sub-10'), findsOneWidget);
        expect(find.text('17:00 Sub-10'), findsOneWidget);
        expect(find.byType(VerticalDivider), findsOneWidget);
      },
    );
  });

  group('publicar', () {
    testWidgets(
      'técnico con un grupo: elegido, sin "Todo el club" y vista previa',
      (tester) async {
        _phone(tester, size: _tall);
        final requests = <RequestOptions>[];
        await tester.pumpWidget(
          _app(
            {
              ..._organization(permissions: ['publish_events']),
              'GET /events/options': (_) => eventOptionsJson(
                canTargetOrganization: false,
                groups: [
                  {
                    'id': 3,
                    'name': 'Sub-10',
                    'program': {'id': 1, 'name': 'Fútbol'},
                  },
                ],
              ),
              'POST /events/preview': (_) =>
                  previewJson(families: 12, instructors: 1),
              'POST /events': (options) {
                if ((options.data as Map)['title'] == '') {
                  throw apiError(options, 422, {
                    'errors': {
                      'title': ['Escribí un título.'],
                    },
                  });
                }
                return {'data': eventJson()};
              },
            },
            initial: '/calendario/nuevo?tipo=evento&fecha=2026-10-11',
            requests: requests,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.text('Nuevo evento'), findsOneWidget);
        expect(find.text('Todo el club'), findsNothing);
        final chip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Sub-10'),
        );
        expect(chip.selected, isTrue);
        expect(
          find.text('Les llega a 12 familias y 1 técnico.'),
          findsOneWidget,
        );

        // Sin tipo ni título no se envía.
        await tester.ensureVisible(find.text('Publicar y avisar'));
        await tester.tap(find.text('Publicar y avisar'));
        await tester.pumpAndSettle();
        expect(find.text('Elegí el tipo.'), findsOneWidget);
        expect(find.text('Escribí un título.'), findsOneWidget);
        expect(requests.where((r) => r.path == '/events'), isEmpty);

        await tester.ensureVisible(find.text('Torneo'));
        await tester.tap(find.text('Torneo'));
        await tester.enterText(
          find.widgetWithText(TextField, 'Título'),
          'Apertura Sub-10',
        );
        await tester.pump(const Duration(milliseconds: 500));
        await tester.ensureVisible(find.text('Publicar y avisar'));
        await tester.tap(find.text('Publicar y avisar'));
        await tester.pumpAndSettle();

        final post = requests.lastWhere((r) => r.path == '/events');
        expect(post.data, containsPair('group_ids', [3]));
        expect(post.data, containsPair('starts_on', '2026-10-11'));
        expect(post.data, containsPair('category', 'torneo'));
        expect(find.text('Listo, publicado.'), findsOneWidget);
      },
    );

    testWidgets('día sin clase: "No cobrar", suspende y pide confirmación', (
      tester,
    ) async {
      _phone(tester, size: _tall);
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        _app(
          {
            ..._organization(permissions: ['publish_events']),
            'GET /events/options': (_) => eventOptionsJson(),
            'POST /events/preview': (_) => previewJson(
              suspended: 12,
              skippedStarted: 2,
              canWaiveCharge: true,
            ),
            'POST /events': (_) => {'data': dayOffJson()},
          },
          initial: '/calendario/nuevo?tipo=sin_clase&fecha=2026-10-07',
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nuevo día sin clase'), findsOneWidget);
      expect(find.text('Todo el club'), findsOneWidget);
      // Sin destinatarios no hay vista previa ni casilla de cobro.
      expect(find.text('No cobrar las clases suspendidas'), findsNothing);

      await tester.tap(find.text('Feriado'));
      await tester.pump();
      // Sugiere el título.
      expect(find.widgetWithText(TextField, 'Feriado'), findsOneWidget);

      await tester.ensureVisible(find.text('Fútbol'));
      await tester.tap(find.text('Fútbol'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.text('Se suspenden 12 clases. 2 ya empezaron y no se tocan.'),
        findsOneWidget,
      );
      expect(find.text('No cobrar las clases suspendidas'), findsOneWidget);

      await tester.ensureVisible(find.text('Publicar y avisar'));
      await tester.tap(find.text('Publicar y avisar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Publicamos el día sin clase?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Publicar y avisar').last,
      );
      await tester.pumpAndSettle();

      final post = requests.lastWhere((r) => r.path == '/events');
      expect(post.data, containsPair('kind', 'sin_clase'));
      expect(post.data, containsPair('title', 'Feriado'));
      expect(post.data, containsPair('group_ids', [3, 4]));
      expect(post.data, containsPair('waive_charge', true));
    });
  });

  group('evento', () {
    testWidgets('detalle y cancelar un día sin clase', (tester) async {
      _phone(tester);
      final requests = <RequestOptions>[];
      var cancelled = false;
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /events/9': (_) => {
              'data': dayOffJson(
                cancelled: cancelled,
                affectedClasses: [
                  {
                    'id': 82,
                    'date': '2026-10-07',
                    'starts_at': '17:00',
                    'ends_at': '18:30',
                    'group': {'id': 3, 'name': 'Sub-10'},
                  },
                ],
              ),
            },
            'POST /events/9/cancel': (_) {
              cancelled = true;
              return {'data': dayOffJson(cancelled: true)};
            },
          },
          initial: '/eventos/9',
          requests: requests,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Día del Docente'), findsOneWidget);
      expect(find.text('Para: Sub-10'), findsOneWidget);
      expect(find.text('Clases suspendidas'), findsOneWidget);
      expect(find.text('Las clases suspendidas no se cobran.'), findsOneWidget);
      expect(
        find.text('Publicado por Ana Benítez el 2 de octubre'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Más opciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar día sin clase'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Las 1 clases que se suspendieron'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'Se trabaja');
      await tester.tap(find.text('Cancelar y avisar'));
      await tester.pumpAndSettle();

      expect(requests.lastWhere((r) => r.path == '/events/9/cancel').data, {
        'reason': 'Se trabaja',
      });
      expect(find.text('Se canceló.'), findsOneWidget);
      expect(find.byTooltip('Más opciones'), findsNothing);
    });

    testWidgets('sin permiso no hay menú', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /events/7': (_) => {
            'data': eventJson(canEdit: false, canCancel: false),
          },
        }, initial: '/eventos/7'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apertura Sub-10'), findsOneWidget);
      expect(find.text('Dom 11/10 · 08:00 a 18:00'), findsOneWidget);
      expect(find.byTooltip('Más opciones'), findsNothing);
    });
  });

  testWidgets('el inicio muestra los próximos eventos', (tester) async {
    _phone(tester);
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      _app(
        {
          ..._organization(),
          'GET /calendar': (_) => calendarJson(
            events: [
              eventJson(),
              dayOffJson(),
              eventJson(id: 3, title: 'Viejo', startsOn: '2026-10-01'),
            ],
          ),
        },
        initial: '/inicio',
        requests: requests,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      requests.singleWhere((r) => r.path == '/calendar').queryParameters,
      containsPair('types', 'events'),
    );
    expect(find.text('Próximamente'), findsOneWidget);
    expect(find.text('Sin clases: Día del Docente'), findsOneWidget);
    expect(find.text('Apertura Sub-10'), findsOneWidget);
    expect(find.text('Viejo'), findsNothing);
  });

  group('sincronizar con Google o Apple', () {
    Map<String, Object?> feedJson(String token) => {
      'data': {
        'url': 'https://api.test/calendario/$token.ics',
        'webcal_url': 'webcal://api.test/calendario/$token.ics',
        'google_url':
            'https://calendar.google.com/calendar/r?cid=webcal%3A%2F%2Fapi.test%2Fcalendario%2F$token.ics',
      },
    };

    testWidgets('desde el calendario; en Android, Google primero', (
      tester,
    ) async {
      _phone(tester, size: _tall);
      final launched = <Uri>[];
      await tester.pumpWidget(
        _app({
          ..._organization(),
          ..._students([]),
          'GET /calendar': (_) => calendarJson(),
          'GET /me/calendar-feed': (_) => feedJson('abc'),
        }, launched: launched),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byTooltip('Sincronizar con Google Calendar o iPhone'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Tus actividades en el calendario de tu celular'),
        findsOneWidget,
      );
      final google = tester.getTopLeft(find.text('Google Calendar')).dy;
      final apple = tester
          .getTopLeft(find.text('Calendario de iPhone o Mac'))
          .dy;
      expect(google, lessThan(apple));

      await tester.tap(find.text('Google Calendar'));
      await tester.pumpAndSettle();
      expect(launched.single.host, 'calendar.google.com');
      expect(launched.single.queryParameters['cid'], startsWith('webcal://'));

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.tap(find.text('Copiar link'));
      await tester.pumpAndSettle();
      expect(copied, 'https://api.test/calendario/abc.ics');
      expect(find.text('Link copiado.'), findsOneWidget);
    });

    testWidgets('en iPhone, el Calendario de Apple primero (webcal)', (
      tester,
    ) async {
      _phone(tester, size: _tall);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final launched = <Uri>[];
      await tester.pumpWidget(
        _app(
          {..._organization(), 'GET /me/calendar-feed': (_) => feedJson('abc')},
          initial: '/calendario/sincronizar',
          launched: launched,
        ),
      );
      await tester.pumpAndSettle();

      final google = tester.getTopLeft(find.text('Google Calendar')).dy;
      final apple = tester
          .getTopLeft(find.text('Calendario de iPhone o Mac'))
          .dy;
      expect(apple, lessThan(google));
      await tester.tap(find.text('Calendario de iPhone o Mac'));
      await tester.pumpAndSettle();
      expect(
        launched.single.toString(),
        'webcal://api.test/calendario/abc.ics',
      );
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('generar un link nuevo pide confirmación y anula el anterior', (
      tester,
    ) async {
      _phone(tester, size: _tall);
      final requests = <RequestOptions>[];
      final launched = <Uri>[];
      var token = 'abc';
      await tester.pumpWidget(
        _app(
          {
            ..._organization(),
            'GET /me/calendar-feed': (_) => feedJson(token),
            'POST /me/calendar-feed/reset': (_) {
              token = 'nuevo';
              return feedJson(token);
            },
          },
          initial: '/calendario/sincronizar',
          requests: requests,
          launched: launched,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Generar un link nuevo'));
      await tester.tap(find.text('Generar un link nuevo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.tap(find.text('Generar un link nuevo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar link nuevo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Listo: link nuevo. Volvé a agregarlo a tu calendario.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Calendario de iPhone o Mac'));
      await tester.pumpAndSettle();
      expect(launched.single.toString(), contains('nuevo.ics'));
    });

    testWidgets('error con reintentar', (tester) async {
      _phone(tester, size: _tall);
      var fail = true;
      await tester.pumpWidget(
        _app({
          ..._organization(),
          'GET /me/calendar-feed': (options) {
            if (fail) throw apiError(options, 500, {'message': 'Falló.'});
            return feedJson('abc');
          },
        }, initial: '/calendario/sincronizar'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Falló.'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Copiar link'), findsOneWidget);
    });
  });
}
