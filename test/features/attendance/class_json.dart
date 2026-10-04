/// Respuestas de ejemplo según el contrato (`academia-api/docs/API_V1.md`, Sprint 5).
Map<String, Object?> classJson({
  int id = 81,
  String date = '2026-09-28',
  String status = 'programada',
  String? suspensionReason,
  bool attendanceTaken = false,
  bool editable = true,
  List<Map<String, Object?>>? students,
  Map<String, Object?>? counts,
}) => {
  'id': id,
  'date': date,
  'starts_at': '17:00',
  'ends_at': '18:30',
  'venue': {'name': 'Cancha 1'},
  'group': {
    'id': 3,
    'name': 'Sub-10',
    'program': {'id': 1, 'name': 'Fútbol'},
  },
  'status': status,
  'suspension_reason': suspensionReason,
  'attendance_taken': attendanceTaken,
  'counts':
      counts ??
      {
        'enrolled': 3,
        'going': 1,
        'not_going': 1,
        'no_answer': 1,
        'present': 0,
        'absent': 0,
        'justified': 0,
      },
  'editable': editable,
  'students': ?students,
};

Map<String, Object?> classStudentJson({
  required int id,
  required String name,
  String? status,
  String? response,
  String? note,
}) => {
  'id': id,
  'full_name': name,
  'photo_url': null,
  'status': status,
  'guardian_response': response,
  'note': note,
};

List<Map<String, Object?>> threeStudents() => [
  classStudentJson(id: 12, name: 'Mateo Benítez', response: 'no_va'),
  classStudentJson(id: 13, name: 'Lucas Ortiz', response: 'va'),
  classStudentJson(id: 14, name: 'Tomás Villalba'),
];

Map<String, Object?> agendaItemJson({
  String date = '2026-09-28',
  String? response,
  bool canRespond = true,
  bool? classReminders,
  String status = 'programada',
}) => {
  'student': {
    'id': 12,
    'first_name': 'Mateo',
    'full_name': 'Mateo Benítez',
    'photo_url': null,
  },
  'class': classJson(date: date, status: status),
  'response': response,
  'can_respond': canRespond,
  'class_reminders': classReminders,
};
