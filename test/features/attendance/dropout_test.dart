import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/attendance/data/attendance_repository.dart';
import 'package:academia_app/features/attendance/presentation/group_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

/// "Dejó de venir": el técnico avisa al club desde su grupo; la baja la decide el club.
void main() {
  Map<String, Object?> groupJson({String? reportedOn}) => {
    'id': 3,
    'name': 'Sub-10',
    'program': {'id': 1, 'name': 'Fútbol'},
    'month': '2026-06',
    'classes': <Object>[],
    'students': [
      {
        'id': 9,
        'full_name': 'Matías Zárate',
        'present': 0,
        'absent': 4,
        'justified': 0,
        'rate': 0,
        'dropout_reported_on': reportedOn,
      },
    ],
  };

  test('avisar y deshacer el aviso', () async {
    final requests = <RequestOptions>[];
    final repository = AttendanceRepository(
      fakeDio({
        'POST /groups/3/students/9/dropout': (_) => {
          'data': {'dropout_reported_on': '2026-06-03'},
        },
        'DELETE /groups/3/students/9/dropout': (_) => null,
        'GET /groups/3': (_) => {'data': groupJson(reportedOn: '2026-06-03')},
      }, requests: requests),
      InMemorySessionStorage()..organization = 'jakare',
    );

    final on = await repository.reportDropout(3, 9, note: '  Se mudó  ');
    await repository.reportDropout(3, 9, note: ' ');
    await repository.cancelDropout(3, 9);
    final group = await repository.group(3, DateTime(2026, 6));

    expect(on, DateTime(2026, 6, 3));
    expect(requests[0].data, {'note': 'Se mudó'});
    expect(requests[1].data, isEmpty);
    expect(requests[2].method, 'DELETE');
    expect(group.students.single.dropoutReportedOn, DateTime(2026, 6, 3));
  });

  testWidgets('el técnico avisa desde el grupo con una nota', (tester) async {
    final requests = <RequestOptions>[];
    var reported = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(
            InMemorySessionStorage()
              ..token = 't'
              ..organization = 'jakare',
          ),
          apiClientProvider.overrideWithValue(
            fakeDio({
              'GET /groups/3': (_) => {
                'data': groupJson(reportedOn: reported ? '2026-06-03' : null),
              },
              'POST /groups/3/students/9/dropout': (_) {
                reported = true;
                return {
                  'data': {'dropout_reported_on': '2026-06-03'},
                };
              },
            }, requests: requests),
          ),
          todayProvider.overrideWithValue(DateTime(2026, 6, 3)),
        ],
        child: const MaterialApp(home: GroupScreen(id: 3)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Más opciones de Matías Zárate'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisar que dejó de venir'));
    await tester.pumpAndSettle();

    expect(find.text('¿Dejó de venir?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'No viene hace 3 semanas');
    await tester.tap(find.text('Avisar'));
    await tester.pumpAndSettle();

    final post = requests.singleWhere((r) => r.method == 'POST');
    expect(post.data, {'note': 'No viene hace 3 semanas'});
    expect(find.text('Listo: le avisamos al club.'), findsOneWidget);
    expect(
      find.text('Avisaste que dejó de venir el 03/06/2026'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Más opciones de Matías Zárate'));
    await tester.pumpAndSettle();
    expect(find.text('Sigue viniendo'), findsOneWidget);
  });
}
