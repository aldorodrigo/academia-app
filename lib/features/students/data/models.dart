import '../../../core/utils/format.dart';

/// Estado de la inscripción, como lo define la API.
enum EnrollmentStatus {
  pending('pendiente', 'Pendiente'),
  active('activo', 'Activo'),
  scholarship('becado', 'Becado'),
  suspended('suspendido', 'Suspendido'),
  withdrawn('baja', 'Baja');

  const EnrollmentStatus(this.value, this.label);

  final String value;
  final String label;

  /// Un valor desconocido se trata como pendiente en lugar de romper.
  static EnrollmentStatus parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => EnrollmentStatus.pending,
  );

  /// Activo o becado: el alumno está entrenando.
  bool get isCurrent =>
      this == EnrollmentStatus.active || this == EnrollmentStatus.scholarship;
}

class Program {
  const Program({required this.id, required this.name});

  factory Program.fromJson(Map<String, dynamic> json) =>
      Program(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

/// Horario semanal de un grupo.
class Schedule {
  const Schedule({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
    this.venue,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
    weekday: json['weekday'] as int,
    startsAt: json['starts_at'] as String,
    endsAt: json['ends_at'] as String,
    venue: (json['venue'] as Map<String, dynamic>?)?['name'] as String?,
  );

  /// ISO: 1 = lunes … 7 = domingo.
  final int weekday;
  final String startsAt;
  final String endsAt;
  final String? venue;

  /// "Lun 17:00–18:30 · Cancha 1".
  String get description {
    final time = '${weekdayShort(weekday)} $startsAt–$endsAt';
    return venue == null ? time : '$time · $venue';
  }
}

/// Grupo (ej. Sub-10). Horarios e instructores vienen solo en la ficha.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.program,
    this.schedules = const [],
    this.instructors = const [],
  });

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'] as int,
    name: json['name'] as String,
    program: Program.fromJson(json['program'] as Map<String, dynamic>),
    schedules: _list(json['schedules'], Schedule.fromJson)
      ..sort((a, b) => a.weekday.compareTo(b.weekday)),
    instructors: _list(json['instructors'], (i) => i['name'] as String),
  );

  final int id;
  final String name;
  final Program program;
  final List<Schedule> schedules;
  final List<String> instructors;
}

/// Inscripción = alumno + grupo + temporada.
class Enrollment {
  const Enrollment({
    required this.id,
    required this.status,
    required this.season,
    required this.group,
    this.seasonStartsOn,
    this.seasonEndsOn,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final season = json['season'] as Map<String, dynamic>;
    return Enrollment(
      id: json['id'] as int,
      status: EnrollmentStatus.parse(json['status']),
      season: season['name'] as String,
      seasonStartsOn: _date(season['starts_on']),
      seasonEndsOn: _date(season['ends_on']),
      group: Group.fromJson(json['group'] as Map<String, dynamic>),
    );
  }

  final int id;
  final EnrollmentStatus status;
  final String season;
  final DateTime? seasonStartsOn;
  final DateTime? seasonEndsOn;
  final Group group;

  /// La temporada todavía no empezó.
  bool isUpcoming(DateTime today) =>
      seasonStartsOn != null && seasonStartsOn!.isAfter(today);
}

class Guardian {
  const Guardian({required this.name, this.relationship, this.isMe = false});

  factory Guardian.fromJson(Map<String, dynamic> json) => Guardian(
    name: json['name'] as String,
    relationship: json['relationship'] as String?,
    isMe: json['is_me'] as bool? ?? false,
  );

  final String name;
  final String? relationship;
  final bool isMe;
}

class MedicalRecord {
  const MedicalRecord({
    this.bloodType,
    this.allergies,
    this.conditions,
    this.medications,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.fitUntil,
  });

  factory MedicalRecord.fromJson(Map<String, dynamic> json) {
    final contact = json['emergency_contact'] as Map<String, dynamic>?;
    return MedicalRecord(
      bloodType: json['blood_type'] as String?,
      allergies: json['allergies'] as String?,
      conditions: json['conditions'] as String?,
      medications: json['medications'] as String?,
      emergencyContactName: contact?['name'] as String?,
      emergencyContactPhone: contact?['phone'] as String?,
      fitUntil: _date(json['fit_until']),
    );
  }

  final String? bloodType;
  final String? allergies;
  final String? conditions;
  final String? medications;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  /// Vencimiento del apto médico.
  final DateTime? fitUntil;

  bool isFitExpired(DateTime today) =>
      fitUntil != null && fitUntil!.isBefore(today);
}

/// Alumno a cargo del usuario. La lista trae los datos básicos; la ficha
/// (`GET students/{id}`) agrega documento, tutores, horarios y ficha médica.
class Student {
  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.birthDate,
    required this.enrollments,
    this.photoUrl,
    this.isSelf = false,
    this.document,
    this.shirtSize,
    this.position,
    this.guardians = const [],
    this.medical,
    this.canViewMedical = false,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    final permissions = json['permissions'] as Map<String, dynamic>?;
    final medical = json['medical'] as Map<String, dynamic>?;
    return Student(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      fullName: json['full_name'] as String,
      birthDate: _date(json['birth_date']),
      photoUrl: json['photo_url'] as String?,
      isSelf: json['is_self'] as bool? ?? false,
      enrollments: _list(json['enrollments'], Enrollment.fromJson),
      document: json['document'] as String?,
      shirtSize: json['shirt_size'] as String?,
      position: json['position'] as String?,
      guardians: _list(json['guardians'], Guardian.fromJson),
      medical: medical == null ? null : MedicalRecord.fromJson(medical),
      canViewMedical: permissions?['view_medical'] as bool? ?? false,
    );
  }

  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final DateTime? birthDate;
  final String? photoUrl;

  /// Alumno adulto que es su propio responsable.
  final bool isSelf;
  final List<Enrollment> enrollments;
  final String? document;
  final String? shirtSize;
  final String? position;
  final List<Guardian> guardians;

  /// Null si el usuario no puede verla o si todavía no se cargó.
  final MedicalRecord? medical;
  final bool canViewMedical;

  String get initials =>
      '${firstName.isEmpty ? '' : firstName[0]}'
              '${lastName.isEmpty ? '' : lastName[0]}'
          .toUpperCase();

  int? age(DateTime today) =>
      birthDate == null ? null : ageOn(birthDate!, today);

  /// "Sub-10 · Fútbol, Inicial · Pádel".
  String get groupsDescription => enrollments
      .map((e) => '${e.group.name} · ${e.group.program.name}')
      .join(', ');
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    ((value as List?) ?? const [])
        .map((e) => parse(e as Map<String, dynamic>))
        .toList();
