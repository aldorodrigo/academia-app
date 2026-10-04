import '../../../core/utils/format.dart';
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
    this.enrollmentRequestId,
    this.canConfirm = false,
  });

  factory ClassStudent.fromJson(Map<String, dynamic> json) {
    final request = json['enrollment_request'] as Map<String, dynamic>?;
    return ClassStudent(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      photoUrl: json['photo_url'] as String?,
      status: AttendanceStatus.parse(json['status']),
      guardianResponse: GuardianResponse.parse(json['guardian_response']),
      note: json['note'] as String?,
      enrollmentRequestId: request?['id'] as int?,
      canConfirm: request?['can_review'] as bool? ?? false,
    );
  }

  final int id;
  final String fullName;
  final String? photoUrl;
  final AttendanceStatus? status;
  final GuardianResponse? guardianResponse;
  final String? note;

  /// Nuevo que pidió lugar desde la app: va a clases mientras el club confirma.
  final int? enrollmentRequestId;

  /// Quien toma la asistencia lo puede confirmar o rechazar acá mismo.
  final bool canConfirm;

  bool get isPendingConfirmation => enrollmentRequestId != null;

  String get initials => _initials(fullName);
}

/// Cancha del club.
class Venue {
  const Venue({required this.id, required this.name});

  factory Venue.fromJson(Map<String, dynamic> json) =>
      Venue(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

/// Otra clase enlazada (la recuperación o la original de una reprogramación).
class ClassSlot {
  const ClassSlot({
    required this.id,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    this.venue,
  });

  factory ClassSlot.fromJson(Map<String, dynamic> json) => ClassSlot(
    id: json['id'] as int,
    date: DateTime.parse(json['date'] as String),
    startsAt: json['starts_at'] as String,
    endsAt: json['ends_at'] as String? ?? '',
    venue: (json['venue'] as Map<String, dynamic>?)?['name'] as String?,
  );

  final int id;
  final DateTime date;
  final String startsAt;
  final String endsAt;
  final String? venue;

  /// "de ayer 17:00–18:30" o "del lun 28/9 17:00–18:30" (para "la clase …").
  String describeAfterClass(DateTime today) {
    final text = describe(today);
    final lower = '${text[0].toLowerCase()}${text.substring(1)}';
    final relative = formatDay(date, today);
    return relative.startsWith('el ') ? 'del $lower' : 'de $lower';
  }

  /// "Sáb 3/10 9:00–10:30 · Cancha 2" (con "Hoy"/"Mañana" cuando corresponde).
  String describe(DateTime today) {
    final time = endsAt.isEmpty ? startsAt : '$startsAt–$endsAt';
    final text = '${formatShortDay(date, today)} $time';
    return venue == null ? text : '$text · $venue';
  }
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
    this.rescheduled = false,
    this.suspensionReason,
    this.chargeWaived = false,
    this.canWaiveCharge = false,
    this.isMakeup = false,
    this.rescheduledTo,
    this.rescheduledFrom,
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
    rescheduled: json['status'] == 'reprogramada',
    suspensionReason: json['suspension_reason'] as String?,
    chargeWaived: json['charge_waived'] as bool? ?? false,
    canWaiveCharge: json['can_waive_charge'] as bool? ?? false,
    isMakeup: json['is_makeup'] as bool? ?? false,
    rescheduledTo: _slot(json['rescheduled_to']),
    rescheduledFrom: _slot(json['rescheduled_from']),
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

  /// Se pasó a otro día u horario ([rescheduledTo]).
  final bool rescheduled;
  final String? suspensionReason;

  /// Suspendida y sin cobrar (temporadas por día de entrenamiento).
  final bool chargeWaived;

  /// Se puede elegir "No cobrar esta clase" al suspenderla (solo en el detalle).
  final bool canWaiveCharge;

  /// Clase de recuperación de otra ([rescheduledFrom]).
  final bool isMakeup;
  final ClassSlot? rescheduledTo;
  final ClassSlot? rescheduledFrom;
  final bool attendanceTaken;
  final ClassCounts counts;

  /// Solo en el detalle (`GET classes/{id}`).
  final bool editable;
  final List<ClassStudent> students;

  /// Fecha y hora de inicio (hora local de la organización).
  DateTime get startsAtDateTime => _at(date, startsAt);

  bool hasStarted(DateTime now) => !now.isBefore(startsAtDateTime);

  /// La misma clase con otra lista de alumnos (y editable como estaba).
  ClassSession withStudents(List<ClassStudent> students) => ClassSession(
    id: id,
    date: date,
    startsAt: startsAt,
    endsAt: endsAt,
    group: group,
    venue: venue,
    suspended: suspended,
    rescheduled: rescheduled,
    suspensionReason: suspensionReason,
    chargeWaived: chargeWaived,
    canWaiveCharge: canWaiveCharge,
    isMakeup: isMakeup,
    rescheduledTo: rescheduledTo,
    rescheduledFrom: rescheduledFrom,
    attendanceTaken: attendanceTaken,
    counts: counts,
    editable: editable,
    students: students,
  );

  /// No se dicta en su día y hora: suspendida o reprogramada.
  bool get isOff => suspended || rescheduled;

  /// La clase es de un día anterior a [today].
  bool isPast(DateTime today) =>
      DateTime(date.year, date.month, date.day).isBefore(today);

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
    this.enrollmentRequestId,
    this.canConfirm = false,
  });

  factory StudentAttendanceSummary.fromJson(Map<String, dynamic> json) {
    final request = json['enrollment_request'] as Map<String, dynamic>?;
    return StudentAttendanceSummary(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      photoUrl: json['photo_url'] as String?,
      present: json['present'] as int? ?? 0,
      absent: json['absent'] as int? ?? 0,
      justified: json['justified'] as int? ?? 0,
      rate: json['rate'] as int?,
      enrollmentRequestId: request?['id'] as int?,
      canConfirm: request?['can_review'] as bool? ?? false,
    );
  }

  final int id;
  final String fullName;
  final String? photoUrl;
  final int present;
  final int absent;
  final int justified;
  final int? rate;

  /// Nuevo que pidió lugar desde la app y el club todavía no confirmó.
  final int? enrollmentRequestId;
  final bool canConfirm;

  bool get isPendingConfirmation => enrollmentRequestId != null;

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

ClassSlot? _slot(Object? json) =>
    json is Map<String, dynamic> ? ClassSlot.fromJson(json) : null;

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
