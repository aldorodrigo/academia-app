import 'package:academia_app/features/auth/data/auth_repository.dart';
import 'package:academia_app/features/onboarding/data/models.dart';
import 'package:academia_app/features/onboarding/data/onboarding_repository.dart';
import 'package:academia_app/features/organizations/data/organization_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'onboarding_json.dart';

void main() {
  group('cuenta', () {
    test('crear cuenta con el celular manda el captcha', () async {
      final storage = InMemorySessionStorage();
      final requests = <RequestOptions>[];
      await AuthRepository(
        fakeDio({
          'POST /auth/register': (_) => {'token': 'nuevo'},
        }, requests: requests),
        storage,
      ).register(
        name: 'Laura Gómez',
        phone: '0981 123 456',
        password: 'secreta123',
        passwordConfirmation: 'secreta123',
        captchaToken: 'cf-token',
      );

      expect(storage.token, 'nuevo');
      expect(requests.single.data, {
        'name': 'Laura Gómez',
        'phone': '0981 123 456',
        'password': 'secreta123',
        'password_confirmation': 'secreta123',
        'device_name': 'app',
        'terms': true,
        'captcha_token': 'cf-token',
      });
    });

    test('ingresar manda el celular o el correo como login', () async {
      final requests = <RequestOptions>[];
      final storage = InMemorySessionStorage();
      await AuthRepository(
        fakeDio({
          'POST /auth/token': (_) => {'token': 't'},
        }, requests: requests),
        storage,
      ).login(login: '0981 123 456', password: 'secreta123');
      expect(requests.single.data, {
        'login': '0981 123 456',
        'password': 'secreta123',
        'device_name': 'app',
      });
      expect(storage.token, 't');
    });

    test('reenviar el código por correo', () async {
      final requests = <RequestOptions>[];
      final repository = AuthRepository(
        fakeDio({'POST /auth/verify/resend': (_) => null}, requests: requests),
        InMemorySessionStorage(),
      );
      await repository.resendCode();
      await repository.resendCode(byEmail: true, captchaToken: 'cf');
      expect(requests.first.data, <String, Object?>{});
      expect(requests.last.data, {'channel': 'mail', 'captcha_token': 'cf'});
    });

    test('recuperar la contraseña con el código deja la sesión', () async {
      final requests = <RequestOptions>[];
      final storage = InMemorySessionStorage();
      final repository = AuthRepository(
        fakeDio({
          'POST /auth/password/forgot': (_) => null,
          'POST /auth/password/reset': (_) => {'token': 'nuevo'},
        }, requests: requests),
        storage,
      );

      await repository.forgotPassword('0981 123 456', captchaToken: 'cf');
      await repository.resetPassword(
        login: '0981 123 456',
        code: '123456',
        password: 'nueva1234',
        passwordConfirmation: 'nueva1234',
      );

      expect(requests.first.data, {
        'login': '0981 123 456',
        'captcha_token': 'cf',
      });
      expect(requests.last.data, {
        'login': '0981 123 456',
        'code': '123456',
        'password': 'nueva1234',
        'password_confirmation': 'nueva1234',
        'device_name': 'app',
      });
      expect(storage.token, 'nuevo');
    });

    test('crear cuenta guarda el token y acepta los términos', () async {
      final storage = InMemorySessionStorage();
      final requests = <RequestOptions>[];
      final repository = AuthRepository(
        fakeDio({
          'POST /auth/register': (_) => {'token': 'nuevo'},
        }, requests: requests),
        storage,
      );

      await repository.register(
        name: 'Laura Gómez',
        email: 'laura@test.com',
        password: 'secreta123',
        passwordConfirmation: 'secreta123',
      );

      expect(storage.token, 'nuevo');
      expect(requests.single.data, {
        'name': 'Laura Gómez',
        'email': 'laura@test.com',
        'password': 'secreta123',
        'password_confirmation': 'secreta123',
        'device_name': 'app',
        'terms': true,
      });
    });

    test('la sesión trae el celular y si la cuenta está verificada', () async {
      final storage = InMemorySessionStorage()..token = 't';
      final unverified = await AuthRepository(
        fakeDio({
          'GET /me': (_) => meJson(
            verified: false,
            phone: '+595981123456',
            email: null,
            organizations: const [],
          ),
        }),
        storage,
      ).restore();
      expect(unverified!.verified, isFalse);
      expect(unverified.phone, '+595981123456');
      expect(unverified.email, isNull);
      expect(unverified.contact, '0981 123 456');
      expect(unverified.organizations, isEmpty);

      // Sin el campo (API anterior), se toma como verificado.
      final old = await AuthRepository(
        fakeDio({
          'GET /me': (_) => {
            'data': {'name': 'Ana', 'email': 'a@t.com', 'organizations': []},
          },
        }),
        storage,
      ).restore();
      expect(old!.verified, isTrue);
      expect(old.contact, 'a@t.com');
    });

    test('verificar manda el código', () async {
      final requests = <RequestOptions>[];
      await AuthRepository(
        fakeDio({'POST /auth/verify': (_) => null}, requests: requests),
        InMemorySessionStorage(),
      ).verify('123456');
      expect(requests.single.data, {'code': '123456'});
    });
  });

  group('alta del club', () {
    test('lee las plantillas', () async {
      final repository = OnboardingRepository(
        fakeDio({'GET /onboarding/templates': (_) => templatesJson}),
        InMemorySessionStorage(),
      );

      final templates = await repository.templates();

      expect(templates.organizationTypes.map((t) => t.label), [
        'Club',
        'Academia',
      ]);
      expect(templates.type('academy')!.terminology['student'], 'Alumno');
      expect(templates.programs.first.criterion, GroupCriterion.birthYear);
      expect(templates.programs.last.criterion, GroupCriterion.level);
      expect(templates.terminologyOptions['group'], contains('Nivel'));
      expect(templates.agesSpan, 2);
    });

    test('revisa el identificador', () async {
      final requests = <RequestOptions>[];
      final repository = OnboardingRepository(
        fakeDio({
          'GET /organizations/slug': (_) => {
            'slug': 'jakare',
            'available': false,
            'suggestion': 'jakare-2',
          },
        }, requests: requests),
        InMemorySessionStorage(),
      );

      final check = await repository.checkSlug('Jakare');

      expect(requests.single.queryParameters, {'value': 'Jakare'});
      expect(check.available, isFalse);
      expect(check.usable, 'jakare-2');
    });

    test('crear el club lo deja como organización activa', () async {
      final storage = InMemorySessionStorage();
      final requests = <RequestOptions>[];
      final repository = OnboardingRepository(
        fakeDio({
          'POST /organizations': (_) => {
            'data': {
              'slug': 'club-jakare',
              'name': 'Club Jakare',
              'type': 'club',
            },
          },
        }, requests: requests),
        storage,
      );

      final slug = await repository.createOrganization(
        name: 'Club Jakare',
        type: 'club',
        slug: 'club-jakare',
        terminology: const {'student': 'Jugador'},
      );

      expect(slug, 'club-jakare');
      expect(storage.organization, 'club-jakare');
      expect(requests.single.data, {
        'name': 'Club Jakare',
        'type': 'club',
        'slug': 'club-jakare',
        'terminology': {'student': 'Jugador'},
      });
    });
  });

  group('guía', () {
    test('lee los pasos y descarta los que la app no conoce', () async {
      final json = onboardingJson(programs: 'done', groups: 'pending');
      ((json['data']! as Map)['steps'] as List).add({
        'key': 'enrollment',
        'title': 'Inscripciones',
        'status': 'pending',
      });
      final repository = OnboardingRepository(
        fakeDio({'GET /onboarding': (_) => json}),
        InMemorySessionStorage(),
      );

      final onboarding = await repository.onboarding();

      expect(onboarding.steps.map((s) => s.key), [
        'programs',
        'groups',
        'season',
        'instructors',
      ]);
      expect(onboarding.step('programs')!.status, StepStatus.done);
      expect(onboarding.step('programs')!.summary, 'Fútbol');
      expect(onboarding.step('instructors')!.blockedBy, 'groups');
      expect(onboarding.nextStep!.key, 'groups');
      expect(onboarding.numberOf('season'), 3);
      expect(onboarding.done, 1);
    });

    test(
      'crea categorías con horario propio y la cancha de cada horario',
      () async {
        final requests = <RequestOptions>[];
        final repository = OnboardingRepository(
          fakeDio({
            'POST /setup/groups': (_) => {
              'data': [groupJson(3, 'Sub-10'), groupJson(4, 'Sub-12')],
            },
          }, requests: requests),
          InMemorySessionStorage(),
        );

        final created = await repository.createGroups(
          programId: 1,
          groups: const [
            GroupDraft(
              name: 'Sub-10',
              minAge: 9,
              maxAge: 10,
              slots: [
                WeeklyTime(weekdays: {4, 2}, venueId: 7),
              ],
            ),
            GroupDraft(
              name: 'Sub-12',
              minAge: 11,
              maxAge: 12,
              // Dos horarios: martes a la tarde y sábado a la mañana; el vacío no va.
              slots: [
                WeeklyTime(weekdays: {2}, startsAt: '18:30', endsAt: '20:00'),
                WeeklyTime(weekdays: {6}, startsAt: '09:00', endsAt: '10:30'),
                WeeklyTime(),
              ],
            ),
          ],
          capacity: 20,
        );

        expect(created, hasLength(2));
        final body = requests.single.data as Map<String, Object?>;
        expect(body['program_id'], 1);
        expect(body.containsKey('venue'), isFalse);
        final groups = body['groups']! as List;
        // Cada horario con su cancha.
        expect((groups.first as Map)['schedules'], [
          {
            'weekday': 2,
            'starts_at': '17:00',
            'ends_at': '18:30',
            'venue_id': 7,
          },
          {
            'weekday': 4,
            'starts_at': '17:00',
            'ends_at': '18:30',
            'venue_id': 7,
          },
        ]);
        expect((groups.first as Map)['capacity'], 20);
        expect((groups.last as Map)['schedules'], [
          {'weekday': 2, 'starts_at': '18:30', 'ends_at': '20:00'},
          {'weekday': 6, 'starts_at': '09:00', 'ends_at': '10:30'},
        ]);
      },
    );

    test('la temporada va con los mismos campos que el panel', () async {
      final requests = <RequestOptions>[];
      final repository = OnboardingRepository(
        fakeDio({
          'GET /setup/seasons/new': (_) => seasonDraftJson(),
          'POST /setup/seasons/preview': (_) => seasonPreviewJson(),
        }, requests: requests),
        InMemorySessionStorage(),
      );

      final draft = await repository.newSeason();
      final preview = await repository.previewSeason(
        draft.copyWith(feeAmount: 150000, groupAmounts: const {3: 180000}),
      );

      expect(draft.startsOn, DateTime(2027));
      expect(draft.feeFrequency, FeeFrequency.monthly);
      final body = requests.last.data as Map<String, Object?>;
      expect(body['starts_on'], '2027-01-01');
      expect(body['fee_frequency'], 'mensual');
      expect(body['fee_amount'], 150000);
      expect(body['group_amounts'], [
        {'group_id': 3, 'amount': 180000},
      ]);
      expect(preview.suggestedEndsOn, DateTime(2027, 12, 31));
      expect(preview.dueDaysByFrequency[FeeFrequency.weekly], 3);
      expect(preview.examples.single.amount, '₲ 150.000');
      expect(preview.periodsCount, 12);
    });

    test('invitar a un técnico devuelve el link para compartir', () async {
      final requests = <RequestOptions>[];
      final repository = OnboardingRepository(
        fakeDio({
          'POST /setup/instructors': (_) => {
            'data': {
              'user_id': null,
              'invitation_id': 12,
              'name': 'Marta Ríos',
              'email': 'marta@test.com',
              'status': 'invitado',
              'groups': [
                {'id': 4, 'name': 'Sub-12'},
              ],
              'link': 'https://app.test/invitacion/abc',
            },
          },
        }, requests: requests),
        InMemorySessionStorage(),
      );

      final invited = await repository.inviteInstructor(
        name: 'Marta Ríos',
        email: 'marta@test.com',
        groupIds: const [4],
      );

      expect(requests.single.data, {
        'name': 'Marta Ríos',
        'email': 'marta@test.com',
        'group_ids': [4],
      });
      expect(invited.status, InstructorStatus.invited);
      expect(invited.link, 'https://app.test/invitacion/abc');
      expect(invited.groups.single.name, 'Sub-12');
    });

    test('invitar a un técnico por celular', () async {
      final requests = <RequestOptions>[];
      final repository = OnboardingRepository(
        fakeDio({
          'POST /setup/instructors': (_) => {
            'data': {
              'invitation_id': 13,
              'name': 'Marta Ríos',
              'email': null,
              'phone': '+595981555444',
              'status': 'invitado',
              'groups': [],
              'link': 'https://app.test/invitacion/abc',
            },
          },
        }, requests: requests),
        InMemorySessionStorage(),
      );

      final invited = await repository.inviteInstructor(
        name: 'Marta Ríos',
        phone: '0981 555 444',
        groupIds: const [],
      );

      expect(requests.single.data, {
        'name': 'Marta Ríos',
        'phone': '0981 555 444',
        'group_ids': <int>[],
      });
      expect(invited.phone, '+595981555444');
      expect(invited.email, isNull);
    });
  });

  test('cambiar cómo les dicen', () async {
    final requests = <RequestOptions>[];
    final storage = InMemorySessionStorage()..organization = 'jakare';
    final terminology = await OrganizationRepository(
      fakeDio({
        'PUT /organization/terminology': (_) => {
          'data': {
            'terminology': {
              'program': 'Disciplina',
              'group': 'Categoría',
              'student': 'Alumno',
              'instructor': 'Técnico',
              'guardian': 'Tutor',
              'space': 'Cancha',
            },
          },
        },
      }, requests: requests),
      storage,
    ).updateTerminology({'group': 'Categoría', 'instructor': 'Técnico'});

    expect(requests.single.data, {
      'terminology': {'group': 'Categoría', 'instructor': 'Técnico'},
    });
    expect(terminology['student'], 'Alumno');
    expect(terminology['space'], 'Cancha');
  });
}
