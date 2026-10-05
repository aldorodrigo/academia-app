import '../../billing/data/models.dart';
import '../../../core/vocabulary/vocabulary.dart';

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

/// Quién avisó la baja: el técnico ("dejó de venir") o el tutor ("deja el club").
enum DropoutSource {
  instructor('instructor'),
  guardian('guardian');

  const DropoutSource(this.value);

  final String value;

  static DropoutSource parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => DropoutSource.instructor,
  );
}

/// Aviso de baja todavía sin decidir.
class DropoutReport {
  const DropoutReport({
    required this.source,
    required this.reportedBy,
    required this.reportedOn,
    this.note,
    this.enrollmentId,
    this.studentId,
    this.studentName,
    this.group,
  });

  factory DropoutReport.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>?;
    return DropoutReport(
      source: DropoutSource.parse(json['source']),
      reportedBy: json['reported_by'] as String? ?? '',
      reportedOn: _date(json['reported_on'])!,
      note: json['note'] as String?,
      enrollmentId: json['enrollment_id'] as int?,
      studentId: student?['id'] as int?,
      studentName: student?['full_name'] as String?,
      group: json['group'] as String?,
    );
  }

  final DropoutSource source;
  final String reportedBy;
  final DateTime reportedOn;
  final String? note;

  /// Solo en la lista de avisos (`GET dropout-reports`).
  final int? enrollmentId;
  final int? studentId;
  final String? studentName;
  final String? group;

  /// "Carlos Gómez avisó que dejó de venir" / "Ana Benítez avisó que deja la academia".
  String summaryFor(Word organization) =>
      '$reportedBy avisó que ${source == DropoutSource.guardian ? 'deja ${organization.the()}' : 'dejó de venir'}';
}

/// Inscripción vista por quien da de baja.
class ManagedEnrollment {
  const ManagedEnrollment({
    required this.id,
    required this.group,
    required this.status,
    required this.statusLabel,
    this.program,
    this.season,
    this.endedOn,
    this.withdrawalReason,
    this.canWithdraw = false,
    this.dropoutReport,
  });

  factory ManagedEnrollment.fromJson(Map<String, dynamic> json) {
    final report = json['dropout_report'] as Map<String, dynamic>?;
    return ManagedEnrollment(
      id: json['id'] as int,
      group: json['group'] as String,
      program: json['program'] as String?,
      season: json['season'] as String?,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      endedOn: _date(json['ended_on']),
      withdrawalReason: json['withdrawal_reason'] as String?,
      canWithdraw: json['can_withdraw'] as bool? ?? false,
      dropoutReport: report == null ? null : DropoutReport.fromJson(report),
    );
  }

  final int id;
  final String group;
  final String? program;
  final String? season;
  final String status;
  final String statusLabel;
  final DateTime? endedOn;
  final String? withdrawalReason;
  final bool canWithdraw;
  final DropoutReport? dropoutReport;

  bool get isWithdrawn => status == 'baja';

  String get title => [?program, group, ?season].join(' · ');
}

/// Lo que se condonó de una cuota: cuánto, por qué, quién y cuándo.
class Waiver {
  const Waiver({
    required this.amount,
    required this.reason,
    required this.by,
    required this.on,
  });

  factory Waiver.fromJson(Map<String, dynamic> json) => Waiver(
    amount: json['amount'] as int,
    reason: json['reason'] as String? ?? '',
    by: json['by'] as String? ?? '',
    on: _date(json['on'])!,
  );

  final int amount;
  final String reason;
  final String by;
  final DateTime on;
}

/// Cuota en la ficha de quien condona.
class ManagedCharge {
  const ManagedCharge({
    required this.charge,
    this.waiver,
    this.canWaive = false,
    this.canUnwaive = false,
  });

  factory ManagedCharge.fromJson(Map<String, dynamic> json) {
    final waiver = json['waiver'] as Map<String, dynamic>?;
    return ManagedCharge(
      charge: Charge.fromJson(json),
      waiver: waiver == null ? null : Waiver.fromJson(waiver),
      canWaive: json['can_waive'] as bool? ?? false,
      canUnwaive: json['can_unwaive'] as bool? ?? false,
    );
  }

  final Charge charge;
  final Waiver? waiver;
  final bool canWaive;
  final bool canUnwaive;
}

/// Ficha del alumno para quien da de baja o condona (`GET staff/students/{id}`).
class ManagedStudent {
  const ManagedStudent({
    required this.id,
    required this.fullName,
    required this.firstName,
    this.enrollments = const [],
    this.noticeRecipients = 0,
    this.noticeMessage = '',
    this.charges,
    this.balance = 0,
  });

  factory ManagedStudent.fromJson(Map<String, dynamic> json) {
    final notice = json['notice'] as Map<String, dynamic>?;
    final charges = json['charges'] as List?;
    return ManagedStudent(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      firstName: json['first_name'] as String,
      enrollments: ((json['enrollments'] as List?) ?? const [])
          .map((e) => ManagedEnrollment.fromJson(e as Map<String, dynamic>))
          .toList(),
      noticeRecipients: notice?['recipients'] as int? ?? 0,
      noticeMessage: notice?['message'] as String? ?? '',
      charges: charges
          ?.map((c) => ManagedCharge.fromJson(c as Map<String, dynamic>))
          .toList(),
      balance: json['balance'] as int? ?? 0,
    );
  }

  final int id;
  final String fullName;
  final String firstName;
  final List<ManagedEnrollment> enrollments;

  /// Tutores con la app que reciben el aviso de baja.
  final int noticeRecipients;

  /// Mensaje sugerido para la familia (amable, con las puertas abiertas).
  final String noticeMessage;

  /// Solo con el permiso `waive_charges`.
  final List<ManagedCharge>? charges;
  final int balance;
}

/// Datos de una baja desde la app.
class WithdrawalDraft {
  const WithdrawalDraft({
    required this.endedOn,
    required this.reason,
    this.notify = false,
    this.message,
  });

  final DateTime endedOn;
  final String reason;
  final bool notify;
  final String? message;
}
