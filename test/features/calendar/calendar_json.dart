import '../attendance/class_json.dart';
import '../lessons/lesson_json.dart';

/// Respuestas de ejemplo según el contrato (`academia-api/docs/API_V1.md`,
/// «Calendario de actividades»).
Map<String, Object?> calendarClassJson({
  int id = 81,
  String date = '2026-10-05',
  String status = 'programada',
  String? suspensionReason,
  int? dayOffId,
  bool canTakeAttendance = false,
  List<Map<String, Object?>> students = const [],
}) => {
  ...classJson(
    id: id,
    date: date,
    status: status,
    suspensionReason: suspensionReason,
  ),
  'counts': null,
  'editable': null,
  'day_off_id': dayOffId,
  'can_take_attendance': canTakeAttendance,
  'students': students,
};

Map<String, Object?> calendarStudentJson({
  int id = 12,
  String firstName = 'Mateo',
  String? response,
  bool canRespond = true,
  String? attendance,
}) => {
  'id': id,
  'first_name': firstName,
  'response': response,
  'can_respond': canRespond,
  'attendance': attendance,
};

Map<String, Object?> calendarBookingJson({
  int id = 40,
  String date = '2026-10-06',
  String as = 'student',
}) => {...bookingJson(id: id, date: date), 'as': as};

Map<String, Object?> eventJson({
  int id = 7,
  String kind = 'evento',
  String category = 'torneo',
  String categoryLabel = 'Torneo',
  String title = 'Apertura Sub-10',
  String startsOn = '2026-10-11',
  String? endsOn,
  String? startsAt = '08:00',
  String? endsAt = '18:00',
  Map<String, Object?>? venue,
  String? place = 'Club Olimpia',
  bool everyone = false,
  bool cancelled = false,
  String? cancelReason,
  bool canEdit = true,
  bool canCancel = true,
  bool waiveCharge = false,
  List<Map<String, Object?>>? affectedClasses,
}) => {
  'id': id,
  'kind': kind,
  'category': category,
  'category_label': categoryLabel,
  'title': title,
  'description': 'Llevar la camiseta blanca.',
  'starts_on': startsOn,
  'ends_on': endsOn ?? startsOn,
  'starts_at': startsAt,
  'ends_at': endsAt,
  'venue': venue,
  'place': place,
  'audience': {
    'everyone': everyone,
    'groups': everyone
        ? const []
        : [
            {
              'id': 3,
              'name': 'Sub-10',
              'program': {'id': 1, 'name': 'Fútbol'},
            },
          ],
  },
  'waive_charge': waiveCharge,
  'cancelled': cancelled,
  'cancel_reason': cancelReason,
  'created_by': {'name': 'Ana Benítez'},
  'created_at': '2026-10-02T21:14:00-03:00',
  'can_edit': canEdit,
  'can_cancel': canCancel,
  'affected_classes': ?affectedClasses,
};

Map<String, Object?> dayOffJson({
  int id = 9,
  String title = 'Día del Docente',
  String category = 'feriado',
  String startsOn = '2026-10-07',
  String? endsOn,
  bool cancelled = false,
  List<Map<String, Object?>>? affectedClasses,
}) => eventJson(
  id: id,
  kind: 'sin_clase',
  category: category,
  categoryLabel: category == 'feriado' ? 'Feriado' : 'Vacaciones',
  title: title,
  startsOn: startsOn,
  endsOn: endsOn,
  startsAt: null,
  endsAt: null,
  place: null,
  cancelled: cancelled,
  waiveCharge: true,
  affectedClasses: affectedClasses,
);

Map<String, Object?> calendarJson({
  String from = '2026-09-28',
  String to = '2026-11-08',
  List<Map<String, Object?>> classes = const [],
  List<Map<String, Object?>> bookings = const [],
  List<Map<String, Object?>> events = const [],
}) => {
  'data': {
    'from': from,
    'to': to,
    'classes': classes,
    'bookings': bookings,
    'events': events,
  },
};

Map<String, Object?> eventOptionsJson({
  bool canTargetOrganization = true,
  List<Map<String, Object?>>? groups,
}) => {
  'data': {
    'can_target_organization': canTargetOrganization,
    'groups':
        groups ??
        [
          {
            'id': 3,
            'name': 'Sub-10',
            'program': {'id': 1, 'name': 'Fútbol'},
          },
          {
            'id': 4,
            'name': 'Sub-12',
            'program': {'id': 1, 'name': 'Fútbol'},
          },
          {
            'id': 8,
            'name': 'Inicial',
            'program': {'id': 2, 'name': 'Natación'},
          },
        ],
    'venues': [
      {'id': 1, 'name': 'Cancha 1'},
    ],
    'categories': {
      'evento': [
        {'value': 'torneo', 'label': 'Torneo'},
        {'value': 'amistoso', 'label': 'Amistoso'},
        {'value': 'festival', 'label': 'Festival'},
        {'value': 'reunion', 'label': 'Reunión de padres'},
        {'value': 'otro', 'label': 'Otro'},
      ],
      'sin_clase': [
        {'value': 'feriado', 'label': 'Feriado'},
        {'value': 'vacaciones', 'label': 'Vacaciones'},
        {'value': 'lluvia', 'label': 'Lluvia'},
        {'value': 'otro', 'label': 'Otro'},
      ],
    },
  },
};

Map<String, Object?> previewJson({
  int families = 48,
  int instructors = 3,
  int? suspended,
  int skippedStarted = 0,
  bool canWaiveCharge = false,
}) => {
  'data': {
    'recipients': {'families': families, 'instructors': instructors},
    'classes': suspended == null
        ? null
        : {
            'suspended': suspended,
            'skipped_started': skippedStarted,
            'already_off': 0,
            'items': [
              {
                'date': '2026-10-07',
                'starts_at': '17:00',
                'group': {'id': 3, 'name': 'Sub-10'},
              },
            ],
          },
    'can_waive_charge': canWaiveCharge,
  },
};
