import '../../students/data/models.dart';

/// Marca de asistencia de un alumno en una clase.
enum AttendanceStatus {
  present('presente', 'Presente'),
  absent('ausente', 'Ausente'),
  justified('justificado', 'Justificado');

  const AttendanceStatus(this.value, this.label);

  final String value;
  final String label;

  /// Null si no se tomó o si el valor es desconocido.
  static AttendanceStatus? parse(Object? value) {
    for (final status in values) {
      if (status.value == value) return status;
    }
    return null;
  }
}

/// Respuesta del tutor a "¿Lo llevás?".
enum GuardianResponse {
  going('va'),
  notGoing('no_va');

  const GuardianResponse(this.value);

  final String value;

  static GuardianResponse? parse(Object? value) {
    for (final response in values) {
      if (response.value == value) return response;
    }
    return null;
  }
}

/// Contadores de la clase: inscriptos, respuestas de los tutores y asistencia.
class ClassCounts {
  const ClassCounts({
    this.enrolled = 0,
    this.going = 0,
    this.notGoing = 0,
    this.noAnswer = 0,
    this.present = 0,
    this.absent = 0,
    this.justified = 0,
  });

  factory ClassCounts.fromJson(Map<String, dynamic>? json) => ClassCounts(
    enrolled: json?['enrolled'] as int? ?? 0,
    going: json?['going'] as int? ?? 0,
    notGoing: json?['not_going'] as int? ?? 0,
    noAnswer: json?['no_answer'] as int? ?? 0,
    present: json?['present'] as int? ?? 0,
    absent: json?['absent'] as int? ?? 0,
    justified: json?['justified'] as int? ?? 0,
  );

  final int enrolled;
  final int going;
  final int notGoing;
  final int noAnswer;
  final int present;
  final int absent;
  final int justified;
}

/// Alumno en la lista de una clase, con su marca y la respuesta del tutor.
class ClassStudent {
  const ClassStudent({
    required this.id,
    required this.fullName,
    this.photoUrl,
    this.status,
    this.guardianResponse,
    this.note,
  });

  factory ClassStudent.fromJson(Map<String, dynamic> json) => ClassStudent(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    photoUrl: json['photo_url'] as String?,
    status: AttendanceStatus.parse(json['status']),
    guardianResponse: GuardianResponse.parse(json['guardian_response']),
    note: json['note'] as String?,
  );

  final int id;
  final String fullName;
  final String? photoUrl;
  final AttendanceStatus? status;
  final GuardianResponse? guardianResponse;
  final String? note;

  String get initials => _initials(fullName);
}

/// Un día concreto de un horario del grupo.
class ClassSession {
  const ClassSession({
    required this.id,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.group,
    this.venue,
    this.suspended = false,
    this.suspensionReason,
    this.attendanceTaken = false,
    this.counts = const ClassCounts(),
    this.editable = false,
    this.students = const [],
  });

  factory ClassSession.fromJson(Map<String, dynamic> json) => ClassSession(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    startsAt: json['starts_at'] as String,
    endsAt: json['ends_at'] as String? ?? '',
    venue: (json['venue'] as Map<String, dynamic>?)?['name'] as String?,
    group: Group.fromJson(json['group'] as Map<String, dynamic>),
    suspended: json['status'] == 'suspendida',
    suspensionReason: json['suspension_reason'] as String?,
    attendanceTaken: json['attendance_taken'] as bool? ?? false,
    counts: ClassCounts.fromJson(json['counts'] as Map<String, dynamic>?),
    editable: json['editable'] as bool? ?? false,
    students: _list(json['students'], ClassStudent.fromJson),
  );

  final int id;
  final DateTime date;
  final String startsAt;
  final String endsAt;
  final String? venue;
  final Group group;
  final bool suspended;
  final String? suspensionReason;
  final bool attendanceTaken;
  final ClassCounts counts;

  /// Solo en el detalle (`GET classes/{id}`).
  final bool editable;
  final List<ClassStudent> students;

  /// Fecha y hora de inicio (hora local de la organización).
  DateTime get startsAtDateTime => _at(date, startsAt);

  bool hasStarted(DateTime now) => !now.isBefore(startsAtDateTime);

  /// "17:00–18:30 · Cancha 1".
  String get timeDescription {
    final time = endsAt.isEmpty ? startsAt : '$startsAt–$endsAt';
    return venue == null ? time : '$time · $venue';
  }
}

/// Próxima clase de un alumno a cargo, con la respuesta del tutor.
class AgendaItem {
  const AgendaItem({
    required this.studentId,
    required this.studentFirstName,
    required this.session,
    this.response,
    this.canRespond = false,
    this.classReminders,
  });

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return AgendaItem(
      studentId: student['id'] as int,
      studentFirstName: student['first_name'] as String,
      session: ClassSession.fromJson(json['class'] as Map<String, dynamic>),
      response: GuardianResponse.parse(json['response']),
      canRespond: json['can_respond'] as bool? ?? false,
      classReminders: json['class_reminders'] as bool?,
    );
  }

  final int studentId;
  final String studentFirstName;
  final ClassSession session;
  final GuardianResponse? response;
  final bool canRespond;

  /// Null = nunca respondió si quiere el aviso de los días de clase.
  final bool? classReminders;
}

/// Clase en el historial de un alumno.
class AttendanceEntry {
  const AttendanceEntry({required this.session, this.status});

  factory AttendanceEntry.fromJson(Map<String, dynamic> json) =>
      AttendanceEntry(
        session: ClassSession.fromJson(json),
        status: AttendanceStatus.parse(json['attendance']),
      );

  final ClassSession session;
  final AttendanceStatus? status;
}

/// Asistencia de un alumno en un mes.
class StudentAttendance {
  const StudentAttendance({
    required this.month,
    this.present = 0,
    this.absent = 0,
    this.justified = 0,
    this.rate,
    this.classes = const [],
  });

  factory StudentAttendance.fromJson(Map<String, dynamic> json) =>
      StudentAttendance(
        month: json['month'] as String,
        present: json['present'] as int? ?? 0,
        absent: json['absent'] as int? ?? 0,
        justified: json['justified'] as int? ?? 0,
        rate: json['rate'] as int?,
        classes: _list(json['classes'], AttendanceEntry.fromJson),
      );

  final String month;
  final int present;
  final int absent;
  final int justified;

  /// % de presentes sobre las clases tomadas; null si no hay ninguna.
  final int? rate;
  final List<AttendanceEntry> classes;
}

/// Grupo del técnico (`GET groups`).
class InstructorGroup {
  const InstructorGroup({required this.group, this.studentsCount = 0});

  factory InstructorGroup.fromJson(Map<String, dynamic> json) =>
      InstructorGroup(
        group: Group.fromJson(json),
        studentsCount: json['students_count'] as int? ?? 0,
      );

  final Group group;
  final int studentsCount;
}

/// Resumen de un alumno en el mes del grupo.
class StudentAttendanceSummary {
  const StudentAttendanceSummary({
    required this.id,
    required this.fullName,
    this.photoUrl,
    this.present = 0,
    this.absent = 0,
    this.justified = 0,
    this.rate,
  });

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) =>
      StudentAttendanceSummary(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        photoUrl: json['photo_url'] as String?,
        present: json['present'] as int? ?? 0,
        absent: json['absent'] as int? ?? 0,
        justified: json['justified'] as int? ?? 0,
        rate: json['rate'] as int?,
      );

  final int id;
  final String fullName;
  final String? photoUrl;
  final int present;
  final int absent;
  final int justified;
  final int? rate;

  String get initials => _initials(fullName);
}

/// Grupo con las clases del mes y la asistencia por alumno.
class GroupAttendance {
  const GroupAttendance({
    required this.group,
    required this.month,
    this.classes = const [],
    this.students = const [],
  });

  factory GroupAttendance.fromJson(Map<String, dynamic> json) =>
      GroupAttendance(
        group: Group.fromJson(json),
        month: json['month'] as String,
        classes: _list(json['classes'], ClassSession.fromJson),
        students: _list(json['students'], StudentAttendanceSummary.fromJson),
      );

  final Group group;
  final String month;
  final List<ClassSession> classes;
  final List<StudentAttendanceSummary> students;
}

DateTime _at(DateTime date, String time) {
  final parts = time.split(':');
  return DateTime(
    date.year,
    date.month,
    date.day,
    int.tryParse(parts.first) ?? 0,
    parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _initials(String fullName) => fullName
    .split(' ')
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p[0])
    .join()
    .toUpperCase();

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    ((value as List?) ?? const [])
        .map((e) => parse(e as Map<String, dynamic>))
        .toList();
