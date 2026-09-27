/// Fecha en formato dd/mm/aaaa.
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// Edad cumplida a la fecha [today].
int ageOn(DateTime birth, DateTime today) {
  final age = today.year - birth.year;
  final hadBirthday =
      today.month > birth.month ||
      (today.month == birth.month && today.day >= birth.day);
  return hadBirthday ? age : age - 1;
}

const _weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Día de la semana abreviado a partir del número ISO (1 = lunes).
String weekdayShort(int weekday) => _weekdays[(weekday - 1) % 7];

const _weekdaysLong = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Día de la semana completo, en minúscula: 1 → "lunes".
String weekdayLong(int weekday) => _weekdaysLong[(weekday - 1) % 7];

/// Día relativo a [today]: "hoy", "mañana", "el jueves 1/10" (esta semana)
/// o "el 12/10".
String formatDay(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'mañana';
  if (diff == -1) return 'ayer';
  final short = '${date.day}/${date.month}';
  return diff > 1 && diff < 7
      ? 'el ${weekdayLong(date.weekday)} $short'
      : 'el $short';
}

/// Día corto para listas: "Hoy", "Mañana", "Ayer" o "Jue 24/9".
String formatShortDay(DateTime date, DateTime today) {
  final relative = formatDay(date, today);
  if (!relative.startsWith('el ')) {
    return '${relative[0].toUpperCase()}${relative.substring(1)}';
  }
  return '${weekdayShort(date.weekday)} ${date.day}/${date.month}';
}

/// Fecha para la API: aaaa-mm-dd.
String apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Mes para la API: aaaa-mm.
String apiMonth(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

/// Guaraníes enteros con separador de miles: 150000 → "₲ 150.000".
String formatMoney(int amount) {
  final digits = amount.abs().toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
    grouped.write(digits[i]);
  }
  return '${amount < 0 ? '−' : ''}₲ $grouped';
}

const _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Período mensual de la API: "2026-09" → "Septiembre 2026".
String formatPeriod(String period) {
  final parts = period.split('-');
  return '${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
}
