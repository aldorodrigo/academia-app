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
