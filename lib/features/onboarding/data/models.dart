import '../../../core/utils/format.dart';

/// Estado de un paso de la guía, calculado por la API desde los datos.
enum StepStatus {
  done,
  pending,
  locked,
  skipped;

  static StepStatus parse(Object? value) => StepStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => StepStatus.pending,
  );
}

class OnboardingStep {
  const OnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    required this.status,
    this.required = true,
    this.skippable = false,
    this.blockedBy,
    this.summary,
    this.minutes,
  });

  factory OnboardingStep.fromJson(Map<String, dynamic> json) => OnboardingStep(
    key: json['key'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    status: StepStatus.parse(json['status']),
    required: json['required'] as bool? ?? true,
    skippable: json['skippable'] as bool? ?? false,
    blockedBy: json['blocked_by'] as String?,
    summary: json['summary'] as String?,
    minutes: json['minutes'] as int?,
  );

  final String key;
  final String title;
  final String description;
  final StepStatus status;
  final bool required;
  final bool skippable;
  final String? blockedBy;

  /// Lo que ya está hecho ("Fútbol y Básquet", "6 categorías").
  final String? summary;
  final int? minutes;

  bool get isDone => status == StepStatus.done || status == StepStatus.skipped;
}

/// Guía "Primeros pasos" de la organización activa (`GET onboarding`).
class Onboarding {
  const Onboarding({
    required this.steps,
    required this.done,
    required this.total,
    this.next,
    this.completed = false,
    this.dismissed = false,
    this.terminologySuggestion,
  });

  factory Onboarding.fromJson(Map<String, dynamic> json) => Onboarding(
    steps: ((json['steps'] as List?) ?? const [])
        .map((s) => OnboardingStep.fromJson(s as Map<String, dynamic>))
        // La app dibuja solo los pasos que conoce.
        .where((s) => stepRoutes.containsKey(s.key))
        .toList(),
    done: json['done'] as int? ?? 0,
    total: json['total'] as int? ?? 0,
    next: json['next'] as String?,
    completed: json['completed'] as bool? ?? false,
    dismissed: json['dismissed'] as bool? ?? false,
    terminologySuggestion: json['terminology_suggestion'] is Map
        ? TerminologySuggestion.fromJson(
            Map<String, dynamic>.from(json['terminology_suggestion'] as Map),
          )
        : null,
  );

  final List<OnboardingStep> steps;
  final int done;
  final int total;

  /// Primer paso pendiente; null si está completa.
  final String? next;
  final bool completed;

  /// Se cerró: no se abre sola, pero sigue la tarjeta del inicio.
  final bool dismissed;

  /// Palabras de deporte propuestas (la API decide cuándo); null si no hay.
  final TerminologySuggestion? terminologySuggestion;

  OnboardingStep? step(String? key) {
    for (final step in steps) {
      if (step.key == key) return step;
    }
    return null;
  }

  OnboardingStep? get nextStep => step(next);

  /// Posición del paso para "Paso 2 de 4".
  int numberOf(String key) => steps.indexWhere((s) => s.key == key) + 1;
}

/// Propuesta de vocabulario de deporte: una academia que enseña fútbol pasa de
/// Grupo, Profesor y Sala a Categoría, Técnico y Cancha si el usuario quiere.
class TerminologySuggestion {
  const TerminologySuggestion({
    required this.programs,
    required this.current,
    required this.suggested,
  });

  factory TerminologySuggestion.fromJson(Map<String, dynamic> json) =>
      TerminologySuggestion(
        programs: List<String>.from(json['programs'] as List? ?? const []),
        current: Map<String, String>.from(json['current'] as Map? ?? const {}),
        suggested: Map<String, String>.from(
          json['suggested'] as Map? ?? const {},
        ),
      );

  /// Disciplinas deportivas que la originan ("Fútbol").
  final List<String> programs;

  /// Lo que dicen hoy las pantallas, solo las palabras que se proponen cambiar.
  final Map<String, String> current;
  final Map<String, String> suggested;

  /// "categoría, técnico y cancha".
  String get suggestedText => joinWords(suggested.values);

  /// "grupo, profesor y sala".
  String get currentText => joinWords(current.values);

  /// "fútbol", "fútbol y básquet".
  String get programsText => joinWords(programs);
}

/// "a, b y c" en minúscula.
String joinWords(Iterable<String> words) {
  final list = words.map((w) => w.toLowerCase()).toList();
  if (list.length <= 1) return list.join();
  return '${list.sublist(0, list.length - 1).join(', ')} y ${list.last}';
}

/// Ruta de cada paso de la guía.
const stepRoutes = {
  'programs': '/configurar/disciplinas',
  'groups': '/configurar/categorias',
  'season': '/configurar/temporada',
  'instructors': '/configurar/tecnicos',
};

// ---------------------------------------------------------------------------
// Plantillas (`GET onboarding/templates`)

class OrganizationTypeOption {
  const OrganizationTypeOption({
    required this.value,
    required this.label,
    required this.description,
    required this.terminology,
  });

  factory OrganizationTypeOption.fromJson(Map<String, dynamic> json) =>
      OrganizationTypeOption(
        value: json['value'] as String,
        label: json['label'] as String,
        description: json['description'] as String? ?? '',
        terminology: Map<String, String>.from(
          json['terminology'] as Map? ?? const {},
        ),
      );

  final String value;
  final String label;
  final String description;
  final Map<String, String> terminology;
}

/// Disciplina sugerida con su criterio de categorías.
class ProgramTemplate {
  const ProgramTemplate({required this.name, required this.criterion});

  factory ProgramTemplate.fromJson(Map<String, dynamic> json) =>
      ProgramTemplate(
        name: json['name'] as String,
        criterion: GroupCriterion.parse(json['group_criterion']),
      );

  final String name;
  final GroupCriterion criterion;
}

class OnboardingTemplates {
  const OnboardingTemplates({
    required this.organizationTypes,
    required this.terminologyOptions,
    required this.programs,
    required this.levels,
    this.agesFrom = 4,
    this.agesTo = 16,
    this.agesSpan = 2,
  });

  factory OnboardingTemplates.fromJson(Map<String, dynamic> json) {
    final ages = json['ages'] as Map<String, dynamic>? ?? const {};
    return OnboardingTemplates(
      organizationTypes: ((json['organization_types'] as List?) ?? const [])
          .map(
            (t) => OrganizationTypeOption.fromJson(t as Map<String, dynamic>),
          )
          .toList(),
      terminologyOptions: {
        for (final entry
            in (json['terminology_options'] as Map? ?? const {}).entries)
          entry.key as String: List<String>.from(entry.value as List),
      },
      programs: ((json['programs'] as List?) ?? const [])
          .map((p) => ProgramTemplate.fromJson(p as Map<String, dynamic>))
          .toList(),
      levels: List<String>.from(json['levels'] as List? ?? const []),
      agesFrom: ages['from'] as int? ?? 4,
      agesTo: ages['to'] as int? ?? 16,
      agesSpan: ages['span'] as int? ?? 2,
    );
  }

  final List<OrganizationTypeOption> organizationTypes;

  /// Opciones de vocabulario por clave (student, instructor, group).
  final Map<String, List<String>> terminologyOptions;
  final List<ProgramTemplate> programs;
  final List<String> levels;
  final int agesFrom;
  final int agesTo;
  final int agesSpan;

  OrganizationTypeOption? type(String? value) {
    for (final type in organizationTypes) {
      if (type.value == value) return type;
    }
    return null;
  }
}

/// `GET organizations/slug`: identificador libre para el club.
class SlugCheck {
  const SlugCheck({
    required this.slug,
    required this.available,
    this.suggestion,
  });

  factory SlugCheck.fromJson(Map<String, dynamic> json) => SlugCheck(
    slug: json['slug'] as String,
    available: json['available'] as bool? ?? false,
    suggestion: json['suggestion'] as String?,
  );

  final String slug;
  final bool available;
  final String? suggestion;

  /// El que se usa: el pedido si está libre, si no la alternativa.
  String? get usable => available ? slug : suggestion;
}

/// Género de un término del club (Categoría / Grupo, Técnico / Profesora),
/// para que los textos concuerden: "la categoría" / "el grupo".
bool isFeminine(String word) {
  final lower = word.trim().toLowerCase();
  return lower == 'clase' || lower.endsWith('a') || lower.endsWith('dad');
}

/// La forma según el género: gendered('Grupo', 'otro', 'otra') → "otro".
String gendered(String word, String masculine, String feminine) =>
    isFeminine(word) ? feminine : masculine;

/// Plural en español de los términos habituales (categoría → categorías).
String pluralize(String word) {
  final lower = word.toLowerCase();
  if (lower.endsWith('z')) return '${word.substring(0, word.length - 1)}ces';
  if (RegExp(r'[aeiouáéó]$').hasMatch(lower)) return '${word}s';
  return '${word}es';
}

// ---------------------------------------------------------------------------
// Paso 1: disciplinas

enum GroupCriterion {
  birthYear('birth_year', 'Por edad'),
  level('level', 'Por nivel');

  const GroupCriterion(this.value, this.label);

  final String value;
  final String label;

  static GroupCriterion parse(Object? value) => GroupCriterion.values
      .firstWhere((c) => c.value == value, orElse: () => GroupCriterion.level);
}

class SetupProgram {
  const SetupProgram({
    required this.id,
    required this.name,
    required this.criterion,
    this.groupsCount = 0,
  });

  factory SetupProgram.fromJson(Map<String, dynamic> json) => SetupProgram(
    id: json['id'] as int,
    name: json['name'] as String,
    criterion: GroupCriterion.parse(json['group_criterion']),
    groupsCount: json['groups_count'] as int? ?? 0,
  );

  final int id;
  final String name;
  final GroupCriterion criterion;
  final int groupsCount;
}

// ---------------------------------------------------------------------------
// Paso 2: categorías y horarios

class GroupSchedule {
  const GroupSchedule({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
    this.venueId,
    this.venueName,
  });

  factory GroupSchedule.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] as Map<String, dynamic>?;
    return GroupSchedule(
      weekday: json['weekday'] as int,
      startsAt: json['starts_at'] as String,
      endsAt: json['ends_at'] as String,
      venueId: venue?['id'] as int?,
      venueName: venue?['name'] as String?,
    );
  }

  final int weekday;
  final String startsAt;
  final String endsAt;
  final int? venueId;
  final String? venueName;

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'starts_at': startsAt,
    'ends_at': endsAt,
    if (venueId != null) 'venue_id': venueId,
  };
}

/// Días y horario de una categoría ("Mar y Jue de 17:00 a 18:30").
class WeeklyTime {
  const WeeklyTime({
    this.weekdays = const {},
    this.startsAt = '17:00',
    this.endsAt = '18:30',
    this.venueId,
  });

  /// Los horarios de una categoría, si todos son a la misma hora.
  factory WeeklyTime.of(List<GroupSchedule> schedules) => schedules.isEmpty
      ? const WeeklyTime()
      : WeeklyTime(
          weekdays: {for (final s in schedules) s.weekday},
          startsAt: schedules.first.startsAt,
          endsAt: schedules.first.endsAt,
          venueId: schedules.first.venueId,
        );

  final Set<int> weekdays;
  final String startsAt;
  final String endsAt;

  /// La cancha (sala, aula) de un lugar; null = sin cancha.
  final int? venueId;

  WeeklyTime copyWith({
    Set<int>? weekdays,
    String? startsAt,
    String? endsAt,
    int? venueId,
    bool clearVenue = false,
  }) => WeeklyTime(
    weekdays: weekdays ?? this.weekdays,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    venueId: clearVenue ? null : (venueId ?? this.venueId),
  );

  bool get isEmpty => weekdays.isEmpty;

  /// null si está bien; si no, el problema.
  String? validate() {
    if (weekdays.isEmpty) return 'Elegí al menos un día.';
    if ((minutesOf(endsAt) ?? 0) <= (minutesOf(startsAt) ?? 0)) {
      return 'El horario tiene que terminar después de empezar.';
    }
    return null;
  }

  List<GroupSchedule> toSchedules({int? venueId}) => [
    for (final day in weekdays.toList()..sort())
      GroupSchedule(
        weekday: day,
        startsAt: startsAt,
        endsAt: endsAt,
        venueId: venueId ?? this.venueId,
      ),
  ];

  @override
  String toString() {
    if (weekdays.isEmpty) return 'Sin horario';
    final days = (weekdays.toList()..sort()).map(weekdayShort).toList();
    final list = days.length == 1
        ? days.first
        : '${days.sublist(0, days.length - 1).join(', ')} y ${days.last}';
    return '$list de $startsAt a $endsAt';
  }
}

/// Resumen de los horarios de una categoría (pueden ser a distintas horas).
String describeSchedules(List<GroupSchedule> schedules) {
  if (schedules.isEmpty) return 'Sin horario';
  final byTime = <String, List<GroupSchedule>>{};
  for (final s in schedules) {
    byTime.putIfAbsent('${s.startsAt}-${s.endsAt}', () => []).add(s);
  }
  return byTime.values
      .map((list) => WeeklyTime.of(list).toString())
      .join(' · ');
}

/// Cancha, sala o aula de un lugar.
class Space {
  const Space({required this.id, required this.name, required this.label});

  factory Space.fromJson(Map<String, dynamic> json) => Space(
    id: json['id'] as int,
    name: json['name'] as String,
    label: json['label'] as String? ?? json['name'] as String,
  );

  final int id;
  final String name;

  /// "Polideportivo · Cancha 2" (o solo el lugar si tiene una sola).
  final String label;
}

/// Lugar donde entrena el club, con sus canchas.
class Site {
  const Site({
    required this.id,
    required this.name,
    this.address,
    this.spaces = const [],
  });

  factory Site.fromJson(Map<String, dynamic> json) => Site(
    id: json['id'] as int,
    name: json['name'] as String,
    address: json['address'] as String?,
    spaces: ((json['spaces'] as List?) ?? const [])
        .map((s) => Space.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String name;
  final String? address;
  final List<Space> spaces;
}

class SetupGroup {
  const SetupGroup({
    required this.id,
    required this.programId,
    required this.programName,
    required this.name,
    this.minAge,
    this.maxAge,
    this.level,
    this.capacity,
    this.isActive = true,
    this.schedules = const [],
    this.instructorNames = const [],
    this.enrollmentsCount = 0,
  });

  factory SetupGroup.fromJson(Map<String, dynamic> json) {
    final program = json['program'] as Map<String, dynamic>;
    return SetupGroup(
      id: json['id'] as int,
      programId: program['id'] as int,
      programName: program['name'] as String,
      name: json['name'] as String,
      minAge: json['min_age'] as int?,
      maxAge: json['max_age'] as int?,
      level: json['level'] as String?,
      capacity: json['capacity'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      schedules: ((json['schedules'] as List?) ?? const [])
          .map((s) => GroupSchedule.fromJson(s as Map<String, dynamic>))
          .toList(),
      instructorNames: ((json['instructors'] as List?) ?? const [])
          .map((i) => (i as Map<String, dynamic>)['name'] as String)
          .toList(),
      enrollmentsCount: json['enrollments_count'] as int? ?? 0,
    );
  }

  final int id;
  final int programId;
  final String programName;
  final String name;
  final int? minAge;
  final int? maxAge;
  final String? level;
  final int? capacity;
  final bool isActive;
  final List<GroupSchedule> schedules;
  final List<String> instructorNames;
  final int enrollmentsCount;

  /// Cuerpo de `PUT setup/groups/{id}` con otros horarios.
  Map<String, Object?> toJson({List<GroupSchedule>? schedules}) => {
    'name': name,
    'min_age': minAge,
    'max_age': maxAge,
    'level': level,
    'capacity': capacity,
    'is_active': isActive,
    'schedules': (schedules ?? this.schedules).map((s) => s.toJson()).toList(),
  };
}

/// Categoría por crear (sugerida por la API o agregada a mano).
class GroupDraft {
  const GroupDraft({
    required this.name,
    this.minAge,
    this.maxAge,
    this.level,
    this.slots = const [WeeklyTime()],
  });

  factory GroupDraft.fromJson(Map<String, dynamic> json) => GroupDraft(
    name: json['name'] as String,
    minAge: json['min_age'] as int?,
    maxAge: json['max_age'] as int?,
    level: json['level'] as String?,
  );

  final String name;
  final int? minAge;
  final int? maxAge;
  final String? level;

  /// Horarios de la categoría: días y hora ("Mar y Jue de 17:00 a 18:30");
  /// "+ Otro horario" agrega uno con otros días a otra hora.
  final List<WeeklyTime> slots;

  /// Los horarios con días elegidos (los vacíos no se guardan).
  List<WeeklyTime> get filledSlots => [
    for (final slot in slots)
      if (!slot.isEmpty) slot,
  ];

  /// Todavía no tiene ningún día elegido.
  bool get withoutSchedule => filledSlots.isEmpty;

  GroupDraft copyWith({String? name, List<WeeklyTime>? slots}) => GroupDraft(
    name: name ?? this.name,
    minAge: minAge,
    maxAge: maxAge,
    level: level,
    slots: slots ?? this.slots,
  );

  /// "9 y 10 años" o el nivel.
  String? get detail {
    if (minAge != null && maxAge != null) {
      return minAge == maxAge ? '$maxAge años' : '$minAge y $maxAge años';
    }
    if (maxAge != null) return 'hasta $maxAge años';
    return null;
  }
}

// ---------------------------------------------------------------------------
// Paso 3: temporada y cuotas

enum FeeFrequency {
  monthly('mensual', 'Mensual', 'Una cuota por mes.'),
  fortnightly('quincenal', 'Quincenal', 'Del 1 al 15 y del 16 a fin de mes.'),
  weekly('semanal', 'Semanal', 'De lunes a domingo.'),
  daily('diaria', 'Por día', 'Un monto por día de entrenamiento o por clase.');

  const FeeFrequency(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;

  static FeeFrequency? parse(Object? value) {
    for (final f in FeeFrequency.values) {
      if (f.value == value) return f;
    }
    return null;
  }

  /// Etiqueta del monto: "Cuota mensual", "Monto por día"…
  String get amountLabel => switch (this) {
    FeeFrequency.monthly => 'Cuota por mes',
    FeeFrequency.fortnightly => 'Cuota por quincena',
    FeeFrequency.weekly => 'Cuota por semana',
    FeeFrequency.daily => 'Monto por día',
  };
}

/// Bases del cobro por día; [group] es el término del club ("Categoría").
Map<String, (String, String)> dailyBasisOptions(String group) => {
  'entrenamiento': (
    'Días de entrenamiento',
    'Los días con horario ${gendered(group, 'del', 'de la')} ${group.toLowerCase()}.',
  ),
  'asistencia': (
    'Clases asistidas',
    'Las clases a las que vino, según la asistencia.',
  ),
  'dictado': (
    'Clases dictadas',
    'Las clases que se dieron: las suspendidas no se cobran.',
  ),
};

const dailyGroupingOptions = {
  'mes': 'Una cuota por mes',
  'semana': 'Una cuota por semana',
  'dia': 'Una cuota por día',
};

/// Opciones de "a mitad de…" sin unidad (hasta que llega el resumen de la API).
const midPeriodOptions = {
  'completo': 'Completo',
  'proporcional': 'Proporcional (lo que falta)',
  'proximo': 'Desde la próxima cuota',
};

/// Palabras del plan elegido (mes, quincena, semana o día), ya armadas por la
/// API: la app no calcula género ni artículos.
class BillingTerms {
  const BillingTerms({
    required this.unit,
    required this.issueNow,
    required this.issueNowHelp,
    required this.issueUpfrontHelp,
    required this.issueAfter,
    required this.basisAfter,
    required this.dueQuestion,
    required this.dueText,
    this.midway,
    this.midPeriodOptions = const [],
    this.dueOptions = const [],
  });

  factory BillingTerms.fromJson(Map<String, dynamic> json) => BillingTerms(
    unit: json['unit'] as String,
    issueNow: json['issue_now'] as String,
    issueNowHelp: json['issue_now_help'] as String,
    issueUpfrontHelp: json['issue_upfront_help'] as String,
    issueAfter: json['issue_after'] as String,
    basisAfter: json['basis_after'] as String,
    midway: json['midway'] as String?,
    midPeriodOptions: [
      for (final o in (json['mid_period_options'] as List?) ?? const [])
        ((o as Map<String, dynamic>)['value'] as String, o['label'] as String),
    ],
    dueQuestion: json['due_question'] as String,
    dueOptions: [
      for (final o in (json['due_options'] as List?) ?? const [])
        ((o as Map<String, dynamic>)['value'] as int, o['label'] as String),
    ],
    dueText: json['due_text'] as String,
  );

  /// "mes", "quincena", "semana" o "día".
  final String unit;

  /// "Al empezar cada mes".
  final String issueNow;
  final String issueNowHelp;
  final String issueUpfrontHelp;

  /// Por clase asistida o dictada: "Al terminar cada mes".
  final String issueAfter;

  /// "La cuota se crea al terminar cada mes."
  final String basisAfter;

  /// "Si alguien se inscribe a mitad de mes, se cobra"; null si no aplica (por día).
  final String? midway;
  final List<(String, String)> midPeriodOptions;

  /// "¿Qué día del mes vence?"
  final String dueQuestion;
  final List<(int, String)> dueOptions;

  /// "el día 10 de cada mes".
  final String dueText;
}

/// Estado del asistente de temporada (los mismos campos que el panel).
class SeasonDraft {
  const SeasonDraft({
    this.programIds = const [],
    this.kind = 'anual',
    this.startsOn,
    this.endsOn,
    this.name = '',
    this.feeFrequency = FeeFrequency.monthly,
    this.dailyBasis = 'entrenamiento',
    this.dailyGrouping = 'mes',
    this.feeAmount,
    this.enrollmentFeeAmount,
    this.groupAmounts = const {},
    this.dueDays = 9,
    this.issueUpfront = false,
    this.midPeriod = 'completo',
  });

  factory SeasonDraft.fromJson(Map<String, dynamic> json) => SeasonDraft(
    programIds: List<int>.from(json['program_ids'] as List? ?? const []),
    kind: json['kind'] as String? ?? 'anual',
    startsOn: _date(json['starts_on']),
    endsOn: _date(json['ends_on']),
    name: json['name'] as String? ?? '',
    feeFrequency: FeeFrequency.parse(json['fee_frequency']),
    dailyBasis: json['daily_basis'] as String? ?? 'entrenamiento',
    dailyGrouping: json['daily_grouping'] as String? ?? 'mes',
    feeAmount: json['fee_amount'] as int?,
    enrollmentFeeAmount: json['enrollment_fee_amount'] as int?,
    groupAmounts: {
      for (final row in (json['group_amounts'] as List?) ?? const [])
        (row as Map<String, dynamic>)['group_id'] as int: row['amount'] as int,
    },
    dueDays: json['due_days'] as int? ?? 9,
    issueUpfront: _bool(json['issue_upfront']),
    midPeriod: json['mid_period'] as String? ?? 'completo',
  );

  final List<int> programIds;
  final String kind;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String name;

  /// null = sin plan de cobro.
  final FeeFrequency? feeFrequency;
  final String dailyBasis;
  final String dailyGrouping;
  final int? feeAmount;
  final int? enrollmentFeeAmount;

  /// Categorías que pagan distinto: id → monto.
  final Map<int, int> groupAmounts;
  final int dueDays;
  final bool issueUpfront;
  final String midPeriod;

  bool get hasPlan => feeFrequency != null;

  /// Cuotas que se crean al terminar el período (por clase asistida o dictada).
  bool get chargesAfterPeriod =>
      feeFrequency == FeeFrequency.daily && dailyBasis != 'entrenamiento';

  SeasonDraft copyWith({
    List<int>? programIds,
    String? kind,
    DateTime? startsOn,
    DateTime? endsOn,
    String? name,
    FeeFrequency? feeFrequency,
    bool noPlan = false,
    String? dailyBasis,
    String? dailyGrouping,
    int? feeAmount,
    bool clearFeeAmount = false,
    int? enrollmentFeeAmount,
    bool clearEnrollmentFee = false,
    Map<int, int>? groupAmounts,
    int? dueDays,
    bool? issueUpfront,
    String? midPeriod,
  }) => SeasonDraft(
    programIds: programIds ?? this.programIds,
    kind: kind ?? this.kind,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    name: name ?? this.name,
    feeFrequency: noPlan ? null : (feeFrequency ?? this.feeFrequency),
    dailyBasis: dailyBasis ?? this.dailyBasis,
    dailyGrouping: dailyGrouping ?? this.dailyGrouping,
    feeAmount: clearFeeAmount ? null : (feeAmount ?? this.feeAmount),
    enrollmentFeeAmount: clearEnrollmentFee
        ? null
        : (enrollmentFeeAmount ?? this.enrollmentFeeAmount),
    groupAmounts: groupAmounts ?? this.groupAmounts,
    dueDays: dueDays ?? this.dueDays,
    issueUpfront: issueUpfront ?? this.issueUpfront,
    midPeriod: midPeriod ?? this.midPeriod,
  );

  Map<String, Object?> toJson() => {
    'program_ids': programIds,
    'kind': kind,
    'starts_on': startsOn == null ? null : apiDate(startsOn!),
    'ends_on': endsOn == null ? null : apiDate(endsOn!),
    'name': name,
    'fee_frequency': feeFrequency?.value,
    'daily_basis': dailyBasis,
    'daily_grouping': dailyGrouping,
    'fee_amount': feeAmount,
    'enrollment_fee_amount': enrollmentFeeAmount,
    'group_amounts': [
      for (final entry in groupAmounts.entries)
        {'group_id': entry.key, 'amount': entry.value},
    ],
    'due_days': dueDays,
    'issue_upfront': issueUpfront,
    'mid_period': midPeriod,
  };

  /// Validación de cada página del asistente: null si se puede seguir.
  String? validateSeason({required bool multiplePrograms}) {
    if (multiplePrograms && programIds.isEmpty) {
      return 'Elegí al menos una disciplina.';
    }
    if (startsOn == null || endsOn == null) {
      return 'Completá las fechas de la temporada.';
    }
    if (endsOn!.isBefore(startsOn!)) {
      return 'Tiene que terminar después de empezar.';
    }
    if (name.trim().isEmpty) return 'Poné un nombre a la temporada.';
    return null;
  }

  String? validatePlan() {
    if (!hasPlan) return null;
    if ((feeAmount ?? 0) <= 0) return 'Ingresá el monto de la cuota.';
    if (dueDays < 0 || dueDays > 60) {
      return 'El vencimiento tiene que ser de 0 a 60 días.';
    }
    return null;
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value) : null;

  static bool _bool(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';
}

class SeasonExample {
  const SeasonExample({
    required this.period,
    required this.dueOn,
    required this.amount,
  });

  factory SeasonExample.fromJson(Map<String, dynamic> json) => SeasonExample(
    period: json['period'] as String,
    dueOn: json['due_on'] as String,
    amount: json['amount'] as String,
  );

  final String period;
  final String dueOn;
  final String amount;
}

class SeasonKindOption {
  const SeasonKindOption({
    required this.value,
    required this.label,
    required this.example,
  });

  factory SeasonKindOption.fromJson(Map<String, dynamic> json) =>
      SeasonKindOption(
        value: json['value'] as String,
        label: json['label'] as String,
        example: json['example'] as String? ?? '',
      );

  final String value;
  final String label;
  final String example;
}

/// `POST setup/seasons/preview`: fechas y plan sugeridos, resumen y ejemplos.
class SeasonPreview {
  const SeasonPreview({
    this.suggestedEndsOn,
    this.suggestedName,
    this.suggestedFrequency,
    this.suggestedDueDays,
    this.dueDaysByFrequency = const {},
    this.kinds = const [],
    this.summary = '',
    this.examples = const [],
    this.dueExample,
    this.periodsCount = 0,
    this.terms,
  });

  factory SeasonPreview.fromJson(Map<String, dynamic> json) {
    final dates = json['dates'] as Map<String, dynamic>? ?? const {};
    final plan = json['plan'] as Map<String, dynamic>? ?? const {};
    return SeasonPreview(
      suggestedEndsOn: dates['ends_on'] is String
          ? DateTime.parse(dates['ends_on'] as String)
          : null,
      suggestedName: dates['name'] as String?,
      suggestedFrequency: FeeFrequency.parse(plan['fee_frequency']),
      suggestedDueDays: plan['due_days'] as int?,
      dueDaysByFrequency: {
        for (final entry
            in (plan['due_days_by_frequency'] as Map? ?? const {}).entries)
          if (FeeFrequency.parse(entry.key) != null)
            FeeFrequency.parse(entry.key)!: entry.value as int,
      },
      kinds: ((json['kinds'] as List?) ?? const [])
          .map((k) => SeasonKindOption.fromJson(k as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String? ?? '',
      examples: ((json['examples'] as List?) ?? const [])
          .map((e) => SeasonExample.fromJson(e as Map<String, dynamic>))
          .toList(),
      dueExample: json['due_example'] as String?,
      periodsCount: json['periods_count'] as int? ?? 0,
      terms: json['terms'] is Map
          ? BillingTerms.fromJson(json['terms'] as Map<String, dynamic>)
          : null,
    );
  }

  final DateTime? suggestedEndsOn;
  final String? suggestedName;
  final FeeFrequency? suggestedFrequency;
  final int? suggestedDueDays;

  /// Vencimiento sugerido para cada frecuencia (al cambiarla).
  final Map<FeeFrequency, int> dueDaysByFrequency;
  final List<SeasonKindOption> kinds;
  final String summary;
  final List<SeasonExample> examples;
  final String? dueExample;
  final int periodsCount;

  /// Palabras del plan; null sin plan de cobro.
  final BillingTerms? terms;
}

class SetupSeason {
  const SetupSeason({
    required this.id,
    required this.name,
    required this.status,
    this.hasFeePlan = false,
  });

  factory SetupSeason.fromJson(Map<String, dynamic> json) => SetupSeason(
    id: json['id'] as int,
    name: json['name'] as String,
    status: json['status'] as String? ?? 'vigente',
    hasFeePlan: json['has_fee_plan'] as bool? ?? false,
  );

  final int id;
  final String name;

  /// vigente, proxima o terminada.
  final String status;
  final bool hasFeePlan;
}

// ---------------------------------------------------------------------------
// Paso 4: técnicos

enum InstructorStatus {
  active('activo', 'Activo'),
  invited('invitado', 'Invitado'),
  expired('vencida', 'Invitación vencida');

  const InstructorStatus(this.value, this.label);

  final String value;
  final String label;

  static InstructorStatus parse(Object? value) =>
      InstructorStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => InstructorStatus.invited,
      );
}

class GroupRef {
  const GroupRef({required this.id, required this.name});

  factory GroupRef.fromJson(Map<String, dynamic> json) =>
      GroupRef(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

class SetupInstructor {
  const SetupInstructor({
    required this.name,
    this.email,
    this.phone,
    required this.status,
    this.userId,
    this.invitationId,
    this.groups = const [],
    this.link,
  });

  factory SetupInstructor.fromJson(Map<String, dynamic> json) =>
      SetupInstructor(
        userId: json['user_id'] as int?,
        invitationId: json['invitation_id'] as int?,
        name:
            json['name'] as String? ??
            json['email'] as String? ??
            json['phone'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        status: InstructorStatus.parse(json['status']),
        groups: ((json['groups'] as List?) ?? const [])
            .map((g) => GroupRef.fromJson(g as Map<String, dynamic>))
            .toList(),
        link: json['link'] as String?,
      );

  final int? userId;
  final int? invitationId;
  final String name;

  /// Correo o celular (formato internacional) al que se invitó.
  final String? email;
  final String? phone;
  final InstructorStatus status;
  final List<GroupRef> groups;

  /// Link de la invitación recién creada (la única vez que se ve).
  final String? link;
}

class SetupInstructors {
  const SetupInstructors({
    required this.teaches,
    required this.myGroupIds,
    required this.instructors,
  });

  factory SetupInstructors.fromJson(Map<String, dynamic> json) {
    final me = json['me'] as Map<String, dynamic>? ?? const {};
    return SetupInstructors(
      teaches: me['teaches'] as bool? ?? false,
      myGroupIds: List<int>.from(me['group_ids'] as List? ?? const []),
      instructors: ((json['instructors'] as List?) ?? const [])
          .map((i) => SetupInstructor.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }

  /// El usuario actual también da clases.
  final bool teaches;
  final List<int> myGroupIds;
  final List<SetupInstructor> instructors;
}

/// Texto con la marca Tuku para mandar una invitación por WhatsApp (con el
/// formato de WhatsApp; igual que el de la API en `Invitation::whatsappText`).
String invitationMessage({
  required String name,
  required String organization,
  required String role,
  required String link,
}) {
  final first = name.trim().split(' ').first;
  final greeting = first.isEmpty ? 'Hola' : 'Hola $first';
  return '$greeting, te invito a sumarte como ${role.toLowerCase()} de '
      '*$organization* en *Tuku*, la app de cuotas, asistencia y avisos de '
      'clase.\n\nCreá tu cuenta desde este link:\n$link\n\n'
      'Vence en 14 días y sirve una sola vez.';
}

/// Link de WhatsApp con el texto ya escrito: al [phone] (formato
/// internacional) o, sin número, elegís a quién mandarlo.
Uri whatsappUri(String text, {String? phone}) => Uri.https(
  'wa.me',
  '/${phone?.replaceAll(RegExp(r'\D'), '') ?? ''}',
  {'text': text},
);
