import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/offline_store.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/attendance/data/attendance_outbox.dart';
import 'package:academia_app/features/attendance/data/attendance_repository.dart';
import 'package:academia_app/features/attendance/data/attendance_sheet_controller.dart';
import 'package:academia_app/features/attendance/data/models.dart';
import 'package:academia_app/features/attendance/presentation/class_attendance_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'class_json.dart';

/// API que se puede "desconectar": sin red, todas las rutas fallan como sin señal.
class _Api {
  bool online = true;
  final requests = <RequestOptions>[];
  Object? Function(RequestOptions)? onPut;

  Dio dio() => fakeDio({
    'GET /classes': (o) => _guard(
      o,
      () => {
        'data': [classJson()],
      },
    ),
    'GET /classes/81': (o) =>
        _guard(o, () => {'data': classJson(students: threeStudents())}),
    'PUT /classes/81/attendance': (o) => _guard(
      o,
      () =>
          onPut?.call(o) ??
          {'data': classJson(attendanceTaken: true, students: threeStudents())},
    ),
  }, requests: requests);

  Object? _guard(RequestOptions options, Object? Function() body) {
    if (!online) throw networkError(options);
    return body();
  }
}

ProviderContainer _container(_Api api, InMemoryOfflineStore store) {
  final container = ProviderContainer(
    overrides: [
      sessionStorageProvider.overrideWithValue(
        InMemorySessionStorage()
          ..token = 't'
          ..organization = 'jakare',
      ),
      apiClientProvider.overrideWithValue(api.dio()),
      offlineStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sin red, el repositorio devuelve lo guardado', () async {
    final api = _Api();
    final store = InMemoryOfflineStore();
    final repository = AttendanceRepository(
      api.dio(),
      InMemorySessionStorage()..organization = 'jakare',
      cache: store,
    );

    await repository.classes(DateTime(2026, 9, 28));
    await repository.precache([
      (await repository.classes(DateTime(2026, 9, 28))).single,
    ]);
    api.online = false;

    expect((await repository.classes(DateTime(2026, 9, 28))).single.id, 81);
    expect((await repository.find(81)).students, hasLength(3));
    await expectLater(
      repository.classes(DateTime(2026, 9, 29)),
      throwsA(isA<DioException>()),
    );
  });

  test('guarda sin señal, reemplaza por clase y envía al volver', () async {
    final api = _Api();
    final store = InMemoryOfflineStore();
    final container = _container(api, store);
    container.listen(attendanceSheetProvider(81), (_, _) {});
    await container.read(attendanceSheetProvider(81).future);
    final sheet = container.read(attendanceSheetProvider(81).notifier);

    api.online = false;
    sheet.toggle(14);
    expect(await sheet.save(), isTrue);
    var state = container.read(attendanceSheetProvider(81)).value!;
    expect(state.pendingSync, isTrue);
    expect(state.dirty, isFalse);

    sheet.toggle(13);
    await sheet.save();
    final outbox = await container.read(attendanceOutboxProvider.future);
    expect(outbox, hasLength(1), reason: 'una entrada por clase');
    expect(outbox[81]!.marks[13], AttendanceStatus.absent);
    expect(store.values.keys, contains('jakare:outbox'));

    expect(await container.read(attendanceOutboxProvider.notifier).flush(), 0);

    api.online = true;
    expect(await container.read(attendanceOutboxProvider.notifier).flush(), 1);
    expect(await container.read(attendanceOutboxProvider.future), isEmpty);
    expect(store.values.containsKey('jakare:outbox'), isFalse);
    final put = api.requests.lastWhere((r) => r.method == 'PUT');
    expect(((put.data as Map)['marks'] as List).map((m) => m['status']), [
      'justificado',
      'ausente',
      'ausente',
    ]);
    state = container.read(attendanceSheetProvider(81)).value!;
    expect(state.pendingSync, isFalse);
  });

  test('un rechazo de la API queda marcado y se puede descartar', () async {
    final api = _Api()
      ..onPut = (o) => throw apiError(o, 422, {
        'message': 'Esta clase ya no se puede corregir desde la app.',
      });
    final store = InMemoryOfflineStore();
    final container = _container(api, store);
    final outbox = container.read(attendanceOutboxProvider.notifier);
    await outbox.enqueue(81, {12: AttendanceStatus.present}, const {});

    await outbox.flush();
    final item = (await container.read(attendanceOutboxProvider.future))[81]!;
    expect(item.error, 'Esta clase ya no se puede corregir desde la app.');

    await outbox.discard(81);
    expect(await container.read(attendanceOutboxProvider.future), isEmpty);
  });

  test('la cola sobrevive a reabrir la app', () async {
    final store = InMemoryOfflineStore();
    final first = _container(_Api(), store);
    await first
        .read(attendanceOutboxProvider.notifier)
        .enqueue(81, {12: AttendanceStatus.justified}, {12: 'Viaje'});

    final second = _container(_Api(), store);
    final item = (await second.read(attendanceOutboxProvider.future))[81]!;
    expect(item.marks[12], AttendanceStatus.justified);
    expect(item.notes[12], 'Viaje');
  });

  testWidgets('la planilla muestra que quedó en el celular', (tester) async {
    final api = _Api();
    final store = InMemoryOfflineStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(
            InMemorySessionStorage()
              ..token = 't'
              ..organization = 'jakare',
          ),
          apiClientProvider.overrideWithValue(api.dio()),
          offlineStoreProvider.overrideWithValue(store),
          pushServiceProvider.overrideWithValue(FakePushService()),
          todayProvider.overrideWithValue(DateTime(2026, 9, 28)),
          nowProvider.overrideWithValue(DateTime(2026, 9, 28, 17, 30)),
        ],
        child: const MaterialApp(home: ClassAttendanceScreen(id: 81)),
      ),
    );
    await tester.pumpAndSettle();

    api.online = false;
    await tester.tap(find.text('Tomás Villalba'));
    await tester.pump();
    await tester.tap(find.text('Guardar asistencia (1 de 3)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('quedó guardada en el celular'), findsOneWidget);
    expect(
      find.text('Guardada en el celular · se envía al volver la señal'),
      findsOneWidget,
    );

    api.online = true;
    await tester.tap(find.text('Enviar ahora'));
    await tester.pumpAndSettle();

    expect(find.text('Asistencia enviada.'), findsOneWidget);
    expect(
      find.text('Guardada en el celular · se envía al volver la señal'),
      findsNothing,
    );
  });
}
