import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/features/attendance/data/attendance_sheet_controller.dart';
import 'package:academia_app/features/attendance/data/models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'class_json.dart';

ProviderContainer _container(
  Map<String, Object? Function(RequestOptions)> routes, {
  List<RequestOptions>? requests,
}) {
  final container = ProviderContainer(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        InMemorySessionStorage()
          ..token = 't'
          ..organization = 'jakare',
      ),
      offlineStoreProvider.overrideWithValue(InMemoryOfflineStore()),
      apiClientProvider.overrideWithValue(fakeDio(routes, requests: requests)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<AttendanceSheet> _load(ProviderContainer container) {
  container.listen(attendanceSheetProvider(81), (_, _) {});
  return container.read(attendanceSheetProvider(81).future);
}

void main() {
  test('arranca con todos presentes y justificados los que no van', () async {
    final container = _container({
      'GET /classes/81': (_) => {'data': classJson(students: threeStudents())},
    });

    final sheet = await _load(container);

    expect(sheet.statusOf(12), AttendanceStatus.justified);
    expect(sheet.notes[12], notGoingNote);
    expect(sheet.statusOf(13), AttendanceStatus.present);
    expect(sheet.statusOf(14), AttendanceStatus.present);
    expect(sheet.count(AttendanceStatus.present), 2);
    expect(sheet.dirty, isTrue, reason: 'todavía no se tomó');
    expect(sheet.touched, isFalse);
  });

  test('si ya se tomó, arranca con lo guardado', () async {
    final container = _container({
      'GET /classes/81': (_) => {
        'data': classJson(
          attendanceTaken: true,
          students: [
            classStudentJson(
              id: 12,
              name: 'Mateo Benítez',
              status: 'ausente',
              response: 'no_va',
            ),
          ],
        ),
      },
    });

    final sheet = await _load(container);

    expect(sheet.statusOf(12), AttendanceStatus.absent);
    expect(sheet.dirty, isFalse);
  });

  test(
    'un toque alterna presente y ausente; justificar guarda la nota',
    () async {
      final container = _container({
        'GET /classes/81': (_) => {
          'data': classJson(students: threeStudents()),
        },
      });
      await _load(container);
      final controller = container.read(attendanceSheetProvider(81).notifier);

      controller.toggle(14);
      expect(controller.state.value!.statusOf(14), AttendanceStatus.absent);
      controller.toggle(14);
      expect(controller.state.value!.statusOf(14), AttendanceStatus.present);

      controller.toggle(12); // justificado → presente
      expect(controller.state.value!.statusOf(12), AttendanceStatus.present);
      expect(controller.state.value!.notes.containsKey(12), isFalse);

      controller.setStatus(13, AttendanceStatus.justified, note: ' Enfermo ');
      expect(controller.state.value!.notes[13], 'Enfermo');
      expect(controller.state.value!.touched, isTrue);
    },
  );

  test('guarda y, si falla, conserva las marcas para reintentar', () async {
    var fail = true;
    final requests = <RequestOptions>[];
    final container = _container({
      'GET /classes/81': (_) => {'data': classJson(students: threeStudents())},
      'PUT /classes/81/attendance': (options) {
        if (fail) throw apiError(options, 503, {'message': 'Sin conexión.'});
        return {
          'data': classJson(
            attendanceTaken: true,
            students: [
              classStudentJson(
                id: 12,
                name: 'Mateo Benítez',
                status: 'justificado',
                response: 'no_va',
                note: notGoingNote,
              ),
              classStudentJson(id: 13, name: 'Lucas Ortiz', status: 'presente'),
              classStudentJson(
                id: 14,
                name: 'Tomás Villalba',
                status: 'ausente',
              ),
            ],
          ),
        };
      },
    }, requests: requests);
    await _load(container);
    final controller = container.read(attendanceSheetProvider(81).notifier);
    controller.toggle(14);

    expect(await controller.save(), isFalse);
    var sheet = controller.state.value!;
    expect(sheet.saveError, 'Sin conexión.');
    expect(sheet.statusOf(14), AttendanceStatus.absent);
    expect(sheet.dirty, isTrue);

    fail = false;
    expect(await controller.save(), isTrue);
    sheet = controller.state.value!;
    expect(sheet.saveError, isNull);
    expect(sheet.dirty, isFalse);
    expect(sheet.touched, isFalse);
    expect(sheet.statusOf(14), AttendanceStatus.absent);
    expect(requests.last.data, {
      'marks': [
        {'student_id': 12, 'status': 'justificado', 'note': notGoingNote},
        {'student_id': 13, 'status': 'presente', 'note': null},
        {'student_id': 14, 'status': 'ausente', 'note': null},
      ],
    });
  });

  test('no se puede marcar si no es editable', () async {
    final container = _container({
      'GET /classes/81': (_) => {
        'data': classJson(editable: false, students: threeStudents()),
      },
    });
    await _load(container);
    final controller = container.read(attendanceSheetProvider(81).notifier);

    controller.toggle(14);

    expect(controller.state.value!.statusOf(14), AttendanceStatus.present);
    expect(controller.state.value!.canEdit, isFalse);
  });

  test('suspender conserva la lista de alumnos', () async {
    final container = _container({
      'GET /classes/81': (_) => {'data': classJson(students: threeStudents())},
      'POST /classes/81/suspension': (_) => {
        'data': classJson(status: 'suspendida', suspensionReason: 'Lluvia'),
      },
    });
    await _load(container);
    final controller = container.read(attendanceSheetProvider(81).notifier);

    await controller.suspend('Lluvia');

    final sheet = controller.state.value!;
    expect(sheet.session.suspended, isTrue);
    expect(sheet.session.students, hasLength(3));
    expect(sheet.canEdit, isFalse);
  });
}
