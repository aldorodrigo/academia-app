Map<String, Object?> studentJson({int id = 12, String first = 'Mateo'}) => {
  'id': id,
  'first_name': first,
  'full_name': '$first Benítez',
};

Map<String, Object?> packJson({
  int id = 5,
  int classes = 4,
  int used = 1,
  int reserved = 1,
  int? available,
  String status = 'activo',
  String? activatedOn = '2026-09-20',
  String? expiresOn = '2026-11-18',
  int? validDays = 60,
  Map<String, Object?>? charge = const {
    'id': 300,
    'amount': 100000,
    'pending': 0,
  },
}) => {
  'id': id,
  'teacher_id': 7,
  'student_id': 12,
  'classes': classes,
  'used': used,
  'reserved': reserved,
  'available': available ?? classes - used - reserved,
  'price': 100000,
  'valid_days': validDays,
  'status': status,
  'activated_on': activatedOn,
  'expires_on': expiresOn,
  'charge': charge,
};

Map<String, Object?> bookingJson({
  int id = 40,
  String date = '2026-09-28',
  String startsAt = '16:00',
  String endsAt = '17:00',
  String status = 'confirmada',
  String payment = 'paquete',
  Map<String, Object?>? pack,
  Map<String, Object?>? charge,
  int credit = 0,
  bool canCancel = true,
  Map<String, Object?>? student,
}) => {
  'id': id,
  'date': date,
  'starts_at': startsAt,
  'ends_at': endsAt,
  'status': status,
  'payment': payment,
  'price': payment == 'suelta' ? 35000 : null,
  'class_pack_id': payment == 'paquete' ? 5 : null,
  'teacher': {'id': 7, 'name': 'Carlos Gómez'},
  'student': student ?? studentJson(),
  'charge': charge,
  'can_cancel': canCancel,
  'pack': pack,
  'credit': credit,
};

Map<String, Object?> teacherJson({
  List<Map<String, Object?>>? students,
  List<Map<String, Object?>> packs = const [
    {'id': 2, 'classes': 4, 'price': 100000, 'valid_days': 60},
  ],
}) => {
  'id': 7,
  'name': 'Carlos Gómez',
  'photo_url': null,
  'duration_minutes': 60,
  'single_price': 35000,
  'packs': packs,
  'students':
      students ??
      [
        {'student': studentJson(), 'pack': packJson(), 'next_booking': null},
      ],
};

Map<String, Object?> profileJson({
  bool enabled = true,
  List<Map<String, Object?>> packs = const [],
  List<Map<String, Object?>> availability = const [
    {'weekday': 1, 'starts_at': '15:00', 'ends_at': '18:00'},
  ],
}) => {
  'data': {
    'enabled': enabled,
    'duration_minutes': 60,
    'single_price': 35000,
    'min_notice_minutes': 120,
    'days_ahead': 30,
    'money_account_id': 1,
    'money_accounts': [
      {'id': 1, 'name': 'Caja'},
    ],
    'packs': packs,
    'availability': availability,
  },
};
