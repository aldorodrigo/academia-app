import '../../billing/data/models.dart';
import '../../payment_reports/data/models.dart';
import '../../payment_reports/data/report_form.dart';

/// Modelos del cobro en efectivo y la caja del técnico (`API_V1.md`, «Cobro en
/// efectivo y caja del técnico»).

/// Alumno que se le puede cobrar, con lo que debe hoy su familia.
class CollectableStudent {
  const CollectableStudent({
    required this.id,
    required this.fullName,
    this.photoUrl,
    this.groups = const [],
    this.family,
    this.dueNow = 0,
    this.overdue = 0,
  });

  factory CollectableStudent.fromJson(Map<String, dynamic> json) =>
      CollectableStudent(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        photoUrl: json['photo_url'] as String?,
        groups: List<String>.from(json['groups'] as List? ?? const []),
        family: json['family'] as String?,
        dueNow: json['due_now'] as int? ?? 0,
        overdue: json['overdue'] as int? ?? 0,
      );

  final int id;
  final String fullName;
  final String? photoUrl;
  final List<String> groups;
  final String? family;

  /// Lo que debe hoy la familia (sin las próximas) y la parte vencida.
  final int dueNow;
  final int overdue;

  String get initials => fullName
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  /// Coincide con lo buscado (sin distinguir mayúsculas ni tildes).
  bool matches(String search) {
    final query = _plain(search.trim());
    if (query.isEmpty) return true;
    return _plain('$fullName ${family ?? ''}').contains(query);
  }
}

String _plain(String text) => text
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

/// Cuota pendiente de la familia, con lo que la salda si se paga hoy.
class CollectableCharge {
  const CollectableCharge({
    required this.charge,
    required this.settleAmount,
    this.earlyPaymentAmount = 0,
    this.earlyPaymentLabel,
    this.underReview = false,
  });

  factory CollectableCharge.fromJson(Map<String, dynamic> json) {
    final early = json['early_payment'] as Map<String, dynamic>?;
    final charge = Charge.fromJson(json);
    return CollectableCharge(
      charge: charge,
      settleAmount: json['settle_amount'] as int? ?? charge.pendingAmount,
      earlyPaymentAmount: early?['amount'] as int? ?? 0,
      earlyPaymentLabel: early?['label'] as String?,
      underReview: json['under_review'] as bool? ?? false,
    );
  }

  final Charge charge;

  /// Lo que salda la cuota hoy (con el pronto pago, si corresponde).
  final int settleAmount;
  final int earlyPaymentAmount;
  final String? earlyPaymentLabel;

  /// Está en un comprobante de transferencia en revisión.
  final bool underReview;

  int get id => charge.id;
  bool get isUpcoming => charge.isUpcoming;
}

/// Tutor de la familia (para elegir quién pagó).
class GuardianOption {
  const GuardianOption({required this.id, required this.fullName});

  factory GuardianOption.fromJson(Map<String, dynamic> json) => GuardianOption(
    id: json['id'] as int,
    fullName: json['full_name'] as String,
  );

  final int id;
  final String fullName;
}

/// La caja de quien cobra: nombre y saldo.
class CashBoxSummary {
  const CashBoxSummary({
    required this.id,
    required this.name,
    required this.balance,
    this.active = true,
  });

  factory CashBoxSummary.fromJson(Map<String, dynamic> json) => CashBoxSummary(
    id: json['id'] as int,
    name: json['name'] as String,
    balance: json['balance'] as int? ?? 0,
    active: json['active'] as bool? ?? true,
  );

  final int id;
  final String name;
  final int balance;

  /// `false` = caja cerrada: no puede cobrar.
  final bool active;
}

/// Lo que se ve al cobrarle a un alumno: su familia y sus cuotas pendientes.
class CollectionTarget {
  const CollectionTarget({
    required this.studentId,
    required this.studentName,
    this.familyName,
    this.familyStudents = const [],
    this.guardians = const [],
    this.credit = 0,
    this.charges = const [],
    this.cashBox,
    this.transferAccounts = const [],
    this.approvesTransfers = false,
    this.collectsToOrgCash = false,
    this.collectAccounts = const [],
    this.defaultCollectAccountId,
  });

  factory CollectionTarget.fromJson(Map<String, dynamic> json) {
    final student = json['student'] as Map<String, dynamic>;
    final family = json['family'] as Map<String, dynamic>?;
    final box = json['cash_box'] as Map<String, dynamic>?;
    return CollectionTarget(
      studentId: student['id'] as int,
      studentName: student['full_name'] as String,
      familyName: family?['name'] as String?,
      familyStudents: List<String>.from(
        family?['students'] as List? ?? const [],
      ),
      guardians: ((json['guardians'] as List?) ?? const [])
          .map((g) => GuardianOption.fromJson(g as Map<String, dynamic>))
          .toList(),
      credit: json['credit'] as int? ?? 0,
      charges: ((json['charges'] as List?) ?? const [])
          .map((c) => CollectableCharge.fromJson(c as Map<String, dynamic>))
          .toList(),
      cashBox: box == null ? null : CashBoxSummary.fromJson(box),
      transferAccounts: ((json['transfer_accounts'] as List?) ?? const [])
          .map((a) => TransferAccount.fromJson(a as Map<String, dynamic>))
          .toList(),
      approvesTransfers: json['approves_transfers'] as bool? ?? false,
      collectsToOrgCash: json['collects_to_org_cash'] as bool? ?? false,
      collectAccounts: ((json['collect_accounts'] as List?) ?? const [])
          .map((a) => TransferAccount.fromJson(a as Map<String, dynamic>))
          .toList(),
      defaultCollectAccountId: json['default_collect_account_id'] as int?,
    );
  }

  final int studentId;
  final String studentName;
  final String? familyName;
  final List<String> familyStudents;
  final List<GuardianOption> guardians;

  /// Saldo a favor que ya tiene la familia.
  final int credit;
  final List<CollectableCharge> charges;

  /// `null` si todavía no cobró nunca (la caja se crea con el primer cobro).
  final CashBoxSummary? cashBox;

  /// Bancos y billeteras del club donde pudo entrar una transferencia.
  final List<TransferAccount> transferAccounts;

  /// Quien cobra valida comprobantes: la transferencia queda aprobada al
  /// registrarla (si no, en revisión del tesorero).
  final bool approvesTransfers;

  /// Cobra directo a la Caja del club (o a otra cuenta del club que elija):
  /// sin caja personal ni depósito.
  final bool collectsToOrgCash;

  /// Cuentas del club donde puede entrar el efectivo (solo si cobra directo).
  final List<TransferAccount> collectAccounts;
  final int? defaultCollectAccountId;

  bool get canCollect => collectsToOrgCash || (cashBox?.active ?? true);

  List<CollectableCharge> get dueCharges =>
      charges.where((c) => !c.isUpcoming).toList();

  List<CollectableCharge> get upcomingCharges =>
      charges.where((c) => c.isUpcoming).toList();
}

/// Lo que completa quien cobra.
class CollectionDraft {
  const CollectionDraft({
    required this.studentId,
    required this.amount,
    required this.requestId,
    this.chargeIds = const [],
    this.guardianId,
    this.notes,
    this.moneyAccountId,
  });

  final int studentId;
  final int amount;

  /// El mismo valor en un reintento devuelve el mismo pago (no lo duplica).
  final String requestId;
  final List<int> chargeIds;
  final int? guardianId;
  final String? notes;

  /// Solo si cobra directo: la cuenta del club donde entra (sin elegir, la Caja).
  final int? moneyAccountId;
}

/// Transferencia que la familia le mandó a quien cobra (la captura de
/// WhatsApp), registrada en su nombre.
class TransferRegistrationDraft {
  const TransferRegistrationDraft({
    required this.studentId,
    required this.amount,
    required this.paidOn,
    required this.proof,
    this.chargeIds = const [],
    this.moneyAccountId,
    this.guardianId,
    this.reference,
  });

  final int studentId;
  final int amount;
  final DateTime paidOn;
  final PickedProof proof;
  final List<int> chargeIds;
  final int? moneyAccountId;
  final int? guardianId;
  final String? reference;
}

/// La transferencia registrada: aprobada con recibo o en revisión.
class TransferRegistration {
  const TransferRegistration({required this.report, required this.message});

  final PaymentReport report;
  final String message;
}

/// Cobro registrado: el pago con su recibo y cómo quedó la caja.
class CollectionResult {
  const CollectionResult({
    required this.payment,
    required this.applied,
    required this.credit,
    required this.message,
    this.cashBox,
    this.accountName,
  });

  factory CollectionResult.fromJson(Map<String, dynamic> json) {
    final box = json['cash_box'] as Map<String, dynamic>?;
    final account = json['account'] as Map<String, dynamic>?;
    return CollectionResult(
      accountName: account?['name'] as String?,
      payment: Payment.fromJson(json['payment'] as Map<String, dynamic>),
      applied: json['applied'] as int? ?? 0,
      credit: json['credit'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      cashBox: box == null ? null : CashBoxSummary.fromJson(box),
    );
  }

  final Payment payment;

  /// Lo imputado a cuotas y lo que quedó a favor de la familia.
  final int applied;
  final int credit;
  final String message;

  /// `null` si cobró directo a una cuenta del club.
  final CashBoxSummary? cashBox;

  /// Dónde entró la plata ("Caja de Juan Pérez" o "Caja").
  final String? accountName;
}

/// Estado de un depósito de efectivo informado por el técnico.
enum CashDepositStatus {
  pending('pendiente', 'Por confirmar'),
  confirmed('confirmado', 'Confirmado'),
  rejected('rechazado', 'Rechazado'),
  voided('anulado', 'Anulado');

  const CashDepositStatus(this.value, this.label);

  final String value;
  final String label;

  /// Un valor desconocido se trata como por confirmar en lugar de romper.
  static CashDepositStatus parse(Object? value) => values.firstWhere(
    (s) => s.value == value,
    orElse: () => CashDepositStatus.pending,
  );
}

/// Cuenta del club a donde se deposita.
class DepositAccount {
  const DepositAccount({required this.id, required this.name, this.type});

  factory DepositAccount.fromJson(Map<String, dynamic> json) => DepositAccount(
    id: json['id'] as int,
    name: json['name'] as String,
    type: json['type'] as String?,
  );

  final int id;
  final String name;

  /// `caja`, `banco` o `billetera`.
  final String? type;
}

/// Depósito (rendición) de la plata de una caja personal a una cuenta del club.
class CashDeposit {
  const CashDeposit({
    required this.id,
    required this.amount,
    required this.depositedOn,
    required this.status,
    this.account,
    this.reference,
    this.notes,
    this.rejectionReason,
    this.createdAt,
    this.reviewedAt,
    this.holderName,
  });

  factory CashDeposit.fromJson(Map<String, dynamic> json) {
    final account = json['money_account'] as Map<String, dynamic>?;
    final holder = json['holder'] as Map<String, dynamic>?;
    return CashDeposit(
      id: json['id'] as int,
      amount: json['amount'] as int,
      depositedOn: DateTime.parse(json['deposited_on'] as String),
      status: CashDepositStatus.parse(json['status']),
      account: account == null ? null : DepositAccount.fromJson(account),
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: _dateTime(json['created_at']),
      reviewedAt: _dateTime(json['reviewed_at']),
      holderName: holder?['name'] as String?,
    );
  }

  final int id;
  final int amount;
  final DateTime depositedOn;
  final CashDepositStatus status;
  final DepositAccount? account;
  final String? reference;
  final String? notes;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  /// Quién lo depositó.
  final String? holderName;

  bool get isPending => status == CashDepositStatus.pending;
}

/// Tipo de movimiento de la caja.
enum CashMovementKind {
  collection('cobro'),
  deposit('deposito'),
  reversal('anulacion'),
  other('otro');

  const CashMovementKind(this.value);

  final String value;

  static CashMovementKind parse(Object? value) => values.firstWhere(
    (k) => k.value == value,
    orElse: () => CashMovementKind.other,
  );
}

/// Movimiento del libro mayor de la caja (monto con signo).
class CashMovement {
  const CashMovement({
    required this.id,
    required this.occurredOn,
    required this.description,
    required this.amount,
    required this.kind,
    this.receiptUrl,
  });

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
    id: json['id'] as int,
    occurredOn: DateTime.parse(json['occurred_on'] as String),
    description: json['description'] as String,
    amount: json['amount'] as int,
    kind: CashMovementKind.parse(json['kind']),
    receiptUrl: json['receipt_url'] as String?,
  );

  final int id;
  final DateTime occurredOn;
  final String description;
  final int amount;
  final CashMovementKind kind;
  final String? receiptUrl;
}

/// "Mi caja": la plata del club que tiene quien cobra.
class CashBox {
  const CashBox({
    this.id,
    this.name,
    this.active = true,
    this.balance = 0,
    this.pendingDeposits = 0,
    this.available = 0,
    this.movements = const [],
    this.deposits = const [],
    this.depositAccounts = const [],
  });

  factory CashBox.fromJson(Map<String, dynamic> json) => CashBox(
    id: json['id'] as int?,
    name: json['name'] as String?,
    active: json['active'] as bool? ?? true,
    balance: json['balance'] as int? ?? 0,
    pendingDeposits: json['pending_deposits'] as int? ?? 0,
    available: json['available'] as int? ?? 0,
    movements: ((json['movements'] as List?) ?? const [])
        .map((m) => CashMovement.fromJson(m as Map<String, dynamic>))
        .toList(),
    deposits: ((json['deposits'] as List?) ?? const [])
        .map((d) => CashDeposit.fromJson(d as Map<String, dynamic>))
        .toList(),
    depositAccounts: ((json['deposit_accounts'] as List?) ?? const [])
        .map((a) => DepositAccount.fromJson(a as Map<String, dynamic>))
        .toList(),
  );

  static const empty = CashBox();

  /// `null` si todavía no cobró nunca.
  final int? id;
  final String? name;
  final bool active;

  /// Saldo en su poder, lo que está por confirmar y lo que puede depositar.
  final int balance;
  final int pendingDeposits;
  final int available;
  final List<CashMovement> movements;
  final List<CashDeposit> deposits;
  final List<DepositAccount> depositAccounts;

  bool get canDeposit => available > 0 && depositAccounts.isNotEmpty;
}

/// Lo que informa el técnico al depositar.
class DepositDraft {
  const DepositDraft({
    required this.amount,
    required this.moneyAccountId,
    required this.depositedOn,
    this.reference,
    this.notes,
  });

  final int amount;
  final int moneyAccountId;
  final DateTime depositedOn;
  final String? reference;
  final String? notes;
}

/// Caja personal vista por quien valida.
class HolderCashBox {
  const HolderCashBox({
    required this.id,
    required this.name,
    required this.holderName,
    required this.balance,
    this.holderActive = true,
    this.pendingDeposits = 0,
    this.lastMovementOn,
  });

  factory HolderCashBox.fromJson(Map<String, dynamic> json) {
    final holder = json['holder'] as Map<String, dynamic>? ?? const {};
    final last = json['last_movement_on'] as String?;
    return HolderCashBox(
      id: json['id'] as int,
      name: json['name'] as String,
      holderName: holder['name'] as String? ?? json['name'] as String,
      holderActive: holder['active'] as bool? ?? true,
      balance: json['balance'] as int? ?? 0,
      pendingDeposits: json['pending_deposits'] as int? ?? 0,
      lastMovementOn: last == null ? null : DateTime.parse(last),
    );
  }

  final int id;
  final String name;
  final String holderName;

  /// `false` = ya no es miembro activo del club.
  final bool holderActive;
  final int balance;
  final int pendingDeposits;
  final DateTime? lastMovementOn;
}

/// "Efectivo": cuánto tiene cada uno y los depósitos por confirmar.
/// Quien cobra en efectivo y si cobra directo a la Caja del club (lo ve y lo
/// cambia quien administra los miembros).
class CashCollector {
  const CashCollector({
    required this.userId,
    required this.name,
    this.collectsToOrgCash = false,
    this.isOwner = false,
  });

  factory CashCollector.fromJson(Map<String, dynamic> json) => CashCollector(
    userId: json['user_id'] as int,
    name: json['name'] as String? ?? '',
    collectsToOrgCash: json['collects_to_org_cash'] as bool? ?? false,
    isOwner: json['owner'] as bool? ?? false,
  );

  final int userId;
  final String name;
  final bool collectsToOrgCash;

  /// Quien creó la organización (cobra directo por defecto).
  final bool isOwner;
}

class CashOverview {
  const CashOverview({
    this.total = 0,
    this.boxes = const [],
    this.deposits = const [],
    this.collectors,
  });

  factory CashOverview.fromJson(Map<String, dynamic> json) => CashOverview(
    collectors: (json['collectors'] as List?)
        ?.map((c) => CashCollector.fromJson(c as Map<String, dynamic>))
        .toList(),
    total: json['total'] as int? ?? 0,
    boxes: ((json['boxes'] as List?) ?? const [])
        .map((b) => HolderCashBox.fromJson(b as Map<String, dynamic>))
        .toList(),
    deposits: ((json['deposits'] as List?) ?? const [])
        .map((d) => CashDeposit.fromJson(d as Map<String, dynamic>))
        .toList(),
  );

  final int total;
  final List<HolderCashBox> boxes;
  final List<CashDeposit> deposits;

  /// Solo para quien administra los miembros (si no, `null`).
  final List<CashCollector>? collectors;
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.parse(value).toLocal() : null;
