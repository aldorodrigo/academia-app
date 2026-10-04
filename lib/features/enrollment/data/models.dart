/// Solicitudes de inscripción (`API_V1.md`, «Inscripción desde la app»).
library;

/// Estado de una solicitud de inscripción.
enum EnrollmentRequestStatus {
  pending('pendiente', 'En revisión'),
  approved('aprobada', 'Aprobada'),
  rejected('rechazada', 'No aprobada'),
  cancelled('cancelada', 'Cancelada');

  const EnrollmentRequestStatus(this.value, this.label);

  final String value;
  final String label;

  /// Un valor desconocido se trata como en revisión en lugar de romper.
  static EnrollmentRequestStatus parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => EnrollmentRequestStatus.pending,
  );
}

/// Parentesco con el chico, como lo guarda la API.
enum Relationship {
  mother('madre', 'Madre'),
  father('padre', 'Padre'),
  guardian('tutor', 'Tutor/a'),
  grandparent('abuelo', 'Abuelo/a'),
  other('otro', 'Otro');

  const Relationship(this.value, this.label);

  final String value;
  final String label;

  static Relationship parse(Object? value) => values.firstWhere(
    (r) => r.value == value,
    orElse: () => Relationship.guardian,
  );
}

class NamedRef {
  const NamedRef(this.id, this.name);

  factory NamedRef.fromJson(Map<String, dynamic> json) =>
      NamedRef(json['id'] as int, json['name'] as String);

  final int id;
  final String name;
}

/// Temporada con sus fechas: una próxima se muestra "Empieza el …".
class SeasonRef {
  const SeasonRef({
    required this.id,
    required this.name,
    this.startsOn,
    this.endsOn,
  });

  factory SeasonRef.fromJson(Map<String, dynamic> json) => SeasonRef(
    id: json['id'] as int,
    name: json['name'] as String,
    startsOn: _date(json['starts_on']),
    endsOn: _date(json['ends_on']),
  );

  final int id;
  final String name;
  final DateTime? startsOn;
  final DateTime? endsOn;

  bool startsAfter(DateTime today) =>
      startsOn != null && startsOn!.isAfter(today);
}

class GroupSchedule {
  const GroupSchedule(this.weekday, this.startsAt);

  factory GroupSchedule.fromJson(Map<String, dynamic> json) =>
      GroupSchedule(json['weekday'] as int, json['starts_at'] as String);

  final int weekday;
  final String startsAt;
}

/// Categoría donde se puede pedir lugar, con su cupo.
class GroupOption {
  const GroupOption({
    required this.id,
    required this.name,
    this.capacity,
    this.spotsLeft,
    this.full = false,
    this.suggested = false,
    this.schedules = const [],
  });

  factory GroupOption.fromJson(Map<String, dynamic> json) => GroupOption(
    id: json['id'] as int,
    name: json['name'] as String,
    capacity: json['capacity'] as int?,
    spotsLeft: json['spots_left'] as int?,
    full: json['full'] as bool? ?? false,
    suggested: json['suggested'] as bool? ?? false,
    schedules: ((json['schedules'] as List?) ?? const [])
        .map((s) => GroupSchedule.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String name;

  /// `null` = sin cupo.
  final int? capacity;
  final int? spotsLeft;
  final bool full;

  /// La que corresponde por edad (solo en la lista de quien aprueba).
  final bool suggested;
  final List<GroupSchedule> schedules;

  /// "Completo", "Queda 1 lugar", "Quedan 3 lugares" o `null` sin cupo.
  String? get spotsLabel {
    if (full) return 'Completo';
    final left = spotsLeft;
    if (left == null) return null;
    return left == 1 ? 'Queda 1 lugar' : 'Quedan $left lugares';
  }
}

/// Una disciplina en una temporada, con sus categorías y la sugerida por edad.
class EnrollmentOption {
  const EnrollmentOption({
    required this.program,
    required this.season,
    required this.groups,
    this.suggestedGroupId,
  });

  factory EnrollmentOption.fromJson(Map<String, dynamic> json) =>
      EnrollmentOption(
        program: NamedRef.fromJson(json['program'] as Map<String, dynamic>),
        season: SeasonRef.fromJson(json['season'] as Map<String, dynamic>),
        suggestedGroupId: json['suggested_group_id'] as int?,
        groups: ((json['groups'] as List?) ?? const [])
            .map((g) => GroupOption.fromJson(g as Map<String, dynamic>))
            .toList(),
      );

  final NamedRef program;
  final SeasonRef season;
  final int? suggestedGroupId;
  final List<GroupOption> groups;

  /// La categoría que se elige sola: la sugerida, o la única que hay.
  int? get defaultGroupId {
    if (groups.any((g) => g.id == suggestedGroupId)) return suggestedGroupId;
    return groups.length == 1 ? groups.single.id : null;
  }
}

/// El chico tal como lo cargó el tutor.
class ChildData {
  const ChildData({
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    this.document,
  });

  factory ChildData.fromJson(Map<String, dynamic> json) => ChildData(
    firstName: json['first_name'] as String,
    lastName: json['last_name'] as String,
    birthDate: DateTime.parse(json['birth_date'] as String),
    document: json['document'] as String?,
  );

  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String? document;

  String get fullName => '$firstName $lastName';
}

/// El chico ya está cargado en el club: aprobar lo reutiliza.
class ExistingStudent {
  const ExistingStudent({
    required this.id,
    required this.fullName,
    this.guardians = const [],
  });

  factory ExistingStudent.fromJson(Map<String, dynamic> json) =>
      ExistingStudent(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        guardians: List<String>.from(json['guardians'] as List? ?? const []),
      );

  final int id;
  final String fullName;
  final List<String> guardians;
}

class MidPeriodChoice {
  const MidPeriodChoice(this.value, this.label);

  factory MidPeriodChoice.fromJson(Map<String, dynamic> json) =>
      MidPeriodChoice(json['value'] as String, json['label'] as String);

  final String value;
  final String label;
}

/// Qué se cobra del mes (quincena, semana) en curso, si ya empezó.
class MidPeriod {
  const MidPeriod({
    required this.label,
    required this.options,
    this.defaultValue,
  });

  factory MidPeriod.fromJson(Map<String, dynamic> json) => MidPeriod(
    label: json['label'] as String,
    defaultValue: json['default'] as String?,
    options: ((json['options'] as List?) ?? const [])
        .map((o) => MidPeriodChoice.fromJson(o as Map<String, dynamic>))
        .toList(),
  );

  final String label;
  final String? defaultValue;
  final List<MidPeriodChoice> options;
}

/// Quién pidió la inscripción (solo para quien aprueba).
class Requester {
  const Requester({required this.name, this.phone, this.email});

  factory Requester.fromJson(Map<String, dynamic> json) => Requester(
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
  );

  final String name;
  final String? phone;
  final String? email;

  String? get contact => phone ?? email;
}

/// Solicitud de inscripción de un hijo.
class EnrollmentRequest {
  const EnrollmentRequest({
    required this.id,
    required this.status,
    required this.child,
    required this.season,
    required this.group,
    required this.program,
    this.relationship = Relationship.guardian,
    this.hasMedical = false,
    this.notes,
    this.rejectionReason,
    this.studentId,
    this.createdAt,
    this.reviewedAt,
    this.requestedBy,
    this.age,
    this.existingStudent,
    this.groupOptions = const [],
    this.midPeriod,
  });

  factory EnrollmentRequest.fromJson(Map<String, dynamic> json) {
    final group = json['group'] as Map<String, dynamic>;
    final requester = json['requested_by'] as Map<String, dynamic>?;
    final existing = json['existing_student'] as Map<String, dynamic>?;
    final midPeriod = json['mid_period'] as Map<String, dynamic>?;
    return EnrollmentRequest(
      id: json['id'] as int,
      status: EnrollmentRequestStatus.parse(json['status']),
      child: ChildData.fromJson(json['child'] as Map<String, dynamic>),
      relationship: Relationship.parse(json['relationship']),
      hasMedical: json['has_medical'] as bool? ?? false,
      notes: json['notes'] as String?,
      season: SeasonRef.fromJson(json['season'] as Map<String, dynamic>),
      group: NamedRef.fromJson(group),
      program: NamedRef.fromJson(group['program'] as Map<String, dynamic>),
      rejectionReason: json['rejection_reason'] as String?,
      studentId: json['student_id'] as int?,
      createdAt: _dateTime(json['created_at']),
      reviewedAt: _dateTime(json['reviewed_at']),
      requestedBy: requester == null ? null : Requester.fromJson(requester),
      age: json['age'] as int?,
      existingStudent: existing == null
          ? null
          : ExistingStudent.fromJson(existing),
      groupOptions: ((json['group_options'] as List?) ?? const [])
          .map((g) => GroupOption.fromJson(g as Map<String, dynamic>))
          .toList(),
      midPeriod: midPeriod == null ? null : MidPeriod.fromJson(midPeriod),
    );
  }

  final int id;
  final EnrollmentRequestStatus status;
  final ChildData child;
  final Relationship relationship;
  final bool hasMedical;
  final String? notes;
  final SeasonRef season;
  final NamedRef group;
  final NamedRef program;
  final String? rejectionReason;

  /// El alumno dado de alta al aprobarla.
  final int? studentId;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  // Solo para quien aprueba.
  final Requester? requestedBy;
  final int? age;
  final ExistingStudent? existingStudent;
  final List<GroupOption> groupOptions;
  final MidPeriod? midPeriod;

  bool get isPending => status == EnrollmentRequestStatus.pending;

  /// "Sub-8 · Fútbol (2026)".
  String get placeLabel => '${group.name} · ${program.name} (${season.name})';

  GroupOption? groupOption(int id) {
    for (final option in groupOptions) {
      if (option.id == id) return option;
    }
    return null;
  }
}

/// Ficha médica opcional que el tutor carga con la solicitud.
class MedicalDraft {
  const MedicalDraft({
    this.bloodType,
    this.allergies,
    this.conditions,
    this.medications,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String? bloodType;
  final String? allergies;
  final String? conditions;
  final String? medications;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  Map<String, String> toJson() => {
    for (final entry in {
      'blood_type': bloodType,
      'allergies': allergies,
      'conditions': conditions,
      'medications': medications,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
    }.entries)
      if (entry.value?.trim().isNotEmpty ?? false)
        entry.key: entry.value!.trim(),
  };

  bool get isEmpty => toJson().isEmpty;
}

/// Lo que el tutor completa para pedir la inscripción.
class EnrollmentRequestDraft {
  const EnrollmentRequestDraft({
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.seasonId,
    required this.groupId,
    this.document,
    this.relationship = Relationship.guardian,
    this.notes,
    this.medical = const MedicalDraft(),
  });

  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final int seasonId;
  final int groupId;
  final String? document;
  final Relationship relationship;
  final String? notes;
  final MedicalDraft medical;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;
