import 'package:academia_app/app.dart';
import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/core/utils/launcher.dart';
import 'package:academia_app/features/onboarding/data/step_controllers.dart';
import 'package:academia_app/router.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'onboarding_json.dart';

typedef Routes = Map<String, Object? Function(RequestOptions options)>;

/// La app entera (router real) con la API falsa; con [location] entra directo.
Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  Routes routes, {
  String? token = 't',
  String? organization = 'jakare',
  String? location,
  List<RequestOptions>? requests,
  List<Uri>? launched,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    // Sin reintentos: las tarjetas del inicio que no tienen respuesta fallan y listo.
    retry: (_, _) => null,
    overrides: [
      sessionStorageProvider.overrideWithValue(
        InMemorySessionStorage()
          ..token = token
          ..organization = organization,
      ),
      offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
      apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
      pushServiceProvider.overrideWithValue(FakePushService()),
      // El borrador del paso 2 se guarda enseguida (sin temporizador).
      draftSaveDelayProvider.overrideWithValue(Duration.zero),
      todayProvider.overrideWithValue(DateTime(2026, 10, 3)),
      nowProvider.overrideWithValue(DateTime(2026, 10, 3, 10)),
      urlLauncherProvider.overrideWithValue((uri) async {
        launched?.add(uri);
        return true;
      }),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await _settle(tester);
  if (location != null) {
    container.read(routerProvider).go(location);
    await _settle(tester);
  }
  return container;
}

/// Avanza el reloj hasta que terminan las peticiones encadenadas.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

Routes _admin({
  Map<String, Object?> Function()? onboarding,
  List<String> permissions = const ['configure_organization'],
}) => {
  'GET /me': (_) => meJson(),
  'GET /organization': (_) => organizationJson(permissions: permissions),
  'GET /onboarding': (_) => (onboarding ?? onboardingJson)(),
  'GET /onboarding/templates': (_) => templatesJson,
};

void main() {
  testWidgets('olvidé mi contraseña: código por WhatsApp y entra', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(),
        'POST /auth/password/forgot': (_) => null,
        'POST /auth/password/reset': (options) {
          if ((options.data as Map)['code'] != '123456') {
            throw apiError(options, 422, {
              'message': 'El código no es correcto.',
              'errors': {
                'code': ['El código no es correcto.'],
              },
            });
          }
          return {'token': 'nuevo'};
        },
      },
      token: null,
      requests: requests,
    );

    await tester.enterText(find.byKey(const Key('login')), '0981 123 456');
    await tester.tap(find.byKey(const Key('forgot-password')));
    await _settle(tester);

    expect(find.text('Recuperar la contraseña'), findsOneWidget);
    // Trae lo que ya había escrito.
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, '0981 123 456');
    await tester.tap(find.byKey(const Key('submit')));
    await _settle(tester);

    expect(requests.firstWhere((r) => r.path == '/auth/password/forgot').data, {
      'login': '0981 123 456',
    });
    expect(find.textContaining('por WhatsApp'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '111111');
    await tester.enterText(find.byKey(const Key('password')), 'nueva1234');
    await tester.enterText(find.byKey(const Key('confirmation')), 'nueva1234');
    await tester.tap(find.byKey(const Key('submit')));
    await _settle(tester);
    expect(find.text('El código no es correcto.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('code')), '123456');
    await tester.tap(find.byKey(const Key('submit')));
    await _settle(tester);

    expect(find.text('Recuperar la contraseña'), findsNothing);
    expect(requests.where((r) => r.path == '/auth/password/reset').last.data, {
      'login': '0981 123 456',
      'code': '123456',
      'password': 'nueva1234',
      'password_confirmation': 'nueva1234',
      'device_name': 'app',
    });
  });

  testWidgets('crear cuenta, código y club llevan a la guía', (tester) async {
    var verified = false;
    var organizations = <Map<String, Object?>>[];
    final requests = <RequestOptions>[];

    await _pumpApp(
      tester,
      {
        'POST /auth/register': (_) => {'token': 'nuevo'},
        'GET /me': (_) => meJson(
          verified: verified,
          phone: '+595981123456',
          email: null,
          organizations: organizations,
        ),
        'POST /auth/verify': (options) {
          if ((options.data as Map)['code'] != '123456') {
            throw apiError(options, 422, {
              'message': 'El código no es correcto.',
              'errors': {
                'code': ['El código no es correcto.'],
              },
            });
          }
          verified = true;
          return null;
        },
        'GET /onboarding/templates': (_) => templatesJson,
        'GET /organizations/slug': (_) => {
          'slug': 'academia-ritmo',
          'available': true,
          'suggestion': null,
        },
        'POST /organizations': (_) {
          organizations = [
            {'slug': 'academia-ritmo', 'name': 'Academia Ritmo'},
          ];
          return {
            'data': {
              'slug': 'academia-ritmo',
              'name': 'Academia Ritmo',
              'type': 'academy',
            },
          };
        },
        'GET /organization': (_) => organizationJson(type: 'academy'),
        'GET /onboarding': (_) => onboardingJson(),
      },
      token: null,
      organization: null,
      requests: requests,
    );

    expect(find.text('Iniciar sesión'), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-account')));
    await _settle(tester);

    // Separa al club de la familia.
    await tester.tap(find.byKey(const Key('choice-club')));
    await _settle(tester);

    await tester.enterText(find.byKey(const Key('name')), 'Laura Gómez');
    // Por defecto, con el celular (código por WhatsApp); el correo es la
    // alternativa.
    await tester.tap(find.byKey(const Key('switch-channel')));
    await tester.pump();
    expect(find.byKey(const Key('email')), findsOneWidget);
    await tester.tap(find.byKey(const Key('switch-channel')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('phone')), '0981 123 456');
    await tester.enterText(find.byKey(const Key('password')), 'secreta123');
    await tester.enterText(find.byKey(const Key('confirmation')), 'secreta123');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await _settle(tester);
    // Sin aceptar los términos no se crea.
    expect(find.text('Tenés que aceptar los términos.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('terms')));
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await _settle(tester);

    final register = requests.firstWhere((r) => r.path == '/auth/register');
    expect((register.data as Map)['phone'], '0981 123 456');
    expect((register.data as Map).containsKey('email'), isFalse);
    expect(find.text('Confirmá tu número'), findsOneWidget);
    expect(find.text('0981 123 456'), findsOneWidget);
    // Sin correo no se ofrece mandarlo por correo.
    expect(find.byKey(const Key('resend-email')), findsNothing);

    await tester.enterText(find.byKey(const Key('code')), '111111');
    await _settle(tester);
    expect(find.text('El código no es correcto.'), findsOneWidget);

    // Con los 6 dígitos se envía solo.
    await tester.enterText(find.byKey(const Key('code')), '123456');
    await _settle(tester);

    expect(find.text('Contanos de tu club'), findsOneWidget);
    expect(find.text('Jugadores, técnicos y categorías'), findsOneWidget);

    await tester.tap(find.text('Academia'));
    await _settle(tester);
    // El vocabulario sigue al tipo.
    expect(find.text('Alumnos, profesores y grupos'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('club-name')),
      'Academia Ritmo',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('create-club')));
    await _settle(tester);

    expect(find.text('Configurá tu academia'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
    final created = requests.firstWhere(
      (r) => r.method == 'POST' && r.path == '/organizations',
    );
    expect(created.data, {
      'name': 'Academia Ritmo',
      'type': 'academy',
      'slug': 'academia-ritmo',
      'terminology': {
        'program': 'Disciplina',
        'group': 'Grupo',
        'student': 'Alumno',
        'instructor': 'Profesor',
        'guardian': 'Tutor',
        'space': 'Sala',
      },
    });
  });

  testWidgets(
    'con el celular, el correo es opcional y recibe una copia del código',
    (tester) async {
      final requests = <RequestOptions>[];

      await _pumpApp(
        tester,
        {
          'POST /auth/register': (_) => {'token': 'nuevo'},
          'GET /me': (_) => meJson(
            verified: false,
            phone: '+595981123456',
            email: 'laura@test.com',
            organizations: const [],
          ),
        },
        token: null,
        organization: null,
        requests: requests,
      );

      await tester.tap(find.byKey(const Key('create-account')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('choice-club')));
      await _settle(tester);

      expect(find.text('Correo (opcional)'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('name')), 'Laura Gómez');
      await tester.enterText(find.byKey(const Key('phone')), '0981 123 456');
      await tester.enterText(find.byKey(const Key('optional-email')), 'laura');
      await tester.enterText(find.byKey(const Key('password')), 'secreta123');
      await tester.enterText(
        find.byKey(const Key('confirmation')),
        'secreta123',
      );
      await tester.tap(find.byKey(const Key('terms')));
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await _settle(tester);
      // Si lo escribe, tiene que ser válido.
      expect(find.text('El correo electrónico no es válido.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('optional-email')),
        'laura@test.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await _settle(tester);

      final register = requests.firstWhere((r) => r.path == '/auth/register');
      expect((register.data as Map)['phone'], '0981 123 456');
      expect((register.data as Map)['email'], 'laura@test.com');
      expect(find.text('Confirmá tu número'), findsOneWidget);
      expect(
        find.text('Y otro a laura@test.com: podés usar cualquiera de los dos.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('sin organizaciones se ofrece registrar el club', (tester) async {
    await _pumpApp(tester, {
      'GET /me': (_) => meJson(organizations: const []),
      'GET /onboarding/templates': (_) => templatesJson,
    }, organization: null);

    // Verificado y sin club: va directo a "Tu club" desde el registro, pero
    // si entra con su contraseña ve la lista vacía con el botón.
    expect(find.text('Registrar mi club'), findsOneWidget);
    await tester.tap(find.text('Registrar mi club'));
    await _settle(tester);
    expect(find.text('Contanos de tu club'), findsOneWidget);
  });

  group('guía en el inicio', () {
    testWidgets('está en el inicio con los pasos; no abre otra pantalla', (
      tester,
    ) async {
      await _pumpApp(tester, _admin());

      expect(find.text('Hola, Laura.'), findsOneWidget);
      expect(find.byKey(const Key('setup-guide')), findsOneWidget);
      expect(find.text('Configurá tu club'), findsOneWidget);
      expect(find.text('0 de 4'), findsOneWidget);
      // Bloqueado: dice qué falta antes.
      expect(find.text('Primero: ¿Qué enseñan?'), findsNWidgets(2));
      expect(find.text('Primero: Categorías y horarios'), findsOneWidget);
      expect(find.text('Empezar'), findsOneWidget);
    });

    testWidgets('"Seguir después" la achica y "Seguir" la vuelve a abrir', (
      tester,
    ) async {
      var dismissed = false;
      final requests = <RequestOptions>[];
      await _pumpApp(tester, {
        ..._admin(onboarding: () => onboardingJson(dismissed: dismissed)),
        'PUT /onboarding': (options) {
          dismissed = (options.data as Map)['dismissed'] as bool;
          return onboardingJson(dismissed: dismissed);
        },
      }, requests: requests);

      await tester.ensureVisible(find.text('Seguir después'));
      await tester.tap(find.text('Seguir después'));
      await _settle(tester);

      expect(requests.last.data, {'dismissed': true});
      expect(find.byKey(const Key('setup-compact')), findsOneWidget);
      expect(find.text('Sigue: ¿Qué enseñan?'), findsOneWidget);
      expect(find.text('Primero: Categorías y horarios'), findsNothing);
      expect(find.text('La retomás desde acá cuando quieras.'), findsOneWidget);

      await tester.tap(find.text('Seguir'));
      await _settle(tester);

      expect(requests.last.data, {'dismissed': false});
      expect(find.byKey(const Key('setup-guide')), findsOneWidget);
    });

    testWidgets('completa desaparece', (tester) async {
      await _pumpApp(
        tester,
        _admin(
          onboarding: () => onboardingJson(
            programs: 'done',
            groups: 'done',
            season: 'done',
            instructors: 'skipped',
          ),
        ),
      );

      expect(find.text('Hola, Laura.'), findsOneWidget);
      expect(find.text('Configurá tu club'), findsNothing);
    });

    testWidgets('sin permiso no hay guía', (tester) async {
      await _pumpApp(tester, _admin(permissions: const []));

      expect(find.text('Hola, Laura.'), findsOneWidget);
      expect(find.text('Configurá tu club'), findsNothing);
    });

    testWidgets('un paso bloqueado lleva al que falta', (tester) async {
      await _pumpApp(tester, {
        ..._admin(),
        'GET /setup/programs': (_) => {'data': <Object?>[]},
      });

      await tester.tap(find.text('Temporada y cuotas'));
      await _settle(tester);

      expect(find.text('¿Qué enseñan?'), findsOneWidget);
      expect(find.text('Paso 1 de 4'), findsOneWidget);
    });
  });

  testWidgets('disciplinas: elegir, ajustar el criterio y seguir', (
    tester,
  ) async {
    var programs = <Map<String, Object?>>[];
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => programs.isEmpty
              ? onboardingJson()
              : onboardingJson(programs: 'done', groups: 'pending'),
        ),
        'GET /setup/programs': (_) => {'data': programs},
        'POST /setup/programs': (options) {
          programs = [
            programJson(1, 'Fútbol'),
            programJson(2, 'Danza', criterion: 'level'),
          ];
          return {'data': programs};
        },
        'GET /setup/groups': (_) => {'data': <Object?>[]},
        'GET /setup/sites': (_) => {'data': <Object?>[]},
        'POST /setup/groups/suggestions': (_) => {
          'data': [
            {'name': 'Sub-6', 'min_age': 5, 'max_age': 6, 'level': null},
          ],
        },
      },
      location: '/configurar/disciplinas',
      requests: requests,
    );

    expect(find.text('¿Qué enseñan?'), findsOneWidget);
    await tester.tap(find.text('Fútbol'));
    await tester.tap(find.text('Danza'));
    await _settle(tester);

    expect(find.text('¿Cómo se arman las categorías?'), findsOneWidget);
    // Fútbol sugerido por edad; se cambia a nivel.
    await tester.tap(find.text('Por nivel').first);
    await _settle(tester);

    await tester.tap(find.byKey(const Key('step-primary')));
    await _settle(tester);

    final body = requests
        .firstWhere((r) => r.method == 'POST' && r.path == '/setup/programs')
        .data;
    expect(body, {
      'programs': [
        {'name': 'Fútbol', 'group_criterion': 'level'},
        {'name': 'Danza', 'group_criterion': 'level'},
      ],
    });
    // Sigue al próximo paso pendiente.
    expect(find.text('¿Qué categorías tienen?'), findsOneWidget);
    expect(find.text('Paso 2 de 4'), findsOneWidget);
  });

  testWidgets('categorías: sugeridas, horario de todas y crear', (
    tester,
  ) async {
    var created = false;
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => created
              ? onboardingJson(
                  programs: 'done',
                  groups: 'done',
                  season: 'pending',
                  instructors: 'pending',
                )
              : onboardingJson(programs: 'done', groups: 'pending'),
        ),
        'GET /setup/programs': (_) => {
          'data': [programJson(1, 'Fútbol')],
        },
        'GET /setup/groups': (_) => {'data': <Object?>[]},
        // Un lugar con dos canchas.
        'GET /setup/sites': (_) => {
          'data': [
            {
              'id': 1,
              'name': 'Polideportivo',
              'address': 'Av. España 123',
              'spaces': [
                {
                  'id': 11,
                  'name': 'Cancha 1',
                  'label': 'Polideportivo · Cancha 1',
                },
                {
                  'id': 12,
                  'name': 'Cancha 2',
                  'label': 'Polideportivo · Cancha 2',
                },
              ],
            },
          ],
        },
        // El sábado de Sub-10 choca con una categoría que ya existe.
        'POST /setup/schedules/conflicts': (options) {
          final schedules = (options.data as Map)['schedules'] as List;
          final saturday = schedules.any(
            (s) => (s as Map)['key'] == '1-1' && s['venue_id'] == 11,
          );
          return {
            'data': {
              if (saturday)
                '1-1': [
                  'Choca con Sub-14 el sábado de 17:00 a 18:30 en Polideportivo · Cancha 1.',
                ],
            },
          };
        },
        'POST /setup/groups/suggestions': (_) => {
          'data': [
            {'name': 'Sub-8', 'min_age': 7, 'max_age': 8, 'level': null},
            {'name': 'Sub-10', 'min_age': 9, 'max_age': 10, 'level': null},
            {'name': 'Sub-12', 'min_age': 11, 'max_age': 12, 'level': null},
          ],
        },
        'POST /setup/groups': (_) {
          created = true;
          return {
            'data': [groupJson(3, 'Sub-8'), groupJson(4, 'Sub-10')],
          };
        },
        'GET /setup/seasons/new': (_) => seasonDraftJson(),
        'GET /setup/seasons': (_) => {'data': <Object?>[]},
        'POST /setup/seasons/preview': (_) => seasonPreviewJson(),
      },
      location: '/configurar/categorias',
      requests: requests,
    );

    // Pantalla 1: solo la lista.
    expect(find.text('¿Qué categorías tienen?'), findsOneWidget);
    expect(find.text('Sub-8'), findsOneWidget);
    expect(find.text('7 y 8 años'), findsOneWidget);
    expect(find.text('Lun'), findsNothing);
    await tester.tap(find.byTooltip('Quitar Sub-12'));
    await _settle(tester);
    await tester.tap(find.text('Siguiente: horarios'));
    await _settle(tester);

    // Pantalla 2: el horario de cada una.
    expect(find.text('¿Cuándo entrena cada categoría?'), findsOneWidget);
    expect(find.text('Falta el horario'), findsNWidgets(2));
    expect(find.text('Crear 2 categorías (2 sin horario)'), findsOneWidget);

    // Sub-8: martes y jueves, y "Copiar a todas".
    final sub8 = find.byKey(const ValueKey('schedule-0'));
    await tester.tap(find.descendant(of: sub8, matching: find.text('Mar')));
    await tester.pump();
    await tester.tap(find.descendant(of: sub8, matching: find.text('Jue')));
    await _settle(tester);
    // La cancha de ese horario.
    expect(find.text('Polideportivo'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-0-0-null')));
    await _settle(tester);
    await tester.tap(find.text('Polideportivo · Cancha 1').last);
    await _settle(tester);
    expect(find.text('Crear 2 categorías (1 sin horario)'), findsOneWidget);
    await tester.tap(find.text('Copiar a todas'));
    await _settle(tester);
    expect(find.text('Falta el horario'), findsNothing);

    // Sub-10: además, el sábado a otra hora.
    final sub10 = find.byKey(const ValueKey('schedule-1'));
    // (Se corre un poco: la barra de abajo tapa el final de la lista.)
    Future<void> tapVisible(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.drag(find.byType(ListView).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await _settle(tester);
    }

    await tapVisible(
      find.descendant(of: sub10, matching: find.text('Otro horario')),
    );
    await tapVisible(
      find.descendant(
        of: find.byKey(const ValueKey('slot-1-1')),
        matching: find.text('Sáb'),
      ),
    );

    // Aviso de choque debajo del horario (se puede guardar igual).
    expect(
      find.text(
        'Choca con Sub-14 el sábado de 17:00 a 18:30 en Polideportivo · Cancha 1.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Crear 2 categorías'));
    await _settle(tester);

    final body =
        requests
                .firstWhere(
                  (r) => r.method == 'POST' && r.path == '/setup/groups',
                )
                .data
            as Map<String, Object?>;
    expect((body['groups']! as List).map((g) => (g as Map)['name']), [
      'Sub-8',
      'Sub-10',
    ]);
    expect(((body['groups']! as List).first as Map)['schedules'], [
      {'weekday': 2, 'starts_at': '17:00', 'ends_at': '18:30', 'venue_id': 11},
      {'weekday': 4, 'starts_at': '17:00', 'ends_at': '18:30', 'venue_id': 11},
    ]);
    expect(((body['groups']! as List).last as Map)['schedules'], [
      {'weekday': 2, 'starts_at': '17:00', 'ends_at': '18:30', 'venue_id': 11},
      {'weekday': 4, 'starts_at': '17:00', 'ends_at': '18:30', 'venue_id': 11},
      {'weekday': 6, 'starts_at': '17:00', 'ends_at': '18:30', 'venue_id': 11},
    ]);
    expect(find.text('¿Cuándo es la temporada?'), findsOneWidget);
  });

  testWidgets('categorías: lo armado se guarda solo y se retoma', (
    tester,
  ) async {
    Map<String, Object?>? stored;
    final requests = <RequestOptions>[];
    final container = await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => onboardingJson(programs: 'done', groups: 'pending'),
        ),
        'GET /setup/programs': (_) => {
          'data': [programJson(1, 'Fútbol')],
        },
        'GET /setup/groups': (_) => {'data': <Object?>[]},
        'GET /setup/sites': (_) => {'data': <Object?>[]},
        'POST /setup/groups/suggestions': (_) => {
          'data': [
            {'name': 'Sub-8', 'min_age': 7, 'max_age': 8, 'level': null},
            {'name': 'Sub-10', 'min_age': 9, 'max_age': 10, 'level': null},
            {'name': 'Sub-12', 'min_age': 11, 'max_age': 12, 'level': null},
          ],
        },
        'GET /onboarding/steps/groups/draft': (_) => {
          'data': {'draft': stored, 'updated_at': null},
        },
        'PUT /onboarding/steps/groups/draft': (options) {
          stored = Map<String, Object?>.from(
            (options.data as Map)['draft'] as Map,
          );
          return {
            'data': {'draft': stored},
          };
        },
        'DELETE /onboarding/steps/groups/draft': (_) {
          stored = null;
          return null;
        },
      },
      location: '/configurar/categorias',
      requests: requests,
    );

    // Lo sugerido no es un cambio: todavía no hay borrador.
    expect(stored, isNull);
    await tester.tap(find.byTooltip('Quitar Sub-12'));
    await _settle(tester);
    expect((stored!['groups']! as List).map((g) => (g as Map)['name']), [
      'Sub-8',
      'Sub-10',
    ]);
    expect(stored!['program_id'], 1);

    await tester.tap(find.text('Siguiente: horarios'));
    await _settle(tester);
    final sub8 = find.byKey(const ValueKey('schedule-0'));
    await tester.tap(find.descendant(of: sub8, matching: find.text('Mar')));
    await _settle(tester);
    final slots = ((stored!['groups']! as List).first as Map)['slots'] as List;
    expect((slots.first as Map)['weekdays'], [2]);

    // Sale sin crear y vuelve (o lo abre en otro dispositivo): sigue ahí.
    container.read(routerProvider).go('/inicio');
    await _settle(tester);
    container.read(routerProvider).go('/configurar/categorias');
    await _settle(tester);

    expect(find.text('Sub-8'), findsOneWidget);
    expect(find.text('Sub-12'), findsNothing);
    expect(
      requests.where((r) => r.path == '/setup/groups/suggestions'),
      hasLength(1),
    );
    await tester.tap(find.text('Siguiente: horarios'));
    await _settle(tester);
    expect(find.text('Falta el horario'), findsOneWidget);
  });

  testWidgets('"Yo también doy clases" arranca sin ninguna y pide elegir', (
    tester,
  ) async {
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => onboardingJson(
            programs: 'done',
            groups: 'done',
            season: 'done',
            instructors: 'pending',
          ),
        ),
        'GET /setup/groups': (_) => {
          'data': [groupJson(3, 'Sub-8'), groupJson(4, 'Sub-10')],
        },
        'GET /setup/instructors': (_) => instructorsJson(),
        'PUT /setup/instructors/me': (_) => instructorsJson(teaches: true),
      },
      location: '/configurar/tecnicos',
      requests: requests,
    );

    await tester.tap(find.byKey(const Key('i-teach')));
    await _settle(tester);

    // Todavía no se guardó nada: hay que elegir.
    expect(requests.where((r) => r.path == '/setup/instructors/me'), isEmpty);
    expect(
      find.text('¿Cuáles das vos? Elegí al menos una categoría.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Sub-8'))
          .selected,
      isFalse,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Sub-8'));
    await _settle(tester);
    expect(requests.firstWhere((r) => r.path == '/setup/instructors/me').data, {
      'teaches': true,
      'group_ids': [3],
    });
    expect(find.text('¿Cuáles das vos?'), findsOneWidget);
  });

  testWidgets('temporada: duración, monto y revisar antes de crear', (
    tester,
  ) async {
    var created = false;
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => created
              ? onboardingJson(
                  programs: 'done',
                  groups: 'done',
                  season: 'done',
                  instructors: 'skipped',
                )
              : onboardingJson(
                  programs: 'done',
                  groups: 'done',
                  season: 'pending',
                  instructors: 'skipped',
                ),
        ),
        'GET /setup/programs': (_) => {
          'data': [programJson(1, 'Fútbol', groups: 2)],
        },
        'GET /setup/groups': (_) => {
          'data': [groupJson(3, 'Sub-8')],
        },
        'GET /setup/seasons': (_) => {'data': <Object?>[]},
        'GET /setup/seasons/new': (_) => seasonDraftJson(),
        'POST /setup/seasons/preview': (options) =>
            (options.data as Map)['kind'] == 'semestral'
            ? seasonPreviewJson(
                endsOn: '2027-06-30',
                name: '1.er semestre 2027',
              )
            : seasonPreviewJson(),
        'POST /setup/seasons': (_) {
          created = true;
          return {
            'data': {
              'id': 4,
              'name': '1.er semestre 2027',
              'status': 'proxima',
              'has_fee_plan': true,
            },
          };
        },
      },
      location: '/configurar/temporada',
      requests: requests,
    );

    expect(find.text('Empieza 01/01/2027'), findsOneWidget);
    expect(find.text('Termina 31/12/2027'), findsOneWidget);

    // Al cambiar la duración, el fin y el nombre se recalculan.
    await tester.tap(find.text('Semestral'));
    await _settle(tester);
    expect(find.text('Termina 30/06/2027'), findsOneWidget);
    expect(find.text('1.er semestre 2027'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await _settle(tester);
    expect(find.text('¿Cuánto se cobra?'), findsOneWidget);

    // Sin monto no sigue.
    await tester.tap(find.text('Siguiente'));
    await _settle(tester);
    expect(find.text('Ingresá el monto de la cuota.'), findsOneWidget);

    // Con la palabra de lo que eligió, no "período".
    expect(find.text('¿Qué día del mes vence?'), findsOneWidget);
    expect(find.text('Día 10'), findsOneWidget);
    expect(find.text('Al empezar cada mes (recomendado)'), findsOneWidget);
    expect(
      find.text('La familia ve solo la cuota del mes en curso.'),
      findsOneWidget,
    );
    expect(find.textContaining('período'), findsNothing);

    await tester.enterText(find.byKey(const Key('fee-amount')), '150000');
    await tester.tap(find.text('Siguiente'));
    await _settle(tester);

    expect(find.text('Revisá'), findsOneWidget);
    expect(find.byKey(const Key('season-summary')), findsOneWidget);
    expect(find.text('Enero 2027'), findsOneWidget);

    await tester.tap(find.text('Crear temporada'));
    await _settle(tester);

    final body =
        requests
                .firstWhere(
                  (r) => r.method == 'POST' && r.path == '/setup/seasons',
                )
                .data
            as Map<String, Object?>;
    expect(body['kind'], 'semestral');
    expect(body['ends_on'], '2027-06-30');
    expect(body['name'], '1.er semestre 2027');
    expect(body['fee_amount'], 150000);
    // Con este paso se completó: "¡Listo!".
    expect(find.text('¡Todo listo!'), findsOneWidget);
  });

  testWidgets('técnicos: invitar y compartir por WhatsApp', (tester) async {
    var instructors = <Map<String, Object?>>[];
    final launched = <Uri>[];
    final requests = <RequestOptions>[];
    await _pumpApp(
      tester,
      {
        ..._admin(
          onboarding: () => onboardingJson(
            programs: 'done',
            groups: 'done',
            season: 'done',
            instructors: instructors.isEmpty ? 'pending' : 'done',
          ),
        ),
        'GET /setup/groups': (_) => {
          'data': [groupJson(3, 'Sub-8'), groupJson(4, 'Sub-10')],
        },
        'GET /setup/instructors': (_) =>
            instructorsJson(instructors: instructors),
        'POST /setup/instructors': (options) {
          final invited = {
            'user_id': null,
            'invitation_id': 12,
            'name': 'Marta Ríos',
            'email': null,
            'phone': '+595981555444',
            'gender': (options.data as Map)['gender'],
            'status': 'invitado',
            'groups': [
              {'id': 4, 'name': 'Sub-10'},
            ],
          };
          instructors = [invited];
          return {
            'data': {...invited, 'link': 'https://app.test/invitacion/abc'},
          };
        },
      },
      location: '/configurar/tecnicos',
      requests: requests,
      launched: launched,
    );

    expect(find.text('¿Quién da las clases?'), findsOneWidget);
    expect(find.text('Lo hago después'), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-instructor')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('invite-name')), 'Marta Ríos');
    await tester.enterText(
      find.byKey(const Key('invite-contact')),
      '0981 555 444',
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Sub-10').last);
    // Opcional: para nombrarla bien en la invitación ("como técnica").
    await tester.tap(find.byKey(const Key('gender-female')));
    await tester.tap(find.byKey(const Key('invite-send')));
    await _settle(tester);

    expect(
      requests
          .firstWhere(
            (r) => r.path == '/setup/instructors' && r.method == 'POST',
          )
          .data,
      {
        'name': 'Marta Ríos',
        'phone': '0981 555 444',
        'group_ids': [4],
        'gender': 'female',
      },
    );
    expect(find.text('Invitación lista'), findsOneWidget);
    expect(find.textContaining('0981 555 444'), findsOneWidget);
    await tester.tap(find.text('WhatsApp'));
    await _settle(tester);
    expect(launched.single.host, 'wa.me');
    // Directo al WhatsApp del técnico.
    expect(launched.single.path, '/595981555444');
    expect(
      launched.single.queryParameters['text'],
      contains('https://app.test/invitacion/abc'),
    );
    expect(
      launched.single.queryParameters['text'],
      contains('te invito a sumarte como técnica de'),
    );

    await tester.tap(find.text('Listo'));
    await _settle(tester);
    expect(find.text('Invitado · Sub-10'), findsOneWidget);
    // Ya hay alguien: no se ofrece omitir.
    expect(find.text('Lo hago después'), findsNothing);

    // La guía se completó al invitar (antes de tocar "Seguir"): igual muestra "¡Listo!".
    await tester.tap(find.text('Listo, seguir'));
    await _settle(tester);
    expect(find.text('¡Todo listo!'), findsOneWidget);
  });

  testWidgets('temporada por día agrupado por día: sin "a mitad de…"', (
    tester,
  ) async {
    await _pumpApp(tester, {
      ..._admin(
        onboarding: () => onboardingJson(
          programs: 'done',
          groups: 'done',
          season: 'pending',
          instructors: 'skipped',
        ),
      ),
      'GET /setup/programs': (_) => {
        'data': [programJson(1, 'Pádel', criterion: 'level', groups: 1)],
      },
      'GET /setup/groups': (_) => {
        'data': [groupJson(3, 'Inicial')],
      },
      'GET /setup/seasons': (_) => {'data': <Object?>[]},
      'GET /setup/seasons/new': (_) => seasonDraftJson(),
      'POST /setup/seasons/preview': (options) {
        final daily = (options.data as Map)['fee_frequency'] == 'diaria';
        final json = seasonPreviewJson();
        (json['data']! as Map)['terms'] = termsJson(daily ? 'dia' : 'mes');
        return json;
      },
    }, location: '/configurar/temporada');

    await tester.tap(find.text('Siguiente'));
    await _settle(tester);
    expect(find.text('Opciones avanzadas'), findsOneWidget);

    await tester.ensureVisible(find.text('Por día'));
    await tester.tap(find.text('Por día'));
    await _settle(tester);
    await tester.ensureVisible(find.text('Una cuota por día'));
    await tester.tap(find.text('Una cuota por día'));
    await _settle(tester);

    expect(
      find.text('El mismo día de cada entrenamiento (recomendado)'),
      findsOneWidget,
    );
    expect(find.text('¿Cuándo vence?'), findsOneWidget);
    expect(find.text('Opciones avanzadas'), findsNothing);
    expect(find.textContaining('mitad de'), findsNothing);
  });

  testWidgets('con "Grupo" y "Profesora" los textos concuerdan', (
    tester,
  ) async {
    await _pumpApp(tester, {
      ..._admin(
        onboarding: () => onboardingJson(programs: 'done', groups: 'pending'),
      ),
      'GET /organization': (_) =>
          organizationJson(group: 'Grupo', instructor: 'Profesora'),
      'GET /setup/programs': (_) => {
        'data': [programJson(1, 'Danza', criterion: 'level')],
      },
      'GET /setup/groups': (_) => {'data': <Object?>[]},
      'GET /setup/sites': (_) => {'data': <Object?>[]},
      'POST /setup/groups/suggestions': (_) => {
        'data': [
          {
            'name': 'Inicial',
            'min_age': null,
            'max_age': null,
            'level': 'Inicial',
          },
          {
            'name': 'Avanzado',
            'min_age': null,
            'max_age': null,
            'level': 'Avanzado',
          },
        ],
      },
      'GET /setup/instructors': (_) => instructorsJson(),
    }, location: '/configurar/categorias');

    expect(
      find.textContaining('Las familias eligen el grupo al inscribirse.'),
      findsOneWidget,
    );
    expect(find.text('Nuevos en Danza'), findsOneWidget);
    expect(find.text('Agregar otro'), findsOneWidget);

    await tester.tap(find.text('Siguiente: horarios'));
    await _settle(tester);
    expect(find.textContaining('el horario de cada uno'), findsOneWidget);
    expect(find.textContaining('«Copiar a todos»'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(routerProvider).go('/configurar/tecnicos');
    await _settle(tester);
    expect(find.text('Invitar a una profesora'), findsOneWidget);
    expect(
      find.text('Todavía no invitaste a ninguna profesora.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Las profesoras toman asistencia'),
      findsOneWidget,
    );
  });

  group('vocabulario de deporte', () {
    Map<String, Object?> academy({bool sport = false}) => sport
        ? organizationJson(type: 'academy', student: 'Alumno')
        : organizationJson(
            type: 'academy',
            group: 'Grupo',
            student: 'Alumno',
            instructor: 'Profesor',
            space: 'Sala',
          );

    Routes academyRoutes({
      required bool Function() saved,
      required void Function() onSave,
    }) {
      var programs = <Map<String, Object?>>[];
      return {
        ..._admin(
          onboarding: () => programs.isEmpty
              ? onboardingJson()
              : onboardingJson(
                  programs: 'done',
                  groups: 'pending',
                  terminologySuggestion: saved() ? null : sportSuggestionJson,
                ),
        ),
        'GET /setup/programs': (_) => {'data': programs},
        'POST /setup/programs': (_) {
          programs = [programJson(1, 'Fútbol')];
          return {'data': programs};
        },
        'PUT /organization/terminology': (_) {
          onSave();
          return {
            'data': {'terminology': <String, String>{}},
          };
        },
        'GET /setup/groups': (_) => {'data': <Object?>[]},
        'GET /setup/sites': (_) => {'data': <Object?>[]},
        'POST /setup/groups/suggestions': (_) => {
          'data': [
            {'name': 'Sub-6', 'min_age': 5, 'max_age': 6, 'level': null},
          ],
        },
      };
    }

    testWidgets('una academia que enseña fútbol elige las palabras', (
      tester,
    ) async {
      var saved = false;
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {
          ...academyRoutes(saved: () => saved, onSave: () => saved = true),
          'GET /organization': (_) => academy(sport: saved),
        },
        location: '/configurar/disciplinas',
        requests: requests,
      );

      await tester.tap(find.text('Fútbol'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('step-primary')));
      await _settle(tester);

      expect(find.byKey(const Key('terminology-suggestion')), findsOneWidget);
      expect(
        find.textContaining(
          'En fútbol se suele decir jugador, técnico, categoría y cancha.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Dejar como estaba (alumno, profesor, grupo y sala)'),
        findsOneWidget,
      );
      // Decide: categoría y cancha, pero siguen siendo profesores.
      await tester.tap(find.byKey(const Key('term-instructor-Profesor')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('terminology-use')));
      await _settle(tester);

      final body = requests
          .firstWhere(
            (r) => r.method == 'PUT' && r.path == '/organization/terminology',
          )
          .data;
      expect(body, {
        'terminology': {
          'student': 'Jugador',
          'group': 'Categoría',
          'instructor': 'Profesor',
          'space': 'Cancha',
        },
      });
      // Sigue al paso 2, ya con las palabras nuevas.
      expect(find.byKey(const Key('terminology-suggestion')), findsNothing);
      expect(find.text('¿Qué categorías tienen?'), findsOneWidget);
    });

    testWidgets('"Dejar como estaba" solo lo confirma', (tester) async {
      var saved = false;
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {
          ...academyRoutes(saved: () => saved, onSave: () => saved = true),
          'GET /organization': (_) => academy(),
        },
        location: '/configurar/disciplinas',
        requests: requests,
      );

      await tester.tap(find.text('Fútbol'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('step-primary')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('terminology-keep')));
      await _settle(tester);

      expect(
        requests.firstWhere((r) => r.path == '/organization/terminology').data,
        {'terminology': <String, String>{}},
      );
      expect(find.text('¿Qué grupos tienen?'), findsOneWidget);
    });

    testWidgets('"Después" sigue y el inicio la recuerda hasta contestar', (
      tester,
    ) async {
      var saved = false;
      final requests = <RequestOptions>[];
      final container = await _pumpApp(
        tester,
        {
          ...academyRoutes(saved: () => saved, onSave: () => saved = true),
          'GET /organization': (_) => academy(sport: saved),
        },
        location: '/configurar/disciplinas',
        requests: requests,
      );

      await tester.tap(find.text('Fútbol'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('step-primary')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('terminology-later')));
      await _settle(tester);

      // No decidió nada: sigue al paso 2 con las palabras de antes.
      expect(
        requests.where((r) => r.path == '/organization/terminology'),
        isEmpty,
      );
      expect(find.text('¿Qué grupos tienen?'), findsOneWidget);

      container.read(routerProvider).go('/inicio');
      await _settle(tester);
      expect(find.text('Configurá tu academia'), findsOneWidget);
      expect(find.text('Elegí cómo les dicen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('setup-terminology')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('terminology-use')));
      await _settle(tester);

      expect(saved, isTrue);
      expect(find.text('Elegí cómo les dicen'), findsNothing);
    });

    testWidgets('con la guía completa queda solo el recordatorio', (
      tester,
    ) async {
      await _pumpApp(tester, {
        ..._admin(
          onboarding: () => onboardingJson(
            programs: 'done',
            groups: 'done',
            season: 'done',
            instructors: 'done',
            terminologySuggestion: sportSuggestionJson,
          ),
        ),
        'GET /organization': (_) => academy(),
      });

      expect(find.byKey(const Key('setup-terminology-only')), findsOneWidget);
      expect(find.byKey(const Key('setup-guide')), findsNothing);
      expect(
        find.text(
          'En fútbol se suele decir jugador, técnico, categoría y cancha.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin propuesta sigue directo', (tester) async {
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {
          ...academyRoutes(saved: () => true, onSave: () {}),
          'GET /organization': (_) => academy(),
        },
        location: '/configurar/disciplinas',
        requests: requests,
      );

      await tester.tap(find.text('Fútbol'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('step-primary')));
      await _settle(tester);

      expect(find.byKey(const Key('terminology-suggestion')), findsNothing);
      expect(find.text('¿Qué grupos tienen?'), findsOneWidget);
      expect(
        requests.where((r) => r.path == '/organization/terminology'),
        isEmpty,
      );
    });

    testWidgets('la guía dice "tu academia" y no "tu club"', (tester) async {
      await _pumpApp(tester, {
        ..._admin(),
        'GET /organization': (_) => academy(),
      });

      expect(find.text('Configurá tu academia'), findsOneWidget);
      expect(find.text('Configurá tu club'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      container.read(routerProvider).go('/cuenta');
      await _settle(tester);
      expect(find.text('Configurar la academia'), findsOneWidget);
    });
  });

  group('cómo les dicen (Mi cuenta)', () {
    testWidgets('cambiar las palabras, también escribiendo otra', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {
          ..._admin(),
          'PUT /organization/terminology': (_) => {
            'data': {'terminology': <String, String>{}},
          },
        },
        location: '/cuenta',
        requests: requests,
      );

      await tester.tap(find.text('Cómo les dicen'));
      await _settle(tester);
      expect(find.text('A quienes enseñan'), findsOneWidget);

      await tester.tap(find.byKey(const Key('term-instructor-Profesor')));
      await tester.tap(find.byKey(const Key('term-space-other')));
      await _settle(tester);
      await tester.enterText(
        find.byKey(const Key('term-other-word')),
        'pileta',
      );
      await tester.tap(find.text('Listo'));
      await _settle(tester);
      expect(find.byKey(const Key('term-space-Pileta')), findsOneWidget);

      await tester.tap(find.byKey(const Key('vocabulary-save')));
      await _settle(tester);

      expect(
        requests.firstWhere((r) => r.path == '/organization/terminology').data,
        {
          'terminology': {
            'student': 'Jugador',
            'instructor': 'Profesor',
            'group': 'Categoría',
            'space': 'Pileta',
          },
        },
      );
      expect(find.text('Listo: las pantallas ya dicen así.'), findsOneWidget);
      expect(find.text('Mi cuenta'), findsOneWidget);
    });

    testWidgets('"Si es mujer": la forma femenina que ajusta la organización', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {
          ..._admin(),
          'PUT /organization/terminology': (_) => {
            'data': {'terminology': <String, String>{}},
          },
        },
        location: '/vocabulario',
        requests: requests,
      );

      // La regla ya la sugiere: "Técnico" → "Técnica".
      expect(find.text('Vacío: "Técnica".'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('feminine-instructor')),
        'Entrenadora',
      );
      await tester.tap(find.byKey(const Key('vocabulary-save')));
      await _settle(tester);

      expect(
        requests.firstWhere((r) => r.path == '/organization/terminology').data,
        {
          'terminology': {
            'student': 'Jugador',
            'instructor': 'Técnico',
            'group': 'Categoría',
            'space': 'Cancha',
          },
          'feminine': {'student': '', 'instructor': 'Entrenadora'},
        },
      );
    });

    testWidgets('Mi cuenta: el género (opcional) de la persona', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      await _pumpApp(
        tester,
        {..._admin(), 'PATCH /me': (_) => meJson()},
        location: '/cuenta',
        requests: requests,
      );
      final before = requests.where((r) => r.path == '/organization').length;

      await tester.tap(find.byKey(const Key('gender-female')));
      await _settle(tester);

      expect(requests.firstWhere((r) => r.method == 'PATCH').data, {
        'gender': 'female',
      });
      // Los perfiles se vuelven a pedir: ahora dicen "Técnica", "Tesorera".
      expect(
        requests.where((r) => r.path == '/organization').length,
        greaterThan(before),
      );
      final chip = tester.widget<ChoiceChip>(
        find.byKey(const Key('gender-female')),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('sin permiso no aparece', (tester) async {
      await _pumpApp(
        tester,
        _admin(permissions: const []),
        location: '/cuenta',
      );
      expect(find.text('Cómo les dicen'), findsNothing);
    });
  });
}
