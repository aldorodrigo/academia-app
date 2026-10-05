import '../../../core/utils/format.dart';
import '../../attendance/data/models.dart';
import '../../lessons/data/models.dart';
import '../../students/data/models.dart';

/// Qué es un evento del calendario: algo que pasa o un día sin clases.
enum EventKind {
  event('evento'),
  dayOff('sin_clase');

  const EventKind(this.value);

  final String value;

  static EventKind parse(Object? value) =>
      value == dayOff.value ? dayOff : event;
}

/// Lo que se puede ver en el calendario (filtro de la pantalla).
enum CalendarType {
  classes('classes', 'Clases'),
  bookings('bookings', 'Particulares'),
  events('events', 'Eventos');

  const CalendarType(this.value, this.label);

  final String value;
  final String label;
}

/// Marca de un día en la grilla del mes.
enum CalendarMarker { classScheduled, classOff, booking, event }

/// Hijo del tutor en una clase del calendario.
class CalendarStudent {
  const CalendarStudent({
    required this.id,
    required this.firstName,
    this.response,
    this.canRespond = false,
    this.attendance,
  });

  factory CalendarStudent.fromJson(Map<String, dynamic> json) =>
      CalendarStudent(
        id: json['id'] as int,
        firstName: json['first_name'] as String,
        response: GuardianResponse.parse(json['response']),
        canRespond: json['can_respond'] as bool? ?? false,
        attendance: AttendanceStatus.parse(json['attendance']),
      );

  final int id;
  final String firstName;
  final GuardianResponse? response;
  final bool canRespond;

  /// La asistencia ya tomada (null si todavía no).
  final AttendanceStatus? attendance;

  CalendarStudent withResponse(GuardianResponse response) => CalendarStudent(
    id: id,
    firstName: firstName,
    response: response,
    canRespond: canRespond,
    attendance: attendance,
  );
}

/// Clase de grupo en el calendario.
class CalendarClass {
  const CalendarClass({
    required this.session,
    this.students = const [],
    this.dayOffId,
    this.canTakeAttendance = false,
  });

  factory CalendarClass.fromJson(Map<String, dynamic> json) => CalendarClass(
    // Los alumnos del calendario son los hijos del tutor, no la lista de la clase.
    session: ClassSession.fromJson({...json, 'students': null}),
    students: _list(json['students'], CalendarStudent.fromJson),
    dayOffId: json['day_off_id'] as int?,
    canTakeAttendance: json['can_take_attendance'] as bool? ?? false,
  );

  final ClassSession session;

  /// Hijos del tutor en esta clase (vacío para el técnico).
  final List<CalendarStudent> students;

  /// Día sin clase que la suspendió.
  final int? dayOffId;
  final bool canTakeAttendance;

  /// "Mateo", "Mateo y Sofía", "Mateo, Sofía y Lucas".
  String get studentNames =>
      joinNames([for (final student in students) student.firstName]);
}

/// Reserva de clase particular en el calendario.
class CalendarBooking {
  const CalendarBooking({required this.booking, this.asTeacher = false});

  factory CalendarBooking.fromJson(Map<String, dynamic> json) =>
      CalendarBooking(
        booking: Booking.fromJson(json),
        asTeacher: json['as'] == 'teacher',
      );

  final Booking booking;

  /// La ve el profesor (si no, el alumno o su tutor).
  final bool asTeacher;
}

/// Grupo de un evento o de una vista previa (el programa puede no venir).
class EventGroup {
  const EventGroup({required this.id, required this.name, this.program});

  factory EventGroup.fromJson(Map<String, dynamic> json) => EventGroup(
    id: json['id'] as int,
    name: json['name'] as String,
    program: json['program'] is Map<String, dynamic>
        ? Program.fromJson(json['program'] as Map<String, dynamic>)
        : null,
  );

  final int id;
  final String name;
  final Program? program;
}

/// Clase que suspendió un día sin clase (o que suspendería, en la vista previa).
class AffectedClass {
  const AffectedClass({
    required this.date,
    required this.startsAt,
    required this.group,
    this.id,
    this.endsAt,
  });

  factory AffectedClass.fromJson(Map<String, dynamic> json) => AffectedClass(
    id: json['id'] as int?,
    date: DateTime.parse(json['date'] as String),
    startsAt: json['starts_at'] as String,
    endsAt: json['ends_at'] as String?,
    group: EventGroup.fromJson(json['group'] as Map<String, dynamic>),
  );

  final int? id;
  final DateTime date;
  final String startsAt;
  final String? endsAt;
  final EventGroup group;
}

/// Evento publicado (torneo, reunión…) o día sin clase.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.kind,
    required this.category,
    required this.categoryLabel,
    required this.title,
    required this.startsOn,
    required this.endsOn,
    this.description,
    this.startsAt,
    this.endsAt,
    this.venue,
    this.place,
    this.everyone = false,
    this.groups = const [],
    this.waiveCharge = false,
    this.cancelled = false,
    this.cancelReason,
    this.createdBy,
    this.createdAt,
    this.canEdit = false,
    this.canCancel = false,
    this.affectedClasses = const [],
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final audience = json['audience'] as Map<String, dynamic>? ?? const {};
    final startsOn = DateTime.parse(json['starts_on'] as String);
    return CalendarEvent(
      id: json['id'] as int,
      kind: EventKind.parse(json['kind']),
      category: json['category'] as String,
      categoryLabel: json['category_label'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      startsOn: startsOn,
      endsOn: json['ends_on'] == null
          ? startsOn
          : DateTime.parse(json['ends_on'] as String),
      startsAt: json['starts_at'] as String?,
      endsAt: json['ends_at'] as String?,
      venue: json['venue'] is Map<String, dynamic>
          ? Venue.fromJson(json['venue'] as Map<String, dynamic>)
          : null,
      place: json['place'] as String?,
      everyone: audience['everyone'] as bool? ?? false,
      groups: _list(audience['groups'], EventGroup.fromJson),
      waiveCharge: json['waive_charge'] as bool? ?? false,
      cancelled: json['cancelled'] as bool? ?? false,
      cancelReason: json['cancel_reason'] as String?,
      createdBy:
          (json['created_by'] as Map<String, dynamic>?)?['name'] as String?,
      // El día como lo manda la API (hora local de la organización).
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse((json['created_at'] as String).substring(0, 10)),
      canEdit: json['can_edit'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
      affectedClasses: _list(json['affected_classes'], AffectedClass.fromJson),
    );
  }

  final int id;
  final EventKind kind;

  /// "torneo", "feriado"… (el ícono sale de acá).
  final String category;
  final String categoryLabel;
  final String title;
  final String? description;
  final DateTime startsOn;
  final DateTime endsOn;

  /// "08:00"; null = todo el día.
  final String? startsAt;
  final String? endsAt;
  final Venue? venue;
  final String? place;

  /// Para todo el club (si no, [groups]).
  final bool everyone;
  final List<EventGroup> groups;
  final bool waiveCharge;
  final bool cancelled;
  final String? cancelReason;
  final String? createdBy;

  /// Día en que se publicó.
  final DateTime? createdAt;
  final bool canEdit;
  final bool canCancel;

  /// Solo en el detalle de un día sin clase.
  final List<AffectedClass> affectedClasses;

  bool get isDayOff => kind == EventKind.dayOff;

  bool get isAllDay => startsAt == null;

  bool get isMultiDay => _day(endsOn).isAfter(_day(startsOn));

  /// Cantidad de días que abarca.
  int get days => _day(endsOn).difference(_day(startsOn)).inDays + 1;

  /// La sede o el lugar escrito.
  String? get placeName => venue?.name ?? place;

  /// El evento abarca ese día.
  bool covers(DateTime day) {
    final date = _day(day);
    return !date.isBefore(_day(startsOn)) && !date.isAfter(_day(endsOn));
  }

  /// 1 el primer día, 2 el segundo…
  int dayNumber(DateTime day) =>
      _day(day).difference(_day(startsOn)).inDays + 1;

  /// "Para: todo el club" o "Para: Sub-10 y Sub-12".
  String get audienceDescription => everyone
      ? 'Todo el club'
      : joinNames([for (final group in groups) group.name]);

  /// "8:00 a 18:00", "Desde las 8:00" o "Todo el día".
  String get timeDescription {
    final start = startsAt;
    if (start == null) return 'Todo el día';
    final end = endsAt;
    return end == null ? 'Desde las $start' : '$start a $end';
  }

  /// "Sáb 11/10" o "Del sáb 11/10 al dom 12/10".
  String get dateDescription {
    final start = '${weekdayShort(startsOn.weekday)} ${_dayMonth(startsOn)}';
    if (!isMultiDay) return start;
    final end = '${weekdayShort(endsOn.weekday)} ${_dayMonth(endsOn)}';
    return 'Del ${start.toLowerCase()} al ${end.toLowerCase()}';
  }

  /// Hora para ordenar dentro del día (los de todo el día, primero).
  String get sortTime => startsAt ?? '00:00';
}

/// Una fila del día: clase, particular o evento.
sealed class CalendarEntry {
  const CalendarEntry();

  /// "17:00"; ordena las filas del día.
  String get sortTime;
}

class ClassEntry extends CalendarEntry {
  const ClassEntry(this.item);

  final CalendarClass item;

  @override
  String get sortTime => item.session.startsAt;
}

class BookingEntry extends CalendarEntry {
  const BookingEntry(this.item);

  final CalendarBooking item;

  @override
  String get sortTime => item.booking.startsAt;
}

class EventEntry extends CalendarEntry {
  const EventEntry(this.event);

  final CalendarEvent event;

  @override
  String get sortTime => event.sortTime;
}

/// Lo que devuelve `GET calendar` para un rango de días.
class CalendarRange {
  const CalendarRange({
    required this.from,
    required this.to,
    this.classes = const [],
    this.bookings = const [],
    this.events = const [],
  });

  factory CalendarRange.fromJson(Map<String, dynamic> json) => CalendarRange(
    from: DateTime.parse(json['from'] as String),
    to: DateTime.parse(json['to'] as String),
    classes: _list(json['classes'], CalendarClass.fromJson),
    bookings: _list(json['bookings'], CalendarBooking.fromJson),
    events: _list(json['events'], CalendarEvent.fromJson),
  );

  final DateTime from;
  final DateTime to;
  final List<CalendarClass> classes;
  final List<CalendarBooking> bookings;
  final List<CalendarEvent> events;

  /// El mismo rango con una clase reemplazada (después de responder "¿Lo llevás?").
  CalendarRange replaceClass(CalendarClass updated) => CalendarRange(
    from: from,
    to: to,
    classes: [
      for (final item in classes)
        item.session.id == updated.session.id ? updated : item,
    ],
    bookings: bookings,
    events: events,
  );

  /// Días sin clase (no cancelados) que abarcan ese día.
  List<CalendarEvent> daysOffOn(
    DateTime day, {
    Set<CalendarType> types = const {...CalendarType.values},
  }) {
    if (!types.contains(CalendarType.classes) &&
        !types.contains(CalendarType.events)) {
      return const [];
    }
    return [
      for (final event in events)
        if (event.isDayOff && !event.cancelled && event.covers(day)) event,
    ];
  }

  /// Filas del día ordenadas por hora (los días sin clase van aparte, en
  /// [daysOffOn], salvo los cancelados, que se muestran como evento tachado).
  List<CalendarEntry> entriesOn(
    DateTime day, {
    Set<CalendarType> types = const {...CalendarType.values},
  }) {
    final date = _day(day);
    final entries = <CalendarEntry>[
      if (types.contains(CalendarType.events))
        for (final event in events)
          if (event.covers(date) && (!event.isDayOff || event.cancelled))
            EventEntry(event),
      if (types.contains(CalendarType.classes))
        for (final item in classes)
          if (_day(item.session.date) == date) ClassEntry(item),
      if (types.contains(CalendarType.bookings))
        for (final item in bookings)
          if (_day(item.booking.date) == date) BookingEntry(item),
    ];
    entries.sort(
      (a, b) =>
          (minutesOf(a.sortTime) ?? 0).compareTo(minutesOf(b.sortTime) ?? 0),
    );
    return entries;
  }

  /// Marcas del día para la grilla (una por tipo, en orden fijo).
  List<CalendarMarker> markersOn(
    DateTime day, {
    Set<CalendarType> types = const {...CalendarType.values},
  }) {
    final entries = entriesOn(day, types: types);
    final classes = entries.whereType<ClassEntry>();
    return [
      if (classes.any((e) => !e.item.session.isOff))
        CalendarMarker.classScheduled,
      if (classes.any((e) => e.item.session.isOff)) CalendarMarker.classOff,
      if (entries.any((e) => e is BookingEntry)) CalendarMarker.booking,
      if (entries.any((e) => e is EventEntry)) CalendarMarker.event,
    ];
  }
}

/// Opciones para publicar (`GET events/options`).
class EventOptions {
  const EventOptions({
    this.canTargetOrganization = false,
    this.groups = const [],
    this.venues = const [],
    this.categories = const {},
  });

  factory EventOptions.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] as Map<String, dynamic>? ?? const {};
    return EventOptions(
      canTargetOrganization: json['can_target_organization'] as bool? ?? false,
      groups: _list(json['groups'], EventGroup.fromJson),
      venues: _list(json['venues'], Venue.fromJson),
      categories: {
        for (final kind in EventKind.values)
          kind: _list(categories[kind.value], EventCategoryOption.fromJson),
      },
    );
  }

  final bool canTargetOrganization;
  final List<EventGroup> groups;
  final List<Venue> venues;
  final Map<EventKind, List<EventCategoryOption>> categories;

  /// Grupos por disciplina, en el orden en que vienen.
  Map<String, List<EventGroup>> get groupsByProgram {
    final result = <String, List<EventGroup>>{};
    for (final group in groups) {
      result.putIfAbsent(group.program?.name ?? '', () => []).add(group);
    }
    return result;
  }
}

class EventCategoryOption {
  const EventCategoryOption({required this.value, required this.label});

  factory EventCategoryOption.fromJson(Map<String, dynamic> json) =>
      EventCategoryOption(
        value: json['value'] as String,
        label: json['label'] as String,
      );

  final String value;
  final String label;
}

/// Lo que se publica (`POST events` / `PUT events/{id}`).
class EventDraft {
  const EventDraft({
    required this.kind,
    this.category,
    this.title = '',
    this.startsOn,
    this.endsOn,
    this.allDay = true,
    this.startsAt,
    this.endsAt,
    this.venueId,
    this.place = '',
    this.description = '',
    this.forEveryone = false,
    this.groupIds = const {},
    this.waiveCharge = true,
  });

  /// Para editar un evento ya publicado.
  factory EventDraft.fromEvent(CalendarEvent event) => EventDraft(
    kind: event.kind,
    category: event.category,
    title: event.title,
    startsOn: event.startsOn,
    endsOn: event.endsOn,
    allDay: event.isAllDay,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    venueId: event.venue?.id,
    place: event.place ?? '',
    description: event.description ?? '',
    forEveryone: event.everyone,
    groupIds: {for (final group in event.groups) group.id},
    waiveCharge: event.waiveCharge,
  );

  final EventKind kind;
  final String? category;
  final String title;
  final DateTime? startsOn;

  /// Null = un solo día.
  final DateTime? endsOn;
  final bool allDay;
  final String? startsAt;
  final String? endsAt;
  final int? venueId;

  /// Lugar escrito ("Otro lugar…"), si no se eligió una sede.
  final String place;
  final String description;
  final bool forEveryone;
  final Set<int> groupIds;

  /// "No cobrar las clases suspendidas" (solo día sin clase).
  final bool waiveCharge;

  bool get isDayOff => kind == EventKind.dayOff;

  EventDraft copyWith({
    String? category,
    String? title,
    DateTime? startsOn,
    DateTime? Function()? endsOn,
    bool? allDay,
    String? Function()? startsAt,
    String? Function()? endsAt,
    int? Function()? venueId,
    String? place,
    String? description,
    bool? forEveryone,
    Set<int>? groupIds,
    bool? waiveCharge,
  }) => EventDraft(
    kind: kind,
    category: category ?? this.category,
    title: title ?? this.title,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn == null ? this.endsOn : endsOn(),
    allDay: allDay ?? this.allDay,
    startsAt: startsAt == null ? this.startsAt : startsAt(),
    endsAt: endsAt == null ? this.endsAt : endsAt(),
    venueId: venueId == null ? this.venueId : venueId(),
    place: place ?? this.place,
    description: description ?? this.description,
    forEveryone: forEveryone ?? this.forEveryone,
    groupIds: groupIds ?? this.groupIds,
    waiveCharge: waiveCharge ?? this.waiveCharge,
  );

  Map<String, Object?> toJson() {
    final start = startsOn;
    final end = endsOn;
    final timed = !isDayOff && !allDay;
    final place = this.place.trim();
    final description = this.description.trim();
    return {
      'kind': kind.value,
      'category': category,
      'title': title.trim(),
      'starts_on': start == null ? null : apiDate(start),
      'ends_on': end == null ? null : apiDate(end),
      'starts_at': timed ? startsAt : null,
      'ends_at': timed ? endsAt : null,
      'venue_id': isDayOff ? null : venueId,
      'place': isDayOff || venueId != null || place.isEmpty ? null : place,
      'description': description.isEmpty ? null : description,
      'for_everyone': forEveryone,
      'group_ids': forEveryone ? const <int>[] : groupIds.toList(),
      if (isDayOff) 'waive_charge': waiveCharge,
    };
  }
}

/// Lo que pasaría al publicar (`POST events/preview`).
class EventPreview {
  const EventPreview({
    this.families = 0,
    this.instructors = 0,
    this.suspended,
    this.skippedStarted = 0,
    this.alreadyOff = 0,
    this.items = const [],
    this.canWaiveCharge = false,
  });

  factory EventPreview.fromJson(Map<String, dynamic> json) {
    final recipients = json['recipients'] as Map<String, dynamic>? ?? const {};
    final classes = json['classes'] as Map<String, dynamic>?;
    return EventPreview(
      families: recipients['families'] as int? ?? 0,
      instructors: recipients['instructors'] as int? ?? 0,
      suspended: classes?['suspended'] as int?,
      skippedStarted: classes?['skipped_started'] as int? ?? 0,
      alreadyOff: classes?['already_off'] as int? ?? 0,
      items: _list(classes?['items'], AffectedClass.fromJson),
      canWaiveCharge: json['can_waive_charge'] as bool? ?? false,
    );
  }

  final int families;
  final int instructors;

  /// Clases que se suspenden (null en un evento).
  final int? suspended;
  final int skippedStarted;
  final int alreadyOff;
  final List<AffectedClass> items;
  final bool canWaiveCharge;

  /// "Les llega a 48 familias y 3 técnicos."
  String recipientsText({String instructorTerm = 'técnico'}) {
    final parts = [
      if (families > 0) _count(families, 'familia', 'familias'),
      if (instructors > 0)
        _count(
          instructors,
          instructorTerm.toLowerCase(),
          _plural(instructorTerm),
        ),
    ];
    if (parts.isEmpty) return 'Por ahora no le llega a nadie.';
    return 'Les llega a ${joinNames(parts)}.';
  }

  /// "Se suspenden 12 clases. 2 ya empezaron y no se tocan."
  String? get classesText {
    final count = suspended;
    if (count == null) return null;
    final text = switch (count) {
      0 => 'No hay clases para suspender.',
      1 => 'Se suspende 1 clase.',
      _ => 'Se suspenden $count clases.',
    };
    final skipped = switch (skippedStarted) {
      0 => '',
      1 => ' 1 ya empezó y no se toca.',
      _ => ' $skippedStarted ya empezaron y no se tocan.',
    };
    return '$text$skipped';
  }
}

/// Link personal para suscribirse al calendario desde Google, Apple u otros.
class CalendarFeed {
  const CalendarFeed({
    required this.url,
    required this.webcalUrl,
    required this.googleUrl,
  });

  factory CalendarFeed.fromJson(Map<String, dynamic> json) => CalendarFeed(
    url: json['url'] as String,
    webcalUrl: json['webcal_url'] as String,
    googleUrl: json['google_url'] as String,
  );

  /// `https://…/calendario/{token}.ics` (para copiar: Outlook y otros).
  final String url;

  /// `webcal://…`: el Calendario de iPhone o Mac ofrece suscribirse.
  final String webcalUrl;

  /// Google Calendar con el diálogo para agregar el calendario.
  final String googleUrl;
}

/// "Mateo", "Mateo y Sofía", "Mateo, Sofía y Lucas".
String joinNames(List<String> names) {
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  return '${names.take(names.length - 1).join(', ')} y ${names.last}';
}

/// Los 42 días (6 semanas, de lunes a domingo) que muestra la grilla de un mes.
({DateTime from, DateTime to}) gridRange(DateTime month) {
  final first = DateTime(month.year, month.month);
  final from = DateTime(first.year, first.month, 1 - (first.weekday - 1));
  return (from: from, to: DateTime(from.year, from.month, from.day + 41));
}

/// Lunes de la semana de [day].
DateTime weekStart(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

String _count(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

String _plural(String word) {
  final lower = word.toLowerCase();
  if (lower.endsWith('or')) return '${lower}es';
  return lower.endsWith('s') ? lower : '${lower}s';
}

String _dayMonth(DateTime date) => '${date.day}/${date.month}';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) =>
    ((value as List?) ?? const [])
        .map((e) => parse(e as Map<String, dynamic>))
        .toList();
