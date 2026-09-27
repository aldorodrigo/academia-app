import 'package:academia_app/features/attendance/presentation/class_change_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 28, 10);

  test('se puede reprogramar a un día y hora futuros', () {
    expect(
      validateReschedule(
        date: DateTime(2026, 9, 28),
        startsAt: const TimeOfDay(hour: 18, minute: 0),
        endsAt: const TimeOfDay(hour: 19, minute: 30),
        now: now,
      ),
      isNull,
    );
  });

  test('el fin tiene que ser después del inicio', () {
    expect(
      validateReschedule(
        date: DateTime(2026, 10, 3),
        startsAt: const TimeOfDay(hour: 9, minute: 0),
        endsAt: const TimeOfDay(hour: 9, minute: 0),
        now: now,
      ),
      'La hora de fin tiene que ser después del inicio.',
    );
  });

  test('no se puede reprogramar al pasado', () {
    expect(
      validateReschedule(
        date: DateTime(2026, 9, 28),
        startsAt: const TimeOfDay(hour: 9, minute: 0),
        endsAt: const TimeOfDay(hour: 10, minute: 0),
        now: now,
      ),
      'Elegí un día y hora que todavía no pasó.',
    );
  });

  test('horas de la API', () {
    expect(formatTime(parseTime('09:05')), '09:05');
  });
}
