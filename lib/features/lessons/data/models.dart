import '../../../core/utils/format.dart';

/// "16:00" → minutos desde las 0:00 (null si no es una hora válida).
int? minutesOf(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Minutos desde las 0:00 → "16:00".
String timeOf(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

DateTime _date(Object? value) => DateTime.parse(value as String);

DateTime? _maybeDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

String _dayMonth(DateTime date) => '${date.day}/${date.month}';

enum BookingStatus {
  confirmed('confirmada'),
  attended('asistio'),
  absent('ausente'),
  cancelledByStudent('cancelada_alumno'),
  cancelledByTeacher('cancelada_profesor');

  const BookingStatus(this.value);

  final String value;

  static BookingStatus fromJson(Object? value) => BookingStatus.values
      .firstWhere((s) => s.value == value, orElse: () => confirmed);

  bool get isCancelled =>
      this == cancelledByStudent || this == cancelledByTeacher;

  String get label => switch (this) {
    confirmed => 'Confirmada',
    attended => 'Vino',
    absent => 'No vino',
    cancelledByStudent => 'Cancelada',
    cancelledByTeacher => 'Cancelada por el profesor',
  };
}

/// Cómo se paga una reserva: con una clase del paquete o como clase suelta.
enum BookingPayment {
  pack('paquete'),
  single('suelta');

  const BookingPayment(this.value);

  final String value;

  static BookingPayment fromJson(Object? value) =>
      value == pack.value ? pack : single;
}

enum PaymentMethod {
  cash('efectivo', 'Efectivo'),
  transfer('transferencia', 'Transferencia');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;
}

class LessonStudent {
  const LessonStudent({
    required this.id,
    required this.firstName,
    required this.fullName,
  });

  factory LessonStudent.fromJson(Map<String, dynamic> json) => LessonStudent(
    id: json['id'] as int,
    firstName: json['first_name'] as String,
    fullName: json['full_name'] as String,
  );

  final int id;
  final String firstName;
  final String fullName;
}

class TeacherRef {
  const TeacherRef({required this.id, required this.name});

  factory TeacherRef.fromJson(Map<String, dynamic> json) =>
      TeacherRef(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;

  String get firstName => name.split(' ').first;
}

/// Cargo de una clase suelta o de un paquete.
class LessonCharge {
  const LessonCharge({
    required this.id,
    required this.amount,
    required this.pending,
  });

  factory LessonCharge.fromJson(Map<String, dynamic> json) => LessonCharge(
    id: json['id'] as int,
    amount: json['amount'] as int,
    pending: json['pending'] as int,
  );

  final int id;
  final int amount;
  final int pending;

  bool get isPaid => pending == 0;
}

enum ClassPackStatus {
  pendingPayment('pendiente_pago'),
  active('activo'),
  finished('terminado'),
  expired('vencido');

  const ClassPackStatus(this.value);

  final String value;

  static ClassPackStatus fromJson(Object? value) => ClassPackStatus.values
      .firstWhere((s) => s.value == value, orElse: () => pendingPayment);
}

/// Faltando estos días o menos, el vencimiento se resalta.
const expiringSoonDays = 7;

/// Paquete de clases comprado por un alumno.
class ClassPack {
  const ClassPack({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.classes,
    required this.used,
    required this.reserved,
    required this.available,
    required this.price,
    required this.status,
    this.validDays,
    this.activatedOn,
    this.expiresOn,
    this.charge,
  });

  factory ClassPack.fromJson(Map<String, dynamic> json) => ClassPack(
    id: json['id'] as int,
    teacherId: json['teacher_id'] as int,
    studentId: json['student_id'] as int,
    classes: json['classes'] as int,
    used: json['used'] as int? ?? 0,
    reserved: json['reserved'] as int? ?? 0,
    available: json['available'] as int? ?? 0,
    price: json['price'] as int,
    validDays: json['valid_days'] as int?,
    status: ClassPackStatus.fromJson(json['status']),
    activatedOn: _maybeDate(json['activated_on']),
    expiresOn: _maybeDate(json['expires_on']),
    charge: json['charge'] == null
        ? null
        : LessonCharge.fromJson(json['charge'] as Map<String, dynamic>),
  );

  final int id;
  final int teacherId;
  final int studentId;
  final int classes;
  final int used;

  /// Reservas confirmadas que van a usar el paquete.
  final int reserved;

  /// Clases que todavía se pueden reservar con el paquete.
  final int available;
  final int price;
  final int? validDays;
  final ClassPackStatus status;
  final DateTime? activatedOn;
  final DateTime? expiresOn;
  final LessonCharge? charge;

  /// Clases sin usar (reservadas o no).
  int get remaining => classes - used;

  bool get isActive => status == ClassPackStatus.active;

  bool get isPending => status == ClassPackStatus.pendingPayment;

  /// Días hasta el vencimiento (0 = vence hoy); null si no vence.
  int? daysLeft(DateTime today) => expiresOn
      ?.difference(DateTime(today.year, today.month, today.day))
      .inDays;

  bool expiresSoon(DateTime today) {
    final days = daysLeft(today);
    return isActive && days != null && days <= expiringSoonDays;
  }

  /// La clase de ese día se puede pagar con el paquete.
  bool covers(DateTime date) =>
      isActive &&
      available > 0 &&
      (expiresOn == null || !date.isAfter(expiresOn!));

  /// "válido del 3/10 al 1/11", "sin vencimiento" o, pendiente, "vale 60 días desde que lo pagás".
  String get validity {
    if (activatedOn == null) return describeValidDays(validDays);
    if (expiresOn == null) return 'sin vencimiento';
    return 'válido del ${_dayMonth(activatedOn!)} al ${_dayMonth(expiresOn!)}';
  }

  /// Texto del vencimiento cuando falta poco: "Vence hoy", "Vence mañana", "Vence en 3 días".
  String? expiryWarning(DateTime today) {
    if (!expiresSoon(today)) return null;
    final days = daysLeft(today)!;
    return switch (days) {
      0 => 'Vence hoy',
      1 => 'Vence mañana',
      _ => 'Vence en $days días',
    };
  }
}

/// "vale 60 días desde que lo pagás" o "sin vencimiento".
String describeValidDays(int? days) => days == null
    ? 'sin vencimiento'
    : 'vale ${days == 1 ? '1 día' : '$days días'} desde que lo pagás';

/// Paquete que ofrece el profesor.
class LessonOffer {
  const LessonOffer({
    this.id,
    required this.classes,
    required this.price,
    this.validDays,
  });

  factory LessonOffer.fromJson(Map<String, dynamic> json) => LessonOffer(
    id: json['id'] as int?,
    classes: json['classes'] as int,
    price: json['price'] as int,
    validDays: json['valid_days'] as int?,
  );

  /// Null si todavía no se guardó.
  final int? id;
  final int classes;
  final int price;

  /// Null = sin vencimiento.
  final int? validDays;

  int get unitPrice => classes == 0 ? 0 : price ~/ classes;

  /// Lo que se ahorra frente a pagar cada clase suelta (0 si no hay ahorro).
  int savings(int singlePrice) =>
      (singlePrice * classes - price).clamp(0, 1 << 52);

  /// "4 clases · ₲ 100.000".
  String get title =>
      '${classes == 1 ? '1 clase' : '$classes clases'} · ${formatMoney(price)}';

  /// "₲ 25.000 c/u, ahorrás ₲ 40.000 · vale 60 días desde que lo pagás".
  String describe(int singlePrice) {
    final saved = savings(singlePrice);
    return [
      '${formatMoney(unitPrice)} c/u${saved > 0 ? ', ahorrás ${formatMoney(saved)}' : ''}',
      describeValidDays(validDays),
    ].join(' · ');
  }

  Map<String, Object?> toJson() => {
    'id': ?id,
    'classes': classes,
    'price': price,
    'valid_days': validDays,
  };
}

/// Reserva de una clase particular.
class Booking {
  const Booking({
    required this.id,
    required this.date,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.payment,
    required this.teacher,
    required this.student,
    this.price,
    this.classPackId,
    this.charge,
    this.canCancel = false,
    this.pack,
    this.credit = 0,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as int,
    date: _date(json['date']),
    startsAt: json['starts_at'] as String,
    endsAt: json['ends_at'] as String,
    status: BookingStatus.fromJson(json['status']),
    payment: BookingPayment.fromJson(json['payment']),
    price: json['price'] as int?,
    classPackId: json['class_pack_id'] as int?,
    teacher: TeacherRef.fromJson(json['teacher'] as Map<String, dynamic>),
    student: LessonStudent.fromJson(json['student'] as Map<String, dynamic>),
    charge: json['charge'] == null
        ? null
        : LessonCharge.fromJson(json['charge'] as Map<String, dynamic>),
    canCancel: json['can_cancel'] as bool? ?? false,
    pack: json['pack'] == null
        ? null
        : ClassPack.fromJson(json['pack'] as Map<String, dynamic>),
    credit: json['credit'] as int? ?? 0,
  );

  final int id;
  final DateTime date;

  /// "16:00".
  final String startsAt;
  final String endsAt;
  final BookingStatus status;
  final BookingPayment payment;

  /// Precio de la clase suelta.
  final int? price;
  final int? classPackId;
  final TeacherRef teacher;
  final LessonStudent student;

  /// Cargo de la clase suelta, una vez emitido.
  final LessonCharge? charge;
  final bool canCancel;

  /// Paquete que usa (solo en la vista del profesor).
  final ClassPack? pack;

  /// Saldo a favor de la familia del alumno (solo en la vista del profesor).
  final int credit;

  bool get usesPack => payment == BookingPayment.pack;

  DateTime get startsAtDateTime {
    final minutes = minutesOf(startsAt) ?? 0;
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  bool get isMarked =>
      status == BookingStatus.attended || status == BookingStatus.absent;

  /// Lo que falta cobrar de la clase suelta (sin cargo todavía: el precio menos el saldo a favor).
  int get amountDue {
    if (usesPack || status.isCancelled || status == BookingStatus.absent) {
      return 0;
    }
    final charge = this.charge;
    if (charge != null) return charge.pending;
    return ((price ?? 0) - credit).clamp(0, price ?? 0);
  }

  /// "Mar 6/10 · 16:00 a 17:00".
  String describe(DateTime today) =>
      '${formatShortDay(date, today)} · $startsAt a $endsAt';

  /// "Paquete 2 de 4", "Suelta · debe ₲ 35.000", "Suelta · pagada".
  String get paymentSummary {
    if (usesPack) {
      final pack = this.pack;
      return pack == null
          ? 'Paquete'
          : 'Paquete · le quedan ${pack.remaining} de ${pack.classes}';
    }
    if (status.isCancelled || status == BookingStatus.absent) return 'Suelta';
    final due = amountDue;
    if (due > 0) return 'Suelta · debe ${formatMoney(due)}';
    return charge == null
        ? 'Suelta · pagada por adelantado'
        : 'Suelta · pagada';
  }
}

/// Un alumno a cargo del usuario, con su paquete y su próxima clase con el profesor.
class TeacherStudent {
  const TeacherStudent({required this.student, this.pack, this.nextBooking});

  factory TeacherStudent.fromJson(Map<String, dynamic> json) => TeacherStudent(
    student: LessonStudent.fromJson(json['student'] as Map<String, dynamic>),
    pack: json['pack'] == null
        ? null
        : ClassPack.fromJson(json['pack'] as Map<String, dynamic>),
    nextBooking: json['next_booking'] == null
        ? null
        : Booking.fromJson(json['next_booking'] as Map<String, dynamic>),
  );

  final LessonStudent student;
  final ClassPack? pack;
  final Booking? nextBooking;

  /// Le queda una clase o ninguna (o el paquete venció): se ofrece comprar otro.
  bool get shouldOfferPack {
    final pack = this.pack;
    if (pack == null) return true;
    if (pack.isPending) return false;
    return !pack.isActive || pack.available <= 1;
  }
}

/// Profesor con clases particulares, tal como lo ve el alumno o el tutor.
class Teacher {
  const Teacher({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.singlePrice,
    this.photoUrl,
    this.packs = const [],
    this.students = const [],
  });

  factory Teacher.fromJson(Map<String, dynamic> json) => Teacher(
    id: json['id'] as int,
    name: json['name'] as String,
    photoUrl: json['photo_url'] as String?,
    durationMinutes: json['duration_minutes'] as int? ?? 60,
    singlePrice: json['single_price'] as int,
    packs: ((json['packs'] as List?) ?? const [])
        .map((p) => LessonOffer.fromJson(p as Map<String, dynamic>))
        .toList(),
    students: ((json['students'] as List?) ?? const [])
        .map((s) => TeacherStudent.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String name;
  final String? photoUrl;
  final int durationMinutes;
  final int singlePrice;
  final List<LessonOffer> packs;
  final List<TeacherStudent> students;

  String get firstName => name.split(' ').first;

  TeacherStudent? studentById(int id) {
    for (final s in students) {
      if (s.student.id == id) return s;
    }
    return null;
  }
}

/// Lo que se va a cobrar si se reserva esa fecha (lo mismo que decide la API).
class BookingPreview {
  const BookingPreview({required this.usesPack, required this.message});

  final bool usesPack;
  final String message;
}

BookingPreview previewBooking(Teacher teacher, ClassPack? pack, DateTime date) {
  if (pack != null && pack.covers(date)) {
    final left = pack.available - 1;
    return BookingPreview(
      usesPack: true,
      message:
          'Se descuenta 1 clase del paquete (te ${left == 1 ? 'quedaría 1' : 'quedarían $left'}).',
    );
  }
  final single =
      'Se cobra ${formatMoney(teacher.singlePrice)} el día de la clase.';
  if (pack != null &&
      pack.isActive &&
      pack.available > 0 &&
      pack.expiresOn != null &&
      date.isAfter(pack.expiresOn!)) {
    return BookingPreview(
      usesPack: false,
      message:
          'Tu paquete vence el ${_dayMonth(pack.expiresOn!)}; esta clase se cobra suelta. $single',
    );
  }
  return BookingPreview(usesPack: false, message: single);
}

class SlotDay {
  const SlotDay({required this.date, required this.times});

  factory SlotDay.fromJson(Map<String, dynamic> json) => SlotDay(
    date: _date(json['date']),
    times: List<String>.from(json['times'] as List),
  );

  final DateTime date;
  final List<String> times;
}

/// Horas libres de un profesor.
class Slots {
  const Slots({required this.durationMinutes, required this.days});

  factory Slots.fromJson(Map<String, dynamic> json) => Slots(
    durationMinutes: json['duration_minutes'] as int? ?? 60,
    days: ((json['days'] as List?) ?? const [])
        .map((d) => SlotDay.fromJson(d as Map<String, dynamic>))
        .where((d) => d.times.isNotEmpty)
        .toList(),
  );

  final int durationMinutes;
  final List<SlotDay> days;

  /// "16:00" → "17:00" según la duración.
  String endOf(String time) => timeOf((minutesOf(time) ?? 0) + durationMinutes);
}

class Bookings {
  const Bookings({this.upcoming = const [], this.past = const []});

  factory Bookings.fromJson(Map<String, dynamic> json) => Bookings(
    upcoming: ((json['upcoming'] as List?) ?? const [])
        .map((b) => Booking.fromJson(b as Map<String, dynamic>))
        .toList(),
    past: ((json['past'] as List?) ?? const [])
        .map((b) => Booking.fromJson(b as Map<String, dynamic>))
        .toList(),
  );

  final List<Booking> upcoming;
  final List<Booking> past;
}

/// Franja de disponibilidad del profesor (ej. lunes de 15:00 a 20:00).
class AvailabilityRange {
  const AvailabilityRange({
    required this.weekday,
    required this.startsAt,
    required this.endsAt,
  });

  factory AvailabilityRange.fromJson(Map<String, dynamic> json) =>
      AvailabilityRange(
        weekday: json['weekday'] as int,
        startsAt: json['starts_at'] as String,
        endsAt: json['ends_at'] as String,
      );

  /// 1 = lunes … 7 = domingo.
  final int weekday;
  final String startsAt;
  final String endsAt;

  AvailabilityRange copyWith({
    int? weekday,
    String? startsAt,
    String? endsAt,
  }) => AvailabilityRange(
    weekday: weekday ?? this.weekday,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
  );

  Map<String, Object?> toJson() => {
    'weekday': weekday,
    'starts_at': startsAt,
    'ends_at': endsAt,
  };

  /// Horas de inicio de las clases que entran en la franja.
  List<String> starts(int durationMinutes) {
    final from = minutesOf(startsAt);
    final to = minutesOf(endsAt);
    if (from == null || to == null || durationMinutes <= 0) return const [];
    return [
      for (var t = from; t + durationMinutes <= to; t += durationMinutes)
        timeOf(t),
    ];
  }
}

class MoneyAccountOption {
  const MoneyAccountOption({required this.id, required this.name});

  factory MoneyAccountOption.fromJson(Map<String, dynamic> json) =>
      MoneyAccountOption(id: json['id'] as int, name: json['name'] as String);

  final int id;
  final String name;
}

/// Ajustes de clases particulares del profesor (`me/lesson-profile`).
class LessonProfile {
  const LessonProfile({
    this.enabled = false,
    this.durationMinutes = 60,
    this.singlePrice = 0,
    this.minNoticeMinutes = 120,
    this.daysAhead = 30,
    this.moneyAccountId,
    this.moneyAccounts = const [],
    this.packs = const [],
    this.availability = const [],
  });

  factory LessonProfile.fromJson(Map<String, dynamic> json) => LessonProfile(
    enabled: json['enabled'] as bool? ?? false,
    durationMinutes: json['duration_minutes'] as int? ?? 60,
    singlePrice: json['single_price'] as int? ?? 0,
    minNoticeMinutes: json['min_notice_minutes'] as int? ?? 120,
    daysAhead: json['days_ahead'] as int? ?? 30,
    moneyAccountId: json['money_account_id'] as int?,
    moneyAccounts: ((json['money_accounts'] as List?) ?? const [])
        .map((a) => MoneyAccountOption.fromJson(a as Map<String, dynamic>))
        .toList(),
    packs: ((json['packs'] as List?) ?? const [])
        .map((p) => LessonOffer.fromJson(p as Map<String, dynamic>))
        .toList(),
    availability: ((json['availability'] as List?) ?? const [])
        .map((a) => AvailabilityRange.fromJson(a as Map<String, dynamic>))
        .toList(),
  );

  final bool enabled;
  final int durationMinutes;
  final int singlePrice;
  final int minNoticeMinutes;
  final int daysAhead;
  final int? moneyAccountId;
  final List<MoneyAccountOption> moneyAccounts;
  final List<LessonOffer> packs;
  final List<AvailabilityRange> availability;

  LessonProfile copyWith({
    bool? enabled,
    int? durationMinutes,
    int? singlePrice,
    int? minNoticeMinutes,
    int? daysAhead,
    int? moneyAccountId,
    List<LessonOffer>? packs,
    List<AvailabilityRange>? availability,
  }) => LessonProfile(
    enabled: enabled ?? this.enabled,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    singlePrice: singlePrice ?? this.singlePrice,
    minNoticeMinutes: minNoticeMinutes ?? this.minNoticeMinutes,
    daysAhead: daysAhead ?? this.daysAhead,
    moneyAccountId: moneyAccountId ?? this.moneyAccountId,
    moneyAccounts: moneyAccounts,
    packs: packs ?? this.packs,
    availability: availability ?? this.availability,
  );

  List<AvailabilityRange> rangesOf(int weekday) =>
      availability.where((r) => r.weekday == weekday).toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'duration_minutes': durationMinutes,
    'single_price': singlePrice,
    'min_notice_minutes': minNoticeMinutes,
    'days_ahead': daysAhead,
    'money_account_id': moneyAccountId,
    'packs': [for (final p in packs) p.toJson()],
    'availability': [for (final a in availability) a.toJson()],
  };

  /// Primer error de los ajustes (lo mismo que valida la API), o null.
  String? validate() {
    if (singlePrice <= 0) return 'Poné el precio de la clase suelta.';
    if (durationMinutes < 30 || durationMinutes > 180) {
      return 'La clase dura entre 30 minutos y 3 horas.';
    }
    for (final pack in packs) {
      if (pack.classes < 1) {
        return 'Un paquete tiene que tener al menos 1 clase.';
      }
      if (pack.price <= 0) return 'Poné el precio de cada paquete.';
      final days = pack.validDays;
      if (days != null && (days < 1 || days > 365)) {
        return 'La validez de un paquete va de 1 a 365 días.';
      }
    }
    final availabilityError = validateAvailability(availability);
    if (availabilityError != null) return availabilityError;
    if (enabled && availability.isEmpty) {
      return 'Cargá al menos una franja de disponibilidad.';
    }
    return null;
  }

  /// "lun 15:00, 16:00, 17:00 · mié 18:00": lo que van a ver los alumnos.
  String preview() {
    final parts = <String>[];
    for (var weekday = 1; weekday <= 7; weekday++) {
      final starts = [
        for (final range in rangesOf(weekday)) ...range.starts(durationMinutes),
      ];
      if (starts.isNotEmpty) {
        parts.add(
          '${weekdayShort(weekday).toLowerCase()} ${starts.join(', ')}',
        );
      }
    }
    return parts.join(' · ');
  }
}

/// Las franjas terminan después de empezar y no se superponen en el mismo día.
String? validateAvailability(List<AvailabilityRange> ranges) {
  for (var weekday = 1; weekday <= 7; weekday++) {
    final day = ranges.where((r) => r.weekday == weekday).toList();
    final spans = <(int, int)>[];
    for (final range in day) {
      final from = minutesOf(range.startsAt);
      final to = minutesOf(range.endsAt);
      if (from == null || to == null) return 'Revisá las horas de las franjas.';
      if (to <= from) {
        return 'El ${weekdayLong(weekday)}, una franja termina antes de empezar.';
      }
      spans.add((from, to));
    }
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    for (var i = 1; i < spans.length; i++) {
      if (spans[i].$1 < spans[i - 1].$2) {
        return 'El ${weekdayLong(weekday)} hay franjas que se superponen.';
      }
    }
  }
  return null;
}

/// Alumno del profesor con su saldo de clases y lo que debe.
class TeacherStudentSummary {
  const TeacherStudentSummary({
    required this.student,
    this.pack,
    this.debt = 0,
    this.credit = 0,
    this.lastBooking,
  });

  factory TeacherStudentSummary.fromJson(Map<String, dynamic> json) =>
      TeacherStudentSummary(
        student: LessonStudent.fromJson(
          json['student'] as Map<String, dynamic>,
        ),
        pack: json['pack'] == null
            ? null
            : ClassPack.fromJson(json['pack'] as Map<String, dynamic>),
        debt: json['debt'] as int? ?? 0,
        credit: json['credit'] as int? ?? 0,
        lastBooking: _maybeDate(json['last_booking']),
      );

  final LessonStudent student;
  final ClassPack? pack;
  final int debt;
  final int credit;
  final DateTime? lastBooking;

  /// Se puede extender: paquete activo o vencido con clases sin usar.
  bool get canExtend {
    final pack = this.pack;
    return pack != null &&
        pack.remaining > 0 &&
        (pack.isActive || pack.status == ClassPackStatus.expired);
  }
}

/// Resultado de un cobro del profesor.
class PaymentResult {
  const PaymentResult({
    required this.receiptNumber,
    required this.amount,
    required this.applied,
    required this.credit,
    required this.message,
    this.booking,
    this.pack,
  });

  factory PaymentResult.fromJson(Map<String, dynamic> json) => PaymentResult(
    receiptNumber: json['receipt_number'] as String,
    amount: json['amount'] as int,
    applied: json['applied'] as int? ?? 0,
    credit: json['credit'] as int? ?? 0,
    message: json['message'] as String,
    booking: json['booking'] == null
        ? null
        : Booking.fromJson(json['booking'] as Map<String, dynamic>),
    pack: json['pack'] == null
        ? null
        : ClassPack.fromJson(json['pack'] as Map<String, dynamic>),
  );

  final String receiptNumber;
  final int amount;
  final int applied;
  final int credit;
  final String message;
  final Booking? booking;
  final ClassPack? pack;
}

/// Texto del paquete para la tarjeta del alumno o tutor.
String describePack(ClassPack? pack, Teacher teacher, DateTime today) {
  if (pack == null) {
    return 'Clase suelta ${formatMoney(teacher.singlePrice)}';
  }
  return switch (pack.status) {
    ClassPackStatus.pendingPayment =>
      'Paquete de ${pack.classes} clases pendiente de pago: pagáselo al profesor o en la secretaría.',
    ClassPackStatus.active =>
      'Paquete: te ${pack.remaining == 1 ? 'queda 1' : 'quedan ${pack.remaining}'} de ${pack.classes}'
          '${pack.reserved > 0 ? ' (${pack.reserved == 1 ? '1 reservada' : '${pack.reserved} reservadas'})' : ''}'
          ' · ${pack.validity}',
    ClassPackStatus.finished =>
      'Usaste todas las clases del paquete. Clase suelta ${formatMoney(teacher.singlePrice)}',
    ClassPackStatus.expired =>
      'Tu paquete venció el ${_dayMonth(pack.expiresOn!)}${pack.remaining > 0 ? ' (no usaste ${pack.remaining == 1 ? '1 clase' : '${pack.remaining} clases'})' : ''}.',
  };
}
