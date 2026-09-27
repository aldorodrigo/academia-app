import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fecha de hoy; se reemplaza en los tests para que no dependan del día.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Fecha y hora actuales (para saber si una clase ya empezó); reemplazable en los tests.
final nowProvider = Provider<DateTime>((ref) => DateTime.now());
