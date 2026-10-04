/// Momento de un aviso: minutos antes de la clase o "eve" (el día anterior a las 20:00).
class ReminderOffset implements Comparable<ReminderOffset> {
  const ReminderOffset(this.key);

  factory ReminderOffset.fromJson(Object? value) =>
      ReminderOffset(value.toString());

  static const eve = ReminderOffset('eve');

  /// "eve" o los minutos como texto ("180").
  final String key;

  bool get isEve => key == eve.key;

  int get minutes => isEve ? 0 : int.tryParse(key) ?? 0;

  Object toJson() => isEve ? key : minutes;

  /// Del más temprano al más cercano a la clase.
  @override
  int compareTo(ReminderOffset other) {
    if (isEve || other.isEve) {
      return isEve == other.isEve ? 0 : (isEve ? -1 : 1);
    }
    return other.minutes.compareTo(minutes);
  }

  @override
  bool operator ==(Object other) => other is ReminderOffset && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class ReminderOption {
  const ReminderOption({required this.offset, required this.label});

  factory ReminderOption.fromJson(Map<String, dynamic> json) => ReminderOption(
    offset: ReminderOffset.fromJson(json['value']),
    label: json['label'] as String,
  );

  final ReminderOffset offset;
  final String label;
}

class InstructorReminders {
  const InstructorReminders({required this.enabled, required this.offsets});

  factory InstructorReminders.fromJson(Map<String, dynamic> json) =>
      InstructorReminders(
        enabled: json['enabled'] as bool? ?? true,
        offsets: _offsets(json['offsets']),
      );

  final bool enabled;
  final List<ReminderOffset> offsets;

  InstructorReminders copyWith({
    bool? enabled,
    List<ReminderOffset>? offsets,
  }) => InstructorReminders(
    enabled: enabled ?? this.enabled,
    offsets: offsets ?? this.offsets,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'offsets': [for (final o in offsets) o.toJson()],
  };
}

class ChildReminders {
  const ChildReminders({
    required this.id,
    required this.firstName,
    required this.enabled,
  });

  factory ChildReminders.fromJson(Map<String, dynamic> json) => ChildReminders(
    id: json['id'] as int,
    firstName: json['first_name'] as String,
    enabled: json['enabled'] as bool? ?? false,
  );

  final int id;
  final String firstName;
  final bool enabled;
}

class GuardianReminders {
  const GuardianReminders({required this.offsets, this.students = const []});

  factory GuardianReminders.fromJson(Map<String, dynamic> json) =>
      GuardianReminders(
        offsets: _offsets(json['offsets']),
        students: ((json['students'] as List?) ?? const [])
            .map((s) => ChildReminders.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final List<ReminderOffset> offsets;
  final List<ChildReminders> students;

  GuardianReminders copyWith({List<ReminderOffset>? offsets}) =>
      GuardianReminders(offsets: offsets ?? this.offsets, students: students);

  Map<String, Object?> toJson() => {
    'offsets': [for (final o in offsets) o.toJson()],
  };
}

/// Avisos de días de clase del usuario (`GET me/notification-settings`).
class NotificationSettings {
  const NotificationSettings({
    this.instructor,
    this.guardian,
    this.options = const [],
    this.max = 3,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    final instructor = json['instructor'] as Map<String, dynamic>?;
    final guardian = json['guardian'] as Map<String, dynamic>?;
    return NotificationSettings(
      instructor: instructor == null
          ? null
          : InstructorReminders.fromJson(instructor),
      guardian: guardian == null ? null : GuardianReminders.fromJson(guardian),
      options: ((json['options'] as List?) ?? const [])
          .map((o) => ReminderOption.fromJson(o as Map<String, dynamic>))
          .toList(),
      max: json['max'] as int? ?? 3,
    );
  }

  /// Null si el usuario no dirige grupos.
  final InstructorReminders? instructor;

  /// Null si no tiene alumnos a cargo.
  final GuardianReminders? guardian;
  final List<ReminderOption> options;
  final int max;

  String labelOf(ReminderOffset offset) => options
      .firstWhere(
        (o) => o.offset == offset,
        orElse: () => ReminderOption(offset: offset, label: offset.key),
      )
      .label;

  NotificationSettings copyWith({
    InstructorReminders? instructor,
    GuardianReminders? guardian,
  }) => NotificationSettings(
    instructor: instructor ?? this.instructor,
    guardian: guardian ?? this.guardian,
    options: options,
    max: max,
  );
}

List<ReminderOffset> _offsets(Object? value) =>
    ((value as List?) ?? const []).map(ReminderOffset.fromJson).toList()
      ..sort();

const _days = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Cuándo llegan los avisos para una clase de ejemplo (por defecto, lunes 17:00),
/// con la regla nocturna: entre las 22:00 y las 7:00 sale a las 20:00 del día anterior.
/// "el domingo a las 20:00 y el lunes a las 14:00".
String describeReminderTimes(
  List<ReminderOffset> offsets, {
  int weekday = 1,
  int hour = 17,
  int minute = 0,
}) {
  // Un lunes cualquiera como base (solo importan el día y la hora).
  final classAt = DateTime(2026, 9, 28 + (weekday - 1), hour, minute);
  final times = <DateTime>{};
  for (final offset in offsets) {
    var at = offset.isEve
        ? DateTime(classAt.year, classAt.month, classAt.day - 1, 20)
        : classAt.subtract(Duration(minutes: offset.minutes));
    if (at.hour < 7) {
      at = DateTime(at.year, at.month, at.day - 1, 20);
    } else if (at.hour >= 22) {
      at = DateTime(at.year, at.month, at.day, 20);
    }
    times.add(at);
  }
  final sorted = times.toList()..sort();
  String two(int n) => n.toString().padLeft(2, '0');
  final parts = [
    for (final at in sorted)
      'el ${_days[at.weekday - 1]} a las ${at.hour}:${two(at.minute)}',
  ];
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} y ${parts.last}';
}
