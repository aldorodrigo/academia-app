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
    int? paidAmount,
    int? pendingAmount,
    this.period,
    this.group,
    this.issuedOn,
    this.adjustments = const [],
    this.season,
    this.periodStart,
    this.periodEnd,
    this.quantity,
    this.unitAmount,
    this.isUpcoming = false,
  }) : paidAmount = paidAmount ?? 0,
       pendingAmount = pendingAmount ?? finalAmount;

  factory Charge.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final season = json['season'] as Map<String, dynamic>?;
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
      paidAmount: json['paid_amount'] as int?,
      pendingAmount: json['pending_amount'] as int?,
      adjustments: ((json['adjustments'] as List?) ?? const [])
          .map((a) => ChargeAdjustment.fromJson(a as Map<String, dynamic>))
          .toList(),
      season: season?['name'] as String?,
      periodStart: _date(json['period_start']),
      periodEnd: _date(json['period_end']),
      quantity: json['quantity'] as int?,
      unitAmount: json['unit_amount'] as int?,
      isUpcoming: json['is_upcoming'] as bool? ?? false,
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

  /// Lo cubierto por pagos (incluye el pronto pago). 0 si la API no lo manda.
  final int paidAmount;

  /// Lo que falta pagar. Si la API no lo manda, el monto final.
  final int pendingAmount;
  final List<ChargeAdjustment> adjustments;

  /// Temporada a la que corresponde la cuota; null en cargos manuales.
  final String? season;

  /// Período que cubre la cuota (mes, quincena, semana o día).
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Cobro por día agrupado: "5 entrenamientos × ₲ 20.000".
  final int? quantity;
  final int? unitAmount;

  /// Cuota creada por adelantado cuyo período todavía no empezó.
  final bool isUpcoming;

  bool get hasAdjustments => adjustments.isNotEmpty;

  /// Tiene pagos pero todavía falta.
  bool get isPartiallyPaid => paidAmount > 0 && pendingAmount > 0;
}

/// Parte de un pago aplicada a un cargo.
class PaymentAllocation {
  const PaymentAllocation({
    required this.chargeId,
    required this.description,
    required this.studentFirstName,
    required this.amount,
  });

  factory PaymentAllocation.fromJson(Map<String, dynamic> json) =>
      PaymentAllocation(
        chargeId: json['charge_id'] as int,
        description: json['description'] as String,
        studentFirstName: json['student_first_name'] as String,
        amount: json['amount'] as int,
      );

  final int chargeId;
  final String description;
  final String studentFirstName;
  final int amount;
}

/// Pago de la familia, con su recibo.
class Payment {
  const Payment({
    required this.id,
    required this.receiptNumber,
    required this.receivedOn,
    required this.amount,
    required this.methodLabel,
    this.voided = false,
    this.receiptUrl,
    this.allocations = const [],
    this.creditGenerated = 0,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as int,
    receiptNumber: json['receipt_number'] as String,
    receivedOn: DateTime.parse(json['received_on'] as String),
    amount: json['amount'] as int,
    methodLabel: json['method_label'] as String,
    voided: json['voided'] as bool? ?? false,
    receiptUrl: json['receipt_url'] as String?,
    allocations: ((json['allocations'] as List?) ?? const [])
        .map((a) => PaymentAllocation.fromJson(a as Map<String, dynamic>))
        .toList(),
    creditGenerated: json['credit_generated'] as int? ?? 0,
  );

  final int id;
  final String receiptNumber;
  final DateTime receivedOn;
  final int amount;
  final String methodLabel;
  final bool voided;

  /// Link firmado y temporal al PDF.
  final String? receiptUrl;
  final List<PaymentAllocation> allocations;

  /// Lo que dejó como saldo a favor.
  final int creditGenerated;
}

/// Saldo de un hijo dentro del consolidado.
class StudentBalance {
  const StudentBalance({
    required this.id,
    required this.fullName,
    required this.balance,
    required this.overdue,
    int? dueNow,
    this.upcoming = 0,
  }) : dueNow = dueNow ?? balance;

  factory StudentBalance.fromJson(Map<String, dynamic> json) => StudentBalance(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
    balance: json['balance'] as int,
    overdue: json['overdue'] as int,
    dueNow: json['due_now'] as int?,
    upcoming: json['upcoming'] as int? ?? 0,
  );

  final int id;
  final String fullName;
  final int balance;
  final int overdue;

  /// A pagar ahora (sin las próximas cuotas).
  final int dueNow;
  final int upcoming;
}

/// Estado de cuenta: consolidado de la familia o de un solo hijo.
class Account {
  const Account({
    required this.balance,
    required this.overdue,
    required this.students,
    required this.charges,
    this.credit = 0,
    this.payments = const [],
    int? dueNow,
    this.upcoming = 0,
  }) : dueNow = dueNow ?? balance;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    balance: json['balance'] as int,
    overdue: json['overdue'] as int,
    dueNow: json['due_now'] as int?,
    upcoming: json['upcoming'] as int? ?? 0,
    credit: json['credit'] as int? ?? 0,
    payments: ((json['payments'] as List?) ?? const [])
        .map((p) => Payment.fromJson(p as Map<String, dynamic>))
        .toList(),
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

  /// Total: a pagar ahora más las próximas cuotas.
  final int balance;
  final int overdue;

  /// Lo que hay que pagar ahora (vencido y período en curso, menos el saldo a favor).
  final int dueNow;

  /// Cuotas creadas por adelantado que todavía no empezaron.
  final int upcoming;
  final List<StudentBalance> students;
  final List<Charge> charges;

  /// Saldo a favor de la familia.
  final int credit;
  final List<Payment> payments;

  List<Charge> get unpaid => charges.where((c) => c.status.isUnpaid).toList();

  /// Impagos a pagar ahora, sin las próximas cuotas.
  List<Charge> get dueCharges =>
      charges.where((c) => c.status.isUnpaid && !c.isUpcoming).toList();

  /// Próximas cuotas, de la más cercana a la más lejana.
  List<Charge> get upcomingCharges =>
      charges.where((c) => c.status.isUnpaid && c.isUpcoming).toList()
        ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.parse(value) : null;
