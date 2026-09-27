import 'package:academia_app/features/attendance/data/attendance_repository.dart';
import 'package:academia_app/features/attendance/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'class_json.dart';

AttendanceRepository _repository(
  Map<String, Object? Function(RequestOptions)> routes, {
  List<RequestOptions>? requests,
}) => AttendanceRepository(
  fakeDio(routes, requests: requests),
  InMemorySessionStorage()..organization = 'jakare',
);

void main() {
  test('clases del día con fecha y contadores', () async {
    final requests = <RequestOptions>[];
    final repository = _repository({
      'GET /classes': (_) => {
        'data': [classJson()],
      },
    }, requests: requests);

    final classes = await repository.classes(DateTime(2026, 9, 28));

    expect(requests.single.queryParameters, {'date': '2026-09-28'});
    final session = classes.single;
    expect(session.group.name, 'Sub-10');
    expect(session.timeDescription, '17:00–18:30 · Cancha 1');
    expect(session.counts.notGoing, 1);
    expect(session.startsAtDateTime, DateTime(2026, 9, 28, 17));
    expect(session.hasStarted(DateTime(2026, 9, 28, 16, 59)), isFalse);
    expect(session.hasStarted(DateTime(2026, 9, 28, 17)), isTrue);
  });

  test('detalle con alumnos, marcas y respuestas', () async {
    final repository = _repository({
      'GET /classes/81': (_) => {
        'data': classJson(
          students: [
            classStudentJson(
              id: 12,
              name: 'Mateo Benítez',
              status: 'justificado',
              response: 'no_va',
            ),
            classStudentJson(id: 13, name: 'Lucas Ortiz'),
          ],
        ),
      },
    });

    final session = await repository.find(81);

    expect(session.editable, isTrue);
    expect(session.students.first.status, AttendanceStatus.justified);
    expect(session.students.first.guardianResponse, GuardianResponse.notGoing);
    expect(session.students.first.initials, 'MB');
    expect(session.students.last.status, isNull);
  });

  test('guarda todas las marcas de una vez', () async {
    final requests = <RequestOptions>[];
    final repository = _repository({
      'PUT /classes/81/attendance': (_) => {
        'data': classJson(attendanceTaken: true),
      },
    }, requests: requests);

    await repository.saveAttendance(
      81,
      {12: AttendanceStatus.justified, 13: AttendanceStatus.absent},
      notes: {12: 'Enfermo'},
    );

    expect(requests.single.data, {
      'marks': [
        {'student_id': 12, 'status': 'justificado', 'note': 'Enfermo'},
        {'student_id': 13, 'status': 'ausente', 'note': null},
      ],
    });
  });

  test('suspender manda el motivo', () async {
    final requests = <RequestOptions>[];
    final repository = _repository({
      'POST /classes/81/suspension': (_) => {
        'data': classJson(status: 'suspendida', suspensionReason: 'Lluvia'),
      },
    }, requests: requests);

    final session = await repository.suspend(81, 'Lluvia');

    expect(requests.single.data, {'reason': 'Lluvia'});
    expect(session.suspended, isTrue);
    expect(session.suspensionReason, 'Lluvia');
  });

  test('agenda del tutor y respuesta', () async {
    final requests = <RequestOptions>[];
    final repository = _repository({
      'GET /agenda': (_) => {
        'data': [agendaItemJson()],
      },
      'PUT /classes/81/students/12/response': (_) => {
        'data': agendaItemJson(response: 'no_va'),
      },
    }, requests: requests);

    final agenda = await repository.agenda();
    expect(agenda.single.studentFirstName, 'Mateo');
    expect(agenda.single.response, isNull);
    expect(agenda.single.classReminders, isNull);

    final item = await repository.respond(81, 12, going: false);
    expect(requests.last.data, {'going': false});
    expect(item.response, GuardianResponse.notGoing);
  });

  test('sin organización la agenda está vacía', () async {
    final repository = AttendanceRepository(
      fakeDio({}),
      InMemorySessionStorage(),
    );
    expect(await repository.agenda(), isEmpty);
  });

  test('asistencia del alumno en el mes y aviso de clases', () async {
    final requests = <RequestOptions>[];
    final repository = _repository({
      'GET /students/12/attendance': (_) => {
        'data': {
          'month': '2026-09',
          'present': 7,
          'absent': 1,
          'justified': 1,
          'rate': 78,
          'classes': [
            {...classJson(), 'attendance': 'presente'},
          ],
        },
      },
      'PUT /students/12/reminders': (_) => {
        'data': {'class_reminders': true},
      },
    }, requests: requests);

    final attendance = await repository.studentAttendance(
      12,
      DateTime(2026, 9, 27),
    );
    expect(requests.first.queryParameters, {'month': '2026-09'});
    expect(attendance.rate, 78);
    expect(attendance.classes.single.status, AttendanceStatus.present);

    expect(await repository.setReminders(12, enabled: true), isTrue);
    expect(requests.last.data, {'enabled': true});
  });

  test('grupos del técnico y asistencia del mes', () async {
    final repository = _repository({
      'GET /groups': (_) => {
        'data': [
          {
            'id': 3,
            'name': 'Sub-10',
            'program': {'id': 1, 'name': 'Fútbol'},
            'schedules': [
              {'weekday': 1, 'starts_at': '17:00', 'ends_at': '18:30'},
            ],
            'students_count': 21,
          },
        ],
      },
      'GET /groups/3': (_) => {
        'data': {
          'id': 3,
          'name': 'Sub-10',
          'program': {'id': 1, 'name': 'Fútbol'},
          'month': '2026-09',
          'classes': [classJson(attendanceTaken: true)],
          'students': [
            {
              'id': 12,
              'full_name': 'Mateo Benítez',
              'present': 7,
              'absent': 1,
              'justified': 1,
              'rate': 78,
            },
          ],
        },
      },
    });

    final groups = await repository.groups();
    expect(groups.single.studentsCount, 21);
    expect(groups.single.group.schedules.single.weekday, 1);

    final group = await repository.group(3, DateTime(2026, 9));
    expect(group.classes.single.attendanceTaken, isTrue);
    expect(group.students.single.rate, 78);
  });
}
