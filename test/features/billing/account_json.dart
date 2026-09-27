/// Respuestas de ejemplo según el contrato (`academia-api/docs/API_V1.md`, Sprint 3).
Map<String, Object?> chargeJson({
  int id = 501,
  int studentId = 13,
  String firstName = 'Sofía',
  String status = 'pendiente',
  String description = 'Cuota septiembre 2026',
  String? period = '2026-09',
  int base = 150000,
  int total = 60000,
  List<Map<String, Object?>>? adjustments,
}) => {
  'id': id,
  'student': {'id': studentId, 'first_name': firstName},
  'concept': 'Cuota mensual',
  'description': description,
  'period': period,
  'group': 'Sub-8',
  'issued_on': '2026-09-01',
  'due_on': '2026-09-10',
  'status': status,
  'status_label': status,
  'base_amount': base,
  'final_amount': total,
  'adjustments':
      adjustments ??
      [
        {'type': 'beca', 'label': 'Beca 50 %', 'amount': -75000},
        {
          'type': 'hermanos',
          'label': 'Hermanos (2º hijo) −20 %',
          'amount': -15000,
        },
      ],
};

/// Cuota semanal de una colonia, creada por adelantado (Sprint 4c).
Map<String, Object?> upcomingChargeJson({
  int id = 700,
  String description = 'Colonia: semana 4–10 ene (5 entrenamientos)',
  String dueOn = '2027-01-07',
  bool upcoming = true,
}) => {
  ...chargeJson(
    id: id,
    description: description,
    period: '2027-01',
    base: 100000,
    total: 100000,
    adjustments: const [],
  ),
  'concept': 'Cuota',
  'due_on': dueOn,
  'season': {'id': 3, 'name': 'Colonia de verano 2027'},
  'period_start': '2027-01-04',
  'period_end': '2027-01-10',
  'quantity': 5,
  'unit_amount': 20000,
  'is_upcoming': upcoming,
};

Map<String, Object?> accountJson({
  int balance = 270000,
  int overdue = 150000,
  List<Map<String, Object?>>? students,
  List<Map<String, Object?>>? charges,
}) => {
  'balance': balance,
  'overdue': overdue,
  'students':
      students ??
      [
        {
          'id': 12,
          'full_name': 'Mateo Benítez',
          'balance': 150000,
          'overdue': 150000,
        },
        {
          'id': 13,
          'full_name': 'Sofía Benítez',
          'balance': 120000,
          'overdue': 0,
        },
      ],
  'charges':
      charges ??
      [
        chargeJson(),
        chargeJson(
          id: 400,
          studentId: 12,
          firstName: 'Mateo',
          status: 'vencido',
          description: 'Cuota agosto 2026',
          period: '2026-08',
          base: 150000,
          total: 150000,
          adjustments: const [],
        ),
        chargeJson(
          id: 300,
          studentId: 12,
          firstName: 'Mateo',
          status: 'pagado',
          description: 'Inscripción 2026',
          period: null,
          base: 100000,
          total: 100000,
          adjustments: const [],
        ),
      ],
};

Map<String, Object?> paymentJson({
  int id = 90,
  bool voided = false,
  int creditGenerated = 90000,
}) => {
  'id': id,
  'receipt_number': '000123',
  'received_on': '2026-09-20',
  'amount': 300000,
  'method': 'transferencia',
  'method_label': 'Transferencia',
  'voided': voided,
  'receipt_url': 'https://api.test/recibos/$id?signature=abc',
  'allocations': [
    {
      'charge_id': 400,
      'description': 'Cuota agosto 2026',
      'student_first_name': 'Mateo',
      'amount': 150000,
    },
    {
      'charge_id': 501,
      'description': 'Cuota septiembre 2026',
      'student_first_name': 'Sofía',
      'amount': 60000,
    },
  ],
  'credit_generated': creditGenerated,
};
