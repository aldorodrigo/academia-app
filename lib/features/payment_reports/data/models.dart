/// Estado de un comprobante de transferencia informado por el tutor.
enum PaymentReportStatus {
  pending('pendiente', 'En revisión'),
  approved('aprobado', 'Aprobado'),
  rejected('rechazado', 'Rechazado');

  const PaymentReportStatus(this.value, this.label);

  final String value;
  final String label;

  /// Un valor desconocido se trata como en revisión en lugar de romper.
  static PaymentReportStatus parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => PaymentReportStatus.pending,
  );
}

/// Cuenta bancaria o billetera con los datos para transferir.
class TransferAccount {
  const TransferAccount({required this.id, required this.name, this.details});

  factory TransferAccount.fromJson(Map<String, dynamic> json) =>
      TransferAccount(
        id: json['id'] as int,
        name: json['name'] as String,
        details: json['details'] as String?,
      );

  final int id;
  final String name;

  /// "Cuenta corriente 123456\nTitular: Club Jakare…" (null en las cuentas
  /// donde solo valida el tesorero).
  final String? details;
}

/// Cuota que el tutor eligió pagar con el comprobante.
class ReportedCharge {
  const ReportedCharge({
    required this.id,
    required this.description,
    required this.studentFirstName,
    required this.pendingAmount,
  });

  factory ReportedCharge.fromJson(Map<String, dynamic> json) => ReportedCharge(
    id: json['id'] as int,
    description: json['description'] as String,
    studentFirstName: json['student_first_name'] as String,
    pendingAmount: json['pending_amount'] as int? ?? 0,
  );

  final int id;
  final String description;
  final String studentFirstName;

  /// Lo que falta pagar hoy de esa cuota.
  final int pendingAmount;
}

/// Familia del comprobante (solo para quien valida).
class ReportFamily {
  const ReportFamily({
    required this.id,
    required this.name,
    this.students = const [],
  });

  factory ReportFamily.fromJson(Map<String, dynamic> json) => ReportFamily(
    id: json['id'] as int,
    name: json['name'] as String,
    students: List<String>.from(json['students'] as List? ?? const []),
  );

  final int id;
  final String name;
  final List<String> students;
}

/// Pago por transferencia informado con su comprobante (`API_V1.md`, «Comprobantes de transferencia»).
class PaymentReport {
  const PaymentReport({
    required this.id,
    required this.amount,
    required this.paidOn,
    required this.status,
    this.reference,
    this.notes,
    this.rejectionReason,
    this.moneyAccount,
    this.charges = const [],
    this.proofUrl,
    this.proofName,
    this.createdAt,
    this.reviewedAt,
    this.receiptNumber,
    this.receiptUrl,
    this.family,
    this.reportedBy,
    this.pendingBalance,
    this.moneyAccounts = const [],
  });

  factory PaymentReport.fromJson(Map<String, dynamic> json) {
    final account = json['money_account'] as Map<String, dynamic>?;
    final family = json['family'] as Map<String, dynamic>?;
    return PaymentReport(
      id: json['id'] as int,
      amount: json['amount'] as int,
      paidOn: DateTime.parse(json['paid_on'] as String),
      status: PaymentReportStatus.parse(json['status']),
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      moneyAccount: account == null ? null : TransferAccount.fromJson(account),
      charges: ((json['charges'] as List?) ?? const [])
          .map((c) => ReportedCharge.fromJson(c as Map<String, dynamic>))
          .toList(),
      proofUrl: json['proof_url'] as String?,
      proofName: json['proof_name'] as String?,
      createdAt: _dateTime(json['created_at']),
      reviewedAt: _dateTime(json['reviewed_at']),
      receiptNumber: json['receipt_number'] as String?,
      receiptUrl: json['receipt_url'] as String?,
      family: family == null ? null : ReportFamily.fromJson(family),
      reportedBy: json['reported_by'] as String?,
      pendingBalance: json['pending_balance'] as int?,
      moneyAccounts: ((json['money_accounts'] as List?) ?? const [])
          .map((a) => TransferAccount.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final int amount;
  final DateTime paidOn;
  final PaymentReportStatus status;
  final String? reference;
  final String? notes;
  final String? rejectionReason;

  /// Cuenta a la que dice haber transferido.
  final TransferAccount? moneyAccount;

  /// Cuotas elegidas; vacío = pago a cuenta.
  final List<ReportedCharge> charges;

  /// Link firmado y temporal al archivo del comprobante.
  final String? proofUrl;
  final String? proofName;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  /// Recibo del pago registrado al aprobarlo.
  final String? receiptNumber;
  final String? receiptUrl;

  /// Solo para quien valida.
  final ReportFamily? family;
  final String? reportedBy;
  final int? pendingBalance;
  final List<TransferAccount> moneyAccounts;

  bool get isPending => status == PaymentReportStatus.pending;

  /// "Sofía · Cuota octubre 2026, Mateo · Cuota octubre 2026" o "Pago a cuenta".
  String get chargesSummary => charges.isEmpty
      ? 'Pago a cuenta'
      : charges
            .map((c) => '${c.studentFirstName} · ${c.description}')
            .join(', ');
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;
