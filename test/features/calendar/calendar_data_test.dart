import 'package:academia_app/features/attendance/data/models.dart';
import 'package:academia_app/features/calendar/data/calendar_repository.dart';
import 'package:academia_app/features/calendar/data/event_form_controller.dart';
import 'package:academia_app/features/calendar/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'calendar_json.dart';

CalendarRepository _repository(
  Map<String, Object? Function(RequestOptions)> routes, {
  List<RequestOptions>? requests,
}) => CalendarRepository(
  fakeDio(routes, requests: requests),
  InMemorySessionStorage()..organization = 'jakare',
);

CalendarRange _range({
  List<Map<String, Object?>> classes = const [],
  List<Map<String, Object?>> bookings = const [],
  List<Map<String, Object?>> events = const [],
}) => CalendarRange.fromJson(
  calendarJson(classes: classes, bookings: bookings, events: events)['data']
      as Map<String, dynamic>,
);

void main() {
  group('grilla del mes', () {
    test('6 semanas de lunes a domingo', () {
      final range = gridRange(DateTime(2026, 10));
      expect(range.from, DateTime(2026, 9, 28));
      expect(range.to, DateTime(2026, 11, 8));
    });

    test('mes que empieza en lunes y cambio de año', () {
      expect(gridRange(DateTime(2026, 6)).from, DateTime(2026, 6));
      final january = gridRange(DateTime(2027));
      expect(january.from, DateTime(2026, 12, 28));
      expect(january.to, DateTime(2027, 2, 7));
    });

    test('lunes de la semana', () {
      expect(weekStart(DateTime(2026, 10, 4)), DateTime(2026, 9, 28));
      expect(weekStart(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });
  });

  group('días del calendario', () {
    test('filas ordenadas por hora y filtradas por tipo', () {
      final range = _range(
        classes: [calendarClassJson(date: '2026-10-11')],
        bookings: [calendarBookingJson(date: '2026-10-11')],
        events: [eventJson()],
      );
      final day = DateTime(2026, 10, 11);

      final entries = range.entriesOn(day);
      expect(entries.map((e) => e.runtimeType), [
        EventEntry,
        BookingEntry,
        ClassEntry,
      ]);
      expect(range.entriesOn(day, types: {CalendarType.events}), hasLength(1));
      expect(range.markersOn(day), [
        CalendarMarker.classScheduled,
        CalendarMarker.booking,
        CalendarMarker.event,
      ]);
      expect(range.entriesOn(DateTime(2026, 10, 12)), isEmpty);
    });

    test('evento de varios días y día sin clase aparte', () {
      final range = _range(
        classes: [
          calendarClassJson(
            date: '2026-10-08',
            status: 'suspendida',
            suspensionReason: 'Vacaciones',
            dayOffId: 9,
          ),
        ],
        events: [
          dayOffJson(startsOn: '2026-10-07', endsOn: '2026-10-09'),
          dayOffJson(id: 10, startsOn: '2026-10-08', cancelled: true),
        ],
      );
      final day = DateTime(2026, 10, 8);

      final dayOff = range.daysOffOn(day).single;
      expect(dayOff.id, 9);
      expect(dayOff.dayNumber(day), 2);
      expect(dayOff.days, 3);
      expect(dayOff.dateDescription, 'Del mié 7/10 al vie 9/10');
      // El cancelado no suspende: se ve como evento tachado.
      final entries = range.entriesOn(day);
      expect(entries.whereType<EventEntry>().single.event.id, 10);
      expect(range.markersOn(day), [
        CalendarMarker.classOff,
        CalendarMarker.event,
      ]);
      expect(range.daysOffOn(DateTime(2026, 10, 10)), isEmpty);
      expect(range.daysOffOn(day, types: {CalendarType.bookings}), isEmpty);
    });
  });

  group('repositorio', () {
    test(
      'pide el rango con los filtros y separa los hijos de la clase',
      () async {
        final requests = <RequestOptions>[];
        final repository = _repository({
          'GET /calendar': (_) => calendarJson(
            classes: [
              calendarClassJson(
                students: [
                  calendarStudentJson(response: 'va'),
                  calendarStudentJson(
                    id: 13,
                    firstName: 'Sofía',
                    attendance: 'presente',
                  ),
                ],
              ),
            ],
            bookings: [calendarBookingJson(as: 'teacher')],
            events: [eventJson()],
          ),
        }, requests: requests);

        final range = await repository.calendar(
          DateTime(2026, 9, 28),
          DateTime(2026, 11, 8),
          studentId: 12,
          types: {CalendarType.classes, CalendarType.events},
        );

        expect(requests.single.queryParameters, {
          'from': '2026-09-28',
          'to': '2026-11-08',
          'student_id': 12,
          'types': 'classes,events',
        });
        final item = range.classes.single;
        expect(item.session.group.name, 'Sub-10');
        expect(item.session.students, isEmpty);
        expect(item.studentNames, 'Mateo y Sofía');
        expect(item.students.first.response, GuardianResponse.going);
        expect(item.students.last.attendance, AttendanceStatus.present);
        expect(range.bookings.single.asTeacher, isTrue);
        final event = range.events.single;
        expect(event.title, 'Apertura Sub-10');
        expect(event.placeName, 'Club Olimpia');
        expect(event.timeDescription, '08:00 a 18:00');
        expect(event.audienceDescription, 'Sub-10');
      },
    );

    test('sin organización no pide nada', () async {
      final repository = CalendarRepository(
        fakeDio({}),
        InMemorySessionStorage(),
      );
      final range = await repository.calendar(
        DateTime(2026, 9, 28),
        DateTime(2026, 11, 8),
      );
      expect(range.classes, isEmpty);
    });

    test('publica un día sin clase con lo que pide la API', () async {
      final requests = <RequestOptions>[];
      final repository = _repository({
        'POST /events': (_) => {'data': dayOffJson()},
      }, requests: requests);

      final event = await repository.publish(
        EventDraft(
          kind: EventKind.dayOff,
          category: 'feriado',
          title: ' Día del Docente ',
          startsOn: DateTime(2026, 10, 7),
          startsAt: '08:00',
          place: 'No va',
          groupIds: {3, 4},
        ),
      );

      expect(event.isDayOff, isTrue);
      expect(requests.single.data, {
        'kind': 'sin_clase',
        'category': 'feriado',
        'title': 'Día del Docente',
        'starts_on': '2026-10-07',
        'ends_on': null,
        'starts_at': null,
        'ends_at': null,
        'venue_id': null,
        'place': null,
        'description': null,
        'for_everyone': false,
        'group_ids': [3, 4],
        'waive_charge': true,
      });
    });

    test('edita sin cambiar el tipo, avisa y cancela con motivo', () async {
      final requests = <RequestOptions>[];
      final repository = _repository({
        'PUT /events/7': (_) => {'data': eventJson()},
        'POST /events/7/cancel': (_) => {
          'data': eventJson(cancelled: true, cancelReason: 'Lluvia'),
        },
      }, requests: requests);

      await repository.update(
        7,
        EventDraft(
          kind: EventKind.event,
          category: 'torneo',
          title: 'Apertura',
          startsOn: DateTime(2026, 10, 11),
          allDay: false,
          startsAt: '08:00',
          endsAt: '18:00',
          place: 'Club Olimpia',
          forEveryone: true,
          groupIds: {3},
        ),
        notify: false,
      );
      final put = requests.first.data as Map;
      expect(put.containsKey('kind'), isFalse);
      expect(put['notify'], isFalse);
      expect(put['starts_at'], '08:00');
      expect(put['place'], 'Club Olimpia');
      expect(put['group_ids'], isEmpty);
      expect(put.containsKey('waive_charge'), isFalse);

      final cancelled = await repository.cancel(7, reason: '  ');
      expect(requests.last.data, {'reason': null});
      expect(cancelled.cancelled, isTrue);
    });

    test('vista previa con clases y opciones por disciplina', () async {
      final requests = <RequestOptions>[];
      final repository = _repository({
        'POST /events/preview': (_) =>
            previewJson(suspended: 12, skippedStarted: 2, canWaiveCharge: true),
        'GET /events/options': (_) => eventOptionsJson(),
      }, requests: requests);

      final preview = await repository.preview(
        EventDraft(kind: EventKind.dayOff, startsOn: DateTime(2026, 10, 7)),
        eventId: 9,
      );
      expect((requests.single.data as Map)['event_id'], 9);
      expect(preview.recipientsText(), 'Les llega a 48 familias y 3 técnicos.');
      expect(
        preview.classesText,
        'Se suspenden 12 clases. 2 ya empezaron y no se tocan.',
      );
      expect(preview.items.single.group.name, 'Sub-10');

      final options = await repository.options();
      expect(options.groupsByProgram.keys, ['Fútbol', 'Natación']);
      expect(options.categories[EventKind.dayOff]!.first.label, 'Feriado');
    });
  });

  group('validación', () {
    final today = DateTime(2026, 10, 5);

    test('pide tipo, título, fecha y para quién', () {
      expect(
        validateEventDraft(const EventDraft(kind: EventKind.event), today),
        {
          'category': 'Elegí el tipo.',
          'title': 'Escribí un título.',
          'starts_on': 'Elegí la fecha.',
          'group_ids': 'Elegí para quién es.',
        },
      );
    });

    test('fechas y horas', () {
      final draft = EventDraft(
        kind: EventKind.event,
        category: 'torneo',
        title: 'Apertura',
        startsOn: DateTime(2026, 10, 11),
        endsOn: DateTime(2026, 10, 10),
        allDay: false,
        startsAt: '18:00',
        endsAt: '08:00',
        forEveryone: true,
      );
      expect(validateEventDraft(draft, today), {
        'ends_on': 'La fecha de fin no puede ser anterior al inicio.',
        'ends_at': 'La hora de fin tiene que ser posterior al inicio.',
      });
      expect(
        validateEventDraft(
          draft.copyWith(
            endsOn: () => DateTime(2027, 1, 11),
            startsAt: () => null,
          ),
          today,
        ),
        {'ends_on': 'Elegí hasta 92 días.', 'starts_at': 'Elegí la hora.'},
      );
    });

    test('un día sin clase no empieza antes de hoy', () {
      final draft = EventDraft(
        kind: EventKind.dayOff,
        category: 'feriado',
        title: 'Feriado',
        startsOn: DateTime(2026, 10, 4),
        groupIds: {3},
      );
      expect(validateEventDraft(draft, today), {
        'starts_on': 'Un día sin clase no puede empezar antes de hoy.',
      });
      expect(
        validateEventDraft(draft.copyWith(startsOn: today), today),
        isEmpty,
      );
    });
  });
}
