/// Estado de un cargo, calculado por la API.
enum ChargeStatus {
  pending('pendiente', 'Pendiente'),
  overdue('vencido', 'Vencido'),
  paid('pagado', 'Pagado'),
  voided('anulado', 'Anulado');

  const ChargeStatus(this.value, this.label);

  final String value;
  final String label;

  /// Un valor desconocido se trata como pendiente en lugar de romper.
  static ChargeStatus parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => ChargeStatus.pending,
  );

  /// Pendiente o vencido: todavía hay que pagarlo.
  bool get isUnpaid =>
      this == ChargeStatus.pending || this == ChargeStatus.overdue;
}

/// Descuento, beca o recargo aplicado a un cargo (monto con signo).
class ChargeAdjustment {
  const ChargeAdjustment({
    required this.type,
    required this.label,
    required this.amount,
  });

  factory ChargeAdjustment.fromJson(Map<String, dynamic> json) =>
      ChargeAdjustment(
        type: json['type'] as String,
        label: json['label'] as String,
        amount: json['amount'] as int,
      );

  final String type;
  final String label;
  final int amount;
}

class Charge {
  const Charge({
    required this.id,
    required this.studentId,
    required this.studentFirstName,
    required this.concept,
    required this.description,
    required this.dueOn,
    required this.status,
    required this.baseAmount,
    required this.finalAmount,
    this.period,
    this.group,
    this.issuedOn,
    this.adjustments = const [],
  });

  factory Charge.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    return Charge(
      id: json['id'] as int,
      studentId: student['id'] as int,
      studentFirstName: student['first_name'] as String,
      concept: json['concept'] as String,
      description: json['description'] as String,
      period: json['period'] as String?,
      group: json['group'] as String?,
      issuedOn: _date(json['issued_on']),
      dueOn: _date(json['due_on'])!,
      status: ChargeStatus.parse(json['status']),
      baseAmount: json['base_amount'] as int,
      finalAmount: json['final_amount'] as int,
      adjustments: ((json['adjustments'] as List?) ?? const [])
          .map((a) => ChargeAdjustment.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final int studentId;
  final String studentFirstName;
  final String concept;
  final String description;

  /// "2026-09" en los cargos mensuales; null en inscripción, torneo…
  final String? period;
  final String? group;
  final DateTime? issuedOn;
  final DateTime dueOn;
  final ChargeStatus status;
  final int baseAmount;
  final int finalAmount;
  final List<ChargeAdjustment> adjustments;

  bool get hasAdjustments => adjustments.isNotEmpty;
}

/// Saldo de un hijo dentro del consolidado.
class StudentBalance {
  const StudentBalance({
    required this.id,
    required this.fullName,
    required this.balance,
    required this.overdue,
  });

  factory StudentBalance.fromJson(Map<String, dynamic> json) => StudentBalance(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    balance: json['balance'] as int,
    overdue: json['overdue'] as int,
  );

  final int id;
  final String fullName;
  final int balance;
  final int overdue;
}

/// Estado de cuenta: consolidado de la familia o de un solo hijo.
class Account {
  const Account({
    required this.balance,
    required this.overdue,
    required this.students,
    required this.charges,
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    balance: json['balance'] as int,
    overdue: json['overdue'] as int,
    students: ((json['students'] as List?) ?? const [])
        .map((s) => StudentBalance.fromJson(s as Map<String, dynamic>))
        .toList(),
    charges: ((json['charges'] as List?) ?? const [])
        .map((c) => Charge.fromJson(c as Map<String, dynamic>))
        .toList(),
  );

  static const empty = Account(
    balance: 0,
    overdue: 0,
    students: [],
    charges: [],
  );

  final int balance;
  final int overdue;
  final List<StudentBalance> students;
  final List<Charge> charges;

  List<Charge> get unpaid => charges.where((c) => c.status.isUnpaid).toList();
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;
