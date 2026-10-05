/// Respuestas de la API para la guía (`API_V1.md`, Sprint 5d).
library;

Map<String, Object?> stepJson(
  String key,
  String status, {
  String? title,
  String? blockedBy,
  String? summary,
  bool skippable = false,
}) => {
  'key': key,
  'title':
      title ??
      {
        'programs': '¿Qué enseñan?',
        'groups': 'Categorías y horarios',
        'season': 'Temporada y cuotas',
        'instructors': 'Técnicos',
      }[key],
  'description': 'Para qué sirve $key.',
  'status': status,
  'required': key != 'instructors',
  'skippable': skippable || key == 'instructors',
  'blocked_by': blockedBy,
  'summary': summary,
  'minutes': 2,
};

Map<String, Object?> onboardingJson({
  String programs = 'pending',
  String groups = 'locked',
  String season = 'locked',
  String instructors = 'locked',
  bool dismissed = false,
  Map<String, Object?>? terminologySuggestion,
}) {
  final statuses = [programs, groups, season, instructors];
  final done = statuses.where((s) => s == 'done' || s == 'skipped').length;
  const keys = ['programs', 'groups', 'season', 'instructors'];
  String? next;
  for (var i = 0; i < keys.length; i++) {
    if (statuses[i] == 'pending' || statuses[i] == 'locked') {
      next = keys[i];
      break;
    }
  }
  return {
    'data': {
      'steps': [
        stepJson(
          'programs',
          programs,
          summary: programs == 'done' ? 'Fútbol' : null,
        ),
        stepJson(
          'groups',
          groups,
          blockedBy: groups == 'locked' ? 'programs' : null,
          summary: groups == 'done' ? '6 categorías' : null,
        ),
        stepJson(
          'season',
          season,
          blockedBy: season == 'locked' ? 'programs' : null,
          summary: season == 'done' ? '2027' : null,
        ),
        stepJson(
          'instructors',
          instructors,
          blockedBy: instructors == 'locked' ? 'groups' : null,
        ),
      ],
      'done': done,
      'total': 4,
      'next': next,
      'completed': next == null,
      'dismissed': dismissed,
      'terminology_suggestion': terminologySuggestion,
    },
  };
}

/// Propuesta de vocabulario de deporte (`terminology_suggestion`).
const sportSuggestionJson = {
  'programs': ['Fútbol'],
  'current': {
    'student': 'Alumno',
    'instructor': 'Profesor',
    'group': 'Grupo',
    'space': 'Sala',
  },
  'suggested': {
    'student': 'Jugador',
    'instructor': 'Técnico',
    'group': 'Categoría',
    'space': 'Cancha',
  },
};

const templatesJson = {
  'data': {
    'organization_types': [
      {
        'value': 'club',
        'label': 'Club',
        'description': 'Club o asociación deportiva',
        'terminology': {
          'program': 'Disciplina',
          'group': 'Categoría',
          'student': 'Jugador',
          'instructor': 'Técnico',
          'guardian': 'Tutor',
          'space': 'Cancha',
        },
      },
      {
        'value': 'academy',
        'label': 'Academia',
        'description': 'Academia de deporte, danza, música o idiomas',
        'terminology': {
          'program': 'Disciplina',
          'group': 'Grupo',
          'student': 'Alumno',
          'instructor': 'Profesor',
          'guardian': 'Tutor',
          'space': 'Sala',
        },
      },
    ],
    'terminology_options': {
      'student': ['Jugador', 'Alumno', 'Alumna'],
      'instructor': ['Técnico', 'Profesor'],
      'group': ['Categoría', 'Grupo', 'Nivel'],
      'space': ['Cancha', 'Sala', 'Aula'],
    },
    'programs': [
      {'name': 'Fútbol', 'group_criterion': 'birth_year'},
      {'name': 'Básquet', 'group_criterion': 'birth_year'},
      {'name': 'Danza', 'group_criterion': 'level'},
    ],
    'levels': ['Inicial', 'Intermedio', 'Avanzado'],
    'ages': {'from': 4, 'to': 16, 'span': 2},
  },
};

Map<String, Object?> programJson(
  int id,
  String name, {
  String criterion = 'birth_year',
  int groups = 0,
}) => {
  'id': id,
  'name': name,
  'group_criterion': criterion,
  'groups_count': groups,
};

Map<String, Object?> groupJson(
  int id,
  String name, {
  int programId = 1,
  String programName = 'Fútbol',
  List<int> weekdays = const [2, 4],
  int enrollments = 0,
}) => {
  'id': id,
  'program': {'id': programId, 'name': programName},
  'name': name,
  'min_age': 9,
  'max_age': 10,
  'level': null,
  'capacity': null,
  'is_active': true,
  'schedules': [
    for (final day in weekdays)
      {
        'weekday': day,
        'starts_at': '17:00',
        'ends_at': '18:30',
        'venue': {'id': 1, 'name': 'Cancha 1'},
      },
  ],
  'instructors': <Object?>[],
  'enrollments_count': enrollments,
};

Map<String, Object?> seasonDraftJson() => {
  'data': {
    'program_ids': [1],
    'kind': 'anual',
    'starts_on': '2027-01-01',
    'ends_on': '2027-12-31',
    'name': '2027',
    'fee_frequency': 'mensual',
    'daily_basis': 'entrenamiento',
    'daily_grouping': 'mes',
    'fee_amount': null,
    'enrollment_fee_amount': null,
    'group_amounts': <Object?>[],
    'due_days': 9,
    'issue_upfront': false,
    'mid_period': 'completo',
  },
};

Map<String, Object?> seasonPreviewJson({
  String endsOn = '2027-12-31',
  String name = '2027',
  String frequency = 'mensual',
}) => {
  'data': {
    'dates': {'ends_on': endsOn, 'name': name},
    'plan': {
      'fee_frequency': frequency,
      'due_days': 9,
      'due_days_by_frequency': {
        'mensual': 9,
        'quincenal': 3,
        'semanal': 3,
        'diaria': 5,
      },
    },
    'kinds': [
      {'value': 'anual', 'label': 'Anual', 'example': '1 ene – 31 dic'},
      {'value': 'semestral', 'label': 'Semestral', 'example': '1 ene – 30 jun'},
    ],
    'summary': '2027 de Fútbol, del 01/01/2027 al 31/12/2027. Cuota mensual de ₲ 150.000.',
    'examples': [
      {'period': 'enero 2027', 'due_on': '10/01/2027', 'amount': '₲ 150.000'},
    ],
    'due_example': 'Por ejemplo, «Cuota enero 2027» vence el 10/01/2027.',
    'periods_count': 12,
    'terms': termsJson(frequency == 'semanal' ? 'semana' : 'mes'),
  },
};

/// Palabras del plan como las arma la API (mes, semana o día).
Map<String, Object?> termsJson(String unit) => switch (unit) {
  'semana' => {
    'unit': 'semana',
    'issue_now': 'Al empezar cada semana',
    'issue_now_help': 'La familia ve solo la cuota de la semana en curso.',
    'issue_upfront_help': 'La familia ve las 52 cuotas: la de la semana en curso para pagar y el resto como próximas.',
    'issue_after': 'Al terminar cada semana',
    'basis_after': 'La cuota se crea al terminar cada semana.',
    'midway': 'Si alguien se inscribe a mitad de semana, se cobra',
    'mid_period_options': [
      {'value': 'completo', 'label': 'La semana completa'},
      {
        'value': 'proporcional',
        'label': 'Lo que falta de la semana (proporcional)',
      },
      {'value': 'proximo', 'label': 'Desde la semana que viene'},
    ],
    'due_question': '¿Qué día de la semana vence?',
    'due_options': [
      for (final (i, d) in [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ].indexed)
        {'value': i, 'label': d},
    ],
    'due_text': 'el jueves de cada semana',
  },
  'dia' => {
    'unit': 'día',
    'issue_now': 'El mismo día de cada entrenamiento',
    'issue_now_help': 'La familia ve solo la cuota del día.',
    'issue_upfront_help': 'La familia ve las 200 cuotas: la del día para pagar y el resto como próximas.',
    'issue_after': 'Unos días después de cada clase',
    'basis_after': 'La cuota se crea unos días después de cada clase.',
    'midway': null,
    'mid_period_options': <Object?>[],
    'due_question': '¿Cuándo vence?',
    'due_options': [
      {'value': 0, 'label': 'El mismo día'},
      {'value': 1, 'label': 'Al día siguiente'},
    ],
    'due_text': 'el mismo día',
  },
  _ => {
    'unit': 'mes',
    'issue_now': 'Al empezar cada mes',
    'issue_now_help': 'La familia ve solo la cuota del mes en curso.',
    'issue_upfront_help': 'La familia ve las 12 cuotas: la del mes en curso para pagar y el resto como próximas.',
    'issue_after': 'Al terminar cada mes',
    'basis_after': 'La cuota se crea al terminar cada mes.',
    'midway': 'Si alguien se inscribe a mitad de mes, se cobra',
    'mid_period_options': [
      {'value': 'completo', 'label': 'El mes completo'},
      {'value': 'proporcional', 'label': 'Lo que falta del mes (proporcional)'},
      {'value': 'proximo', 'label': 'Desde el mes que viene'},
    ],
    'due_question': '¿Qué día del mes vence?',
    'due_options': [
      for (var d = 0; d < 28; d++) {'value': d, 'label': 'Día ${d + 1}'},
    ],
    'due_text': 'el día 10 de cada mes',
  },
};

Map<String, Object?> instructorsJson({
  bool teaches = false,
  List<Map<String, Object?>> instructors = const [],
}) => {
  'data': {
    'me': {
      'teaches': teaches,
      'group_ids': teaches ? [3] : <int>[],
    },
    'instructors': instructors,
  },
};

Map<String, Object?> organizationJson({
  List<String> permissions = const ['configure_organization'],
  String type = 'club',
  String group = 'Categoría',
  String student = 'Jugador',
  String instructor = 'Técnico',
  String space = 'Cancha',
}) => {
  'data': {
    'slug': 'jakare',
    'name': 'Club Jakare',
    'type': type,
    'features': <String>[],
    'terminology': {
      'program': 'Disciplina',
      'group': group,
      'student': student,
      'instructor': instructor,
      'guardian': 'Tutor',
      'space': space,
    },
    'membership': {'roles': <Object?>[], 'permissions': permissions},
  },
};

Map<String, Object?> meJson({
  bool verified = true,
  String? phone,
  String? email = 'laura@test.com',
  List<Map<String, Object?>> organizations = const [
    {'slug': 'jakare', 'name': 'Club Jakare'},
  ],
}) => {
  'data': {
    'name': 'Laura',
    'phone': phone,
    'email': email,
    'verified': verified,
    'organizations': organizations,
  },
};
