import 'package:academia_app/core/utils/validators.dart';
import 'package:academia_app/features/onboarding/data/models.dart';
import 'package:academia_app/features/onboarding/data/onboarding_controller.dart';
import 'package:academia_app/features/onboarding/data/step_controllers.dart';
import 'package:academia_app/features/organizations/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_json.dart';

Onboarding _onboarding({
  String programs = 'pending',
  String groups = 'locked',
  String season = 'locked',
  String instructors = 'locked',
  bool dismissed = false,
}) => Onboarding.fromJson(
  onboardingJson(
        programs: programs,
        groups: groups,
        season: season,
        instructors: instructors,
        dismissed: dismissed,
      )['data']!
      as Map<String, dynamic>,
);

void main() {
  group('validaciones', () {
    test('código de 6 dígitos', () {
      expect(validateCode(''), 'Ingresá el código que te mandamos.');
      expect(validateCode('12a456'), 'El código tiene 6 dígitos.');
      expect(validateCode('12345'), 'El código tiene 6 dígitos.');
      expect(validateCode(' 123456 '), isNull);
    });

    test('términos', () {
      expect(validateTerms(false), 'Tenés que aceptar los términos.');
      expect(validateTerms(true), isNull);
    });

    test('nombre del club', () {
      expect(
        const ClubDraft(name: 'Ja').validate(),
        'Ingresá el nombre del club.',
      );
      expect(
        const ClubDraft(name: 'Club Jakare').validate(),
        'Esperá a que revisemos el nombre.',
      );
      expect(
        const ClubDraft(name: 'Club Jakare', slug: 'club-jakare').validate(),
        isNull,
      );
    });
  });

  group('vocabulario', () {
    test('plural de los términos habituales', () {
      expect(pluralize('Categoría'), 'Categorías');
      expect(pluralize('Técnico'), 'Técnicos');
      expect(pluralize('Profesor'), 'Profesores');
      expect(pluralize('Nivel'), 'Niveles');
      expect(pluralize('Jugador'), 'Jugadores');
    });

    test('resumen en una frase', () {
      const draft = ClubDraft(
        terminology: {
          'student': 'Alumna',
          'instructor': 'Profesor',
          'group': 'Nivel',
        },
      );
      expect(draft.termsSummary, 'Alumnas, profesores y niveles');
    });
  });

  group('horario', () {
    test('valida días y horas', () {
      expect(const WeeklyTime().validate(), 'Elegí al menos un día.');
      expect(
        const WeeklyTime(
          weekdays: {1},
          startsAt: '18:00',
          endsAt: '17:00',
        ).validate(),
        'El horario tiene que terminar después de empezar.',
      );
      expect(const WeeklyTime(weekdays: {1}).validate(), isNull);
    });

    test('se describe en palabras', () {
      expect(
        const WeeklyTime(weekdays: {4, 2}).toString(),
        'Mar y Jue de 17:00 a 18:30',
      );
      expect(
        describeSchedules(const [
          GroupSchedule(weekday: 1, startsAt: '17:00', endsAt: '18:00'),
          GroupSchedule(weekday: 3, startsAt: '17:00', endsAt: '18:00'),
          GroupSchedule(weekday: 6, startsAt: '09:00', endsAt: '10:00'),
        ]),
        'Lun y Mié de 17:00 a 18:00 · Sáb de 09:00 a 10:00',
      );
      expect(describeSchedules(const []), 'Sin horario');
    });
  });

  group('categorías', () {
    GroupsStep step(List<GroupDraft> drafts) => GroupsStep(
      programs: const [
        SetupProgram(
          id: 1,
          name: 'Fútbol',
          criterion: GroupCriterion.birthYear,
        ),
      ],
      groups: const [],
      sites: const [],
      levels: const [],
      programId: 1,
      drafts: drafts,
    );

    const tueThu = WeeklyTime(weekdays: {2, 4});

    test('la lista pide nombres sin repetir', () {
      expect(step(const []).validateList(), 'Agregá al menos una.');
      expect(
        step(const [GroupDraft(name: 'Sub-10'), GroupDraft(name: 'sub-10')])
            .validateList(),
        '«sub-10» está repetida.',
      );
      expect(step(const [GroupDraft(name: 'Sub-10')]).validateList(), isNull);
    });

    test('cada una tiene sus horarios; sin días se guarda igual', () {
      final missing = step(const [
        GroupDraft(name: 'Sub-8', slots: [tueThu]),
        GroupDraft(name: 'Sub-10'),
      ]);
      expect(missing.validate(), isNull);
      expect(missing.withoutSchedule, 1);
      expect(
        step(const [
          GroupDraft(
            name: 'Sub-12',
            slots: [
              tueThu,
              WeeklyTime(weekdays: {6}, startsAt: '10:00', endsAt: '09:00'),
            ],
          ),
        ]).validate(),
        'Sub-12: El horario tiene que terminar después de empezar.',
      );
      expect(
        const GroupDraft(
          name: 'Sub-8',
          slots: [tueThu, WeeklyTime()],
        ).filledSlots,
        [tueThu],
      );
    });

    test('las edades se muestran en palabras', () {
      expect(
        const GroupDraft(name: 'Sub-10', minAge: 9, maxAge: 10).detail,
        '9 y 10 años',
      );
      expect(
        const GroupDraft(name: 'Sub-6', minAge: 6, maxAge: 6).detail,
        '6 años',
      );
      expect(
        const GroupDraft(name: 'Inicial', level: 'Inicial').detail,
        isNull,
      );
    });
  });

  group('temporada', () {
    test('valida fechas, disciplinas y monto', () {
      final draft = SeasonDraft(
        startsOn: DateTime(2027),
        endsOn: DateTime(2027, 12, 31),
        name: '2027',
      );
      expect(
        draft.validateSeason(multiplePrograms: true),
        'Elegí al menos una disciplina.',
      );
      expect(draft.validateSeason(multiplePrograms: false), isNull);
      expect(
        draft
            .copyWith(endsOn: DateTime(2026, 12, 1))
            .validateSeason(multiplePrograms: false),
        'Tiene que terminar después de empezar.',
      );
      expect(draft.validatePlan(), 'Ingresá el monto de la cuota.');
      expect(draft.copyWith(feeAmount: 150000).validatePlan(), isNull);
      // Sin plan de cobro no se pide monto.
      expect(draft.copyWith(noPlan: true).validatePlan(), isNull);
    });

    test('por clase asistida las cuotas se crean al terminar el período', () {
      const draft = SeasonDraft(feeFrequency: FeeFrequency.daily);
      expect(draft.chargesAfterPeriod, isFalse);
      expect(
        draft.copyWith(dailyBasis: 'asistencia').chargesAfterPeriod,
        isTrue,
      );
    });
  });

  group('pasos de la guía', () {
    test('después de guardar va al siguiente o a "¡Listo!"', () {
      expect(
        nextRoute(
          _onboarding(programs: 'done', groups: 'done', season: 'pending'),
          wasCompleted: false,
        ),
        '/configurar/temporada',
      );
      final complete = _onboarding(
        programs: 'done',
        groups: 'done',
        season: 'done',
        instructors: 'done',
      );
      // Se completó en este paso (aunque haya sido antes de tocar "Seguir").
      expect(nextRoute(complete, wasCompleted: false), '/configurar/listo');
      // Si ya estaba completa, vuelve al inicio.
      expect(nextRoute(complete, wasCompleted: true), '/inicio');
    });
  });

  test('el mensaje de WhatsApp lleva el link', () {
    final text = invitationMessage(
      name: 'Marta Ríos',
      organization: 'Club Jakare',
      role: 'Técnico',
      link: 'https://app.test/invitacion/abc',
    );
    expect(
      text,
      'Hola Marta, te invito a sumarte como técnico de *Club Jakare* en '
      '*Tuku*, la app de cuotas, asistencia y avisos de clase.\n\n'
      'Creá tu cuenta desde este link:\nhttps://app.test/invitacion/abc\n\n'
      'Vence en 14 días y sirve una sola vez.',
    );
    expect(whatsappUri(text).host, 'wa.me');
    expect(whatsappUri(text).queryParameters['text'], text);
    // Con número, va directo a ese WhatsApp.
    final direct = whatsappUri(text, phone: '+595981555444');
    expect(direct.path, '/595981555444');
    expect(direct.queryParameters['text'], text);
  });

  test('lee las palabras del plan y oculta "mitad de…" por día', () {
    final week = BillingTerms.fromJson(termsJson('semana'));
    expect(week.dueOptions[3], (3, 'Jueves'));
    expect(week.midPeriodOptions.first, ('completo', 'La semana completa'));
    expect(week.midway, 'Si alguien se inscribe a mitad de semana, se cobra');

    final day = BillingTerms.fromJson(termsJson('dia'));
    expect(day.midway, isNull);
    expect(day.issueNow, 'El mismo día de cada entrenamiento');

    final preview = SeasonPreview.fromJson(
      seasonPreviewJson()['data']! as Map<String, dynamic>,
    );
    expect(preview.terms!.unit, 'mes');
  });

  test('concordancia con el vocabulario del club', () {
    for (final word in [
      'Categoría',
      'Clase',
      'Profesora',
      'Actividad',
      'Disciplina',
    ]) {
      expect(isFeminine(word), isTrue, reason: word);
    }
    for (final word in ['Grupo', 'Nivel', 'Técnico', 'Profesor', 'Estilo']) {
      expect(isFeminine(word), isFalse, reason: word);
    }
    expect(gendered('Grupo', 'cada uno', 'cada una'), 'cada uno');
    expect(gendered('Categoría', 'todos', 'todas'), 'todas');
  });

  test('propuesta de vocabulario de deporte', () {
    expect(_onboarding().terminologySuggestion, isNull);

    final onboarding = Onboarding.fromJson(
      onboardingJson(
            programs: 'done',
            groups: 'pending',
            terminologySuggestion: sportSuggestionJson,
          )['data']!
          as Map<String, dynamic>,
    );
    final suggestion = onboarding.terminologySuggestion!;
    expect(suggestion.programsText, 'fútbol');
    expect(suggestion.suggestedText, 'jugador, técnico, categoría y cancha');
    expect(suggestion.currentText, 'alumno, profesor, grupo y sala');
    expect(joinWords(['Fútbol', 'Básquet']), 'fútbol y básquet');
  });

  test('qué es la organización, para los textos de la guía', () {
    OrganizationDetails org(String? type) => OrganizationDetails.fromJson({
      ...(organizationJson()['data']! as Map<String, Object?>),
      'type': type,
    });
    expect(org('club').typeNoun, 'club');
    expect(org('club').typeWithArticle, 'el club');
    expect(org('academy').typeWithArticle, 'la academia');
    expect(org('school').typeNoun, 'escuela');
    expect(org('parents_association').typeNoun, 'comisión');
    expect(org(null).typeNoun, 'club');
  });

  test('cobro por día: la base dice el término del club', () {
    expect(
      dailyBasisOptions('Grupo')['entrenamiento']!.$2,
      'Los días con horario del grupo.',
    );
    expect(
      dailyBasisOptions('Categoría')['entrenamiento']!.$2,
      'Los días con horario de la categoría.',
    );
  });

  test('cuota de ejemplo con la fecha para los que se inscriben hoy', () {
    final example = SeasonExample.fromJson({
      'period': 'enero 2026',
      'due_on': '12/01/2026',
      'due_note': 'para los que se inscriben hoy',
      'amount': '₲ 150.000',
    });
    expect(example.dueNote, 'para los que se inscriben hoy');
    expect(
      SeasonExample.fromJson({
        'period': 'febrero 2026',
        'due_on': '10/02/2026',
        'amount': '₲ 150.000',
      }).dueNote,
      isNull,
    );
  });

  test('borrador del paso 2: ida y vuelta', () {
    final step = GroupsStep(
      programs: [SetupProgram.fromJson(programJson(1, 'Fútbol'))],
      groups: const [],
      sites: const [],
      levels: const ['Inicial'],
      programId: 1,
      capacity: 20,
      drafts: const [
        GroupDraft(
          name: 'Sub-8',
          minAge: 7,
          maxAge: 8,
          slots: [
            WeeklyTime(weekdays: {4, 2}, venueId: 11),
          ],
        ),
      ],
    );
    final json = step.toDraftJson()!;
    expect(json['program_id'], 1);
    expect(json['capacity'], 20);
    expect(((json['groups']! as List).first as Map)['slots'], [
      {
        'weekdays': [2, 4],
        'starts_at': '17:00',
        'ends_at': '18:30',
        'venue_id': 11,
      },
    ]);

    final empty = step.copyWith(drafts: const []);
    expect(empty.toDraftJson(), isNull);
    final resumed = empty.withDraft(Map<String, dynamic>.from(json))!;
    expect(resumed.drafts.single.name, 'Sub-8');
    expect(resumed.drafts.single.slots.single.weekdays, {2, 4});
    expect(resumed.capacity, 20);
    // De una disciplina que ya no existe: se arranca de nuevo.
    expect(empty.withDraft({...json, 'program_id': 99}), isNull);
  });
}
