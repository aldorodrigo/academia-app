/// Respuestas de ejemplo según el contrato (`academia-api/docs/API_V1.md`).
Map<String, Object?> studentSummaryJson({
  int id = 12,
  String firstName = 'Mateo',
  String status = 'activo',
  bool isSelf = false,
}) => {
  'id': id,
  'first_name': firstName,
  'last_name': 'Benítez',
  'full_name': '$firstName Benítez',
  'birth_date': '2016-03-14',
  'photo_url': null,
  'is_self': isSelf,
  'enrollments': [
    {
      'id': 40,
      'status': status,
      'status_label': 'Activo',
      'season': {'id': 1, 'name': '2026'},
      'group': {
        'id': 3,
        'name': 'Sub-10',
        'program': {'id': 1, 'name': 'Fútbol'},
      },
    },
  ],
};

Map<String, Object?> studentDetailJson({
  bool withMedical = true,
  bool canViewMedical = true,
  String? fitUntil = '2027-03-01',
}) => {
  ...studentSummaryJson(),
  'document': '6123456',
  'shirt_size': '12',
  'position': 'Arquero',
  'guardians': [
    {'name': 'Ana Benítez', 'relationship': 'Madre', 'is_me': true},
    {'name': 'Luis Benítez', 'relationship': 'Padre', 'is_me': false},
  ],
  'enrollments': [
    {
      'id': 40,
      'status': 'becado',
      'status_label': 'Becado',
      'season': {'id': 1, 'name': '2026'},
      'group': {
        'id': 3,
        'name': 'Sub-10',
        'program': {'id': 1, 'name': 'Fútbol'},
        'schedules': [
          {
            'weekday': 3,
            'starts_at': '17:00',
            'ends_at': '18:30',
            'venue': null,
          },
          {
            'weekday': 1,
            'starts_at': '17:00',
            'ends_at': '18:30',
            'venue': {'name': 'Cancha 1'},
          },
        ],
        'instructors': [
          {'name': 'Carlos Gómez'},
        ],
      },
    },
  ],
  'medical': withMedical
      ? {
          'blood_type': 'O+',
          'allergies': 'Penicilina',
          'conditions': null,
          'medications': null,
          'emergency_contact': {'name': 'Ana Benítez', 'phone': '0981 123 456'},
          'fit_until': fitUntil,
        }
      : null,
  'permissions': {'view_medical': canViewMedical},
};
