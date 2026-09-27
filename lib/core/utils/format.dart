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
