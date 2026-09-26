import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fecha de hoy; se reemplaza en los tests para que no dependan del día.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});
