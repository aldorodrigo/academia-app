import 'package:academia_app/core/api/api_client.dart';
import 'package:academia_app/core/push/push_service.dart';
import 'package:academia_app/core/storage/session_storage.dart';
import 'package:academia_app/core/utils/clock.dart';
import 'package:academia_app/features/notifications/data/models.dart';
import 'package:academia_app/features/notifications/data/notification_settings_repository.dart';
import 'package:academia_app/features/notifications/presentation/notification_settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';

const _options = [
  {'value': 'eve', 'label': 'El día anterior a las 20:00'},
  {'value': 360, 'label': '6 h antes'},
  {'value': 180, 'label': '3 h antes'},
  {'value': 120, 'label': '2 h antes'},
  {'value': 60, 'label': '1 h antes'},
  {'value': 30, 'label': '30 min antes'},
];

Map<String, Object?> settingsJson({
  Map<String, Object?>? instructor = const {
    'enabled': true,
    'offsets': [120],
  },
  List<Object> guardianOffsets = const [180],
  bool childEnabled = true,
  bool guardian = true,
}) => {
  'data': {
    'instructor': instructor,
    'guardian': guardian
        ? {
            'offsets': guardianOffsets,
            'students': [
              {'id': 12, 'first_name': 'Mateo', 'enabled': childEnabled},
            ],
          }
        : null,
    'options': _options,
    'max': 3,
  },
};

void main() {
  test('ejemplo de cuándo llegan los avisos, con la regla nocturna', () {
    expect(
      describeReminderTimes(const [ReminderOffset('180')]),
      'el lunes a las 14:00',
    );
    expect(
      describeReminderTimes(const [ReminderOffset.eve, ReminderOffset('180')]),
      'el domingo a las 20:00 y el lunes a las 14:00',
    );
    // Clase a las 8:00: "3 h antes" caería a las 5:00 → domingo 20:00 (una sola vez con "eve").
    expect(
      describeReminderTimes(const [
        ReminderOffset.eve,
        ReminderOffset('180'),
        ReminderOffset('30'),
      ], hour: 8),
      'el domingo a las 20:00 y el lunes a las 7:30',
    );
  });

  test('los avisos se ordenan del más temprano al más cercano', () {
    final offsets = [
      const ReminderOffset('30'),
      ReminderOffset.eve,
      const ReminderOffset('180'),
    ]..sort();
    expect(offsets.map((o) => o.key), ['eve', '180', '30']);
    expect(offsets.map((o) => o.toJson()), ['eve', 180, 30]);
  });

  test('el repositorio lee y guarda', () async {
    final requests = <RequestOptions>[];
    final repository = NotificationSettingsRepository(
      fakeDio({
        'GET /me/notification-settings': (_) => settingsJson(),
        'PUT /me/notification-settings': (_) => settingsJson(),
      }, requests: requests),
      InMemorySessionStorage(),
    );

    final settings = await repository.get();
    expect(settings.instructor!.offsets.single.minutes, 120);
    expect(settings.guardian!.students.single.firstName, 'Mateo');
    expect(settings.labelOf(ReminderOffset.eve), 'El día anterior a las 20:00');

    await repository.save(
      guardian: const GuardianReminders(
        offsets: [ReminderOffset.eve, ReminderOffset('60')],
      ),
    );
    expect(requests.last.data, {
      'guardian': {
        'offsets': ['eve', 60],
      },
    });
  });

  group('pantalla', () {
    Widget app(
      Map<String, Object? Function(RequestOptions)> routes, {
      List<RequestOptions>? requests,
      PushService? push,
    }) => ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(
          InMemorySessionStorage()
            ..token = 't'
            ..organization = 'jakare',
        ),
        apiClientProvider.overrideWithValue(
          fakeDio(routes, requests: requests),
        ),
        todayProvider.overrideWithValue(DateTime(2026, 9, 28)),
        pushServiceProvider.overrideWithValue(push ?? FakePushService()),
      ],
      child: const MaterialApp(home: NotificationSettingsScreen()),
    );

    testWidgets('técnico y tutor ven sus avisos con el ejemplo', (
      tester,
    ) async {
      await tester.pumpWidget(
        app({'GET /me/notification-settings': (_) => settingsJson()}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis clases'), findsOneWidget);
      expect(find.text('2 h antes'), findsOneWidget);
      expect(find.text('Días de clase de mis hijos'), findsOneWidget);
      expect(find.text('3 h antes'), findsOneWidget);
      expect(
        find.text(
          'Por ejemplo, para una clase del lunes a las 17:00 te avisamos '
          'el lunes a las 14:00.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('agrega un aviso y lo guarda', (tester) async {
      final requests = <RequestOptions>[];
      var guardianOffsets = <Object>[180];
      await tester.pumpWidget(
        app({
          'GET /me/notification-settings': (_) =>
              settingsJson(instructor: null, guardianOffsets: guardianOffsets),
          'PUT /me/notification-settings': (options) {
            guardianOffsets = List<Object>.from(
              ((options.data as Map)['guardian'] as Map)['offsets'] as List,
            );
            return settingsJson(
              instructor: null,
              guardianOffsets: guardianOffsets,
            );
          },
        }, requests: requests),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis clases'), findsNothing);
      await tester.tap(find.text('Agregar aviso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('El día anterior a las 20:00'));
      await tester.pumpAndSettle();

      expect(requests.last.data, {
        'guardian': {
          'offsets': ['eve', 180],
        },
      });
      expect(
        find.textContaining('el domingo a las 20:00 y el lunes a las 14:00'),
        findsOneWidget,
      );
    });

    testWidgets('con 3 avisos no se pueden agregar más', (tester) async {
      await tester.pumpWidget(
        app({
          'GET /me/notification-settings': (_) =>
              settingsJson(instructor: null, guardianOffsets: ['eve', 180, 30]),
        }),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agregar aviso'), findsNothing);
      expect(
        find.text('Podés tener hasta 3 avisos por clase.'),
        findsOneWidget,
      );
    });

    testWidgets('el técnico apaga su aviso', (tester) async {
      final requests = <RequestOptions>[];
      await tester.pumpWidget(
        app({
          'GET /me/notification-settings': (_) => settingsJson(guardian: false),
          'PUT /me/notification-settings': (_) => settingsJson(
            guardian: false,
            instructor: const {
              'enabled': false,
              'offsets': [120],
            },
          ),
        }, requests: requests),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avisarme los días que doy clase'));
      await tester.pumpAndSettle();

      expect(requests.last.data, {
        'instructor': {
          'enabled': false,
          'offsets': [120],
        },
      });
      expect(find.text('2 h antes'), findsNothing);
    });

    testWidgets('el aviso por hijo usa el mismo interruptor que la ficha', (
      tester,
    ) async {
      final requests = <RequestOptions>[];
      final push = FakePushService();
      var enabled = false;
      await tester.pumpWidget(
        app(
          {
            'GET /me/notification-settings': (_) =>
                settingsJson(instructor: null, childEnabled: enabled),
            'PUT /students/12/reminders': (options) {
              enabled = (options.data as Map)['enabled'] as bool;
              return {
                'data': {'class_reminders': enabled},
              };
            },
          },
          requests: requests,
          push: push,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Agregar aviso'), findsNothing);
      await tester.tap(find.text('Mateo'));
      await tester.pumpAndSettle();

      expect(requests.firstWhere((r) => r.method == 'PUT').data, {
        'enabled': true,
      });
      expect(push.enabled, 1);
      expect(find.text('Agregar aviso'), findsOneWidget);
    });
  });
}
