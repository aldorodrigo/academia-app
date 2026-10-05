import 'package:academia_app/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 28); // lunes

  test('día relativo', () {
    expect(formatDay(DateTime(2026, 9, 28), today), 'hoy');
    expect(formatDay(DateTime(2026, 9, 29), today), 'mañana');
    expect(formatDay(DateTime(2026, 9, 27), today), 'ayer');
    expect(formatDay(DateTime(2026, 10, 1), today), 'el jueves 1/10');
    expect(formatDay(DateTime(2026, 10, 12), today), 'el 12/10');
  });

  test('día corto para listas', () {
    expect(formatShortDay(DateTime(2026, 9, 28), today), 'Hoy');
    expect(formatShortDay(DateTime(2026, 9, 24), today), 'Jue 24/9');
  });

  test('fechas para la API', () {
    expect(apiDate(DateTime(2026, 9, 5)), '2026-09-05');
    expect(apiMonth(DateTime(2026, 9, 5)), '2026-09');
  });

  test('cantidades en singular o plural', () {
    expect(countOf(1, 'familia', 'familias'), '1 familia');
    expect(countOf(0, 'justificado', 'justificados'), '0 justificados');
    expect(countOf(3, 'ausente', 'ausentes'), '3 ausentes');
  });

  test('"Temporada" no se repite', () {
    expect(seasonLabel('2026'), 'Temporada 2026');
    expect(seasonLabel('Temporada 2026'), 'Temporada 2026');
    expect(seasonLabel('temporada de verano'), 'temporada de verano');
  });
}
