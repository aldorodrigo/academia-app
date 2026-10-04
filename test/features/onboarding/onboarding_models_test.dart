import 'package:academia_app/core/utils/validators.dart';
import 'package:academia_app/features/onboarding/data/models.dart';
import 'package:academia_app/features/onboarding/data/onboarding_controller.dart';
import 'package:academia_app/features/onboarding/data/step_controllers.dart';
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

  group('apertura de la guía', () {
    test('se abre sola una vez si está incompleta y no se cerró', () {
      final pending = _onboarding();
      expect(shouldAutoOpen(pending, const {}, 'jakare'), isTrue);
      expect(shouldAutoOpen(pending, const {'jakare'}, 'jakare'), isFalse);
      expect(
        shouldAutoOpen(_onboarding(dismissed: true), const {}, 'jakare'),
        isFalse,
      );
      expect(
        shouldAutoOpen(
          _onboarding(
            programs: 'done',
            groups: 'done',
            season: 'done',
            instructors: 'skipped',
          ),
          const {},
          'jakare',
        ),
        isFalse,
      );
      expect(shouldAutoOpen(null, const {}, 'jakare'), isFalse);
    });

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
      // Si ya estaba completa, vuelve a la lista.
      expect(nextRoute(complete, wasCompleted: true), '/configurar');
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
}
