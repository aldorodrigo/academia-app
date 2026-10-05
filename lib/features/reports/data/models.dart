/// Links firmados para descargar un informe.
class ReportLinks {
  const ReportLinks({this.pdf, this.xlsx});

  factory ReportLinks.fromJson(Map<String, dynamic> json) => ReportLinks(
    pdf: json['pdf_url'] as String?,
    xlsx: json['xlsx_url'] as String?,
  );

  final String? pdf;
  final String? xlsx;
}

class ReportLine {
  const ReportLine({required this.label, required this.amount});

  factory ReportLine.fromJson(Map<String, dynamic> json) =>
      ReportLine(label: json['label'] as String, amount: json['amount'] as int);

  final String label;
  final int amount;
}

class AccountBalance {
  const AccountBalance({required this.name, required this.balance});

  factory AccountBalance.fromJson(Map<String, dynamic> json) => AccountBalance(
    name: json['name'] as String,
    balance: json['balance'] as int,
  );

  final String name;
  final int balance;
}

/// Balance de un período: ingresos, gastos y saldos de las cuentas.
class BalanceReport {
  const BalanceReport({
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.closingBalance,
    required this.incomeTotal,
    required this.income,
    required this.expensesTotal,
    required this.expenses,
    required this.accounts,
    required this.pendingExpenses,
    required this.links,
    this.other = 0,
  });

  factory BalanceReport.fromJson(Map<String, dynamic> json) {
    final income = json['income'] as Map<String, dynamic>;
    final expenses = json['expenses'] as Map<String, dynamic>;
    return BalanceReport(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
      openingBalance: json['opening_balance'] as int,
      closingBalance: json['closing_balance'] as int,
      incomeTotal: income['total'] as int,
      income: _lines(income['lines']),
      expensesTotal: expenses['total'] as int,
      expenses: _lines(expenses['lines']),
      accounts: ((json['accounts'] as List?) ?? const [])
          .map((a) => AccountBalance.fromJson(a as Map<String, dynamic>))
          .toList(),
      pendingExpenses: json['pending_expenses'] as int? ?? 0,
      other: json['other'] as int? ?? 0,
      links: ReportLinks.fromJson(json),
    );
  }

  final DateTime from;
  final DateTime to;
  final int openingBalance;
  final int closingBalance;
  final int incomeTotal;
  final List<ReportLine> income;
  final int expensesTotal;
  final List<ReportLine> expenses;
  final List<AccountBalance> accounts;
  final int pendingExpenses;
  final ReportLinks links;

  /// Saldos iniciales y ajustes (ni ingreso ni gasto): inicial + ingresos − gastos + otros = final.
  final int other;

  /// Ingresos menos gastos del período.
  int get result => incomeTotal - expensesTotal;
}

/// Hijo de la familia dado de baja (ninguna inscripción vigente sin baja).
class Withdrawal {
  const Withdrawal({required this.studentId, required this.student, this.on});

  factory Withdrawal.fromJson(Map<String, dynamic> json) => Withdrawal(
    studentId: json['student_id'] as int,
    student: json['student'] as String,
    on: json['on'] == null ? null : DateTime.parse(json['on'] as String),
  );

  final int studentId;

  /// Nombre de pila.
  final String student;
  final DateTime? on;
}

List<Withdrawal> _withdrawals(Object? value) => ((value as List?) ?? const [])
    .map((w) => Withdrawal.fromJson(w as Map<String, dynamic>))
    .toList();

/// Filtro de Morosos por bajas (`withdrawn` de la API).
enum WithdrawnFilter {
  all(null, 'Todos'),
  exclude('exclude', 'Siguen'),
  only('only', 'Dados de baja');

  const WithdrawnFilter(this.value, this.label);

  final String? value;
  final String label;
}

class FamilyBalance {
  const FamilyBalance({
    required this.family,
    required this.students,
    required this.pending,
    required this.overdue,
    required this.credit,
    this.upcoming = 0,
    this.withdrawn = const [],
  });

  factory FamilyBalance.fromJson(Map<String, dynamic> json) => FamilyBalance(
    family: json['family'] as String,
    students: List<String>.from(json['students'] as List? ?? const []),
    pending: json['pending'] as int,
    overdue: json['overdue'] as int,
    credit: json['credit'] as int? ?? 0,
    upcoming: json['upcoming'] as int? ?? 0,
    withdrawn: _withdrawals(json['withdrawn']),
  );

  final String family;
  final List<String> students;

  /// Hijos dados de baja: la deuda queda como histórica.
  final List<Withdrawal> withdrawn;

  /// Pendiente sin las próximas cuotas.
  final int pending;
  final int overdue;
  final int credit;

  /// Cuotas creadas por adelantado que todavía no empezaron.
  final int upcoming;
}

/// Saldos por familia.
class BalancesReport {
  const BalancesReport({
    required this.pending,
    required this.overdue,
    required this.credit,
    required this.families,
    required this.links,
    this.upcoming = 0,
  });

  factory BalancesReport.fromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>;
    return BalancesReport(
      pending: totals['pending'] as int,
      overdue: totals['overdue'] as int,
      credit: totals['credit'] as int? ?? 0,
      upcoming: totals['upcoming'] as int? ?? 0,
      families: ((json['families'] as List?) ?? const [])
          .map((f) => FamilyBalance.fromJson(f as Map<String, dynamic>))
          .toList(),
      links: ReportLinks.fromJson(json),
    );
  }

  final int pending;
  final int overdue;
  final int credit;
  final int upcoming;
  final List<FamilyBalance> families;
  final ReportLinks links;
}

class Delinquent {
  const Delinquent({
    required this.family,
    required this.students,
    required this.overdue,
    required this.oldestDueOn,
    required this.monthsOverdue,
    this.contactName,
    this.contactPhone,
    this.withdrawn = const [],
  });

  factory Delinquent.fromJson(Map<String, dynamic> json) {
    final contact = json['contact'] as Map<String, dynamic>?;
    return Delinquent(
      family: json['family'] as String,
      students: List<String>.from(json['students'] as List? ?? const []),
      overdue: json['overdue'] as int,
      oldestDueOn: DateTime.parse(json['oldest_due_on'] as String),
      monthsOverdue: json['months_overdue'] as int,
      contactName: contact?['name'] as String?,
      contactPhone: contact?['phone'] as String?,
      withdrawn: _withdrawals(json['withdrawn']),
    );
  }

  final String family;
  final List<String> students;
  final int overdue;
  final DateTime oldestDueOn;
  final int monthsOverdue;
  final String? contactName;
  final String? contactPhone;

  /// Hijos dados de baja: la deuda queda como histórica.
  final List<Withdrawal> withdrawn;
}

/// Morosos: familias con cuotas vencidas.
class DelinquentsReport {
  const DelinquentsReport({
    required this.total,
    required this.families,
    required this.links,
  });

  factory DelinquentsReport.fromJson(Map<String, dynamic> json) =>
      DelinquentsReport(
        total: json['total'] as int,
        families: ((json['families'] as List?) ?? const [])
            .map((f) => Delinquent.fromJson(f as Map<String, dynamic>))
            .toList(),
        links: ReportLinks.fromJson(json),
      );

  final int total;
  final List<Delinquent> families;
  final ReportLinks links;
}

List<ReportLine> _lines(Object? value) => ((value as List?) ?? const [])
    .map((l) => ReportLine.fromJson(l as Map<String, dynamic>))
    .toList();
