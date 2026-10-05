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

/// Nombre del mes en minúscula: 10 → "octubre".
String monthName(int month) => _months[(month - 1) % 12].toLowerCase();

/// Período mensual de la API: "2026-09" → "Septiembre 2026".
String formatPeriod(String period) {
  final parts = period.split('-');
  return '${_months[int.parse(parts[1]) - 1]} ${parts[0]}';
}

/// "16:00" → minutos desde las 0:00 (null si no es una hora válida).
int? minutesOf(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hours = int.tryParse(parts[0]);
  final minutes = int.tryParse(parts[1]);
  if (hours == null || minutes == null) return null;
  if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Minutos desde las 0:00 → "16:00".
String timeOf(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// "35.000" o "35000" → 35000 (null si no es un monto válido).
int? parseAmount(String text) {
  final digits = text.replaceAll(RegExp(r'[.\s₲]'), '');
  final value = int.tryParse(digits);
  return value == null || value <= 0 ? null : value;
}

/// Celular de la API (formato internacional) para mostrar:
/// "+595981123456" → "0981 123 456". Los de otros países, tal cual.
String formatPhone(String phone) {
  final match = RegExp(r'^\+595(\d{3})(\d{3})(\d{3})$').firstMatch(phone);
  if (match == null) return phone;
  return '0${match[1]} ${match[2]} ${match[3]}';
}
