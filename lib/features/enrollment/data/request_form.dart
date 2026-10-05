/// Validaciones de la solicitud de inscripción (las mismas reglas que la API).
library;

import '../../../core/vocabulary/vocabulary.dart';

String? validateChildFirstName(String? value) =>
    value == null || value.trim().isEmpty ? 'Ingresá el nombre.' : null;

String? validateChildLastName(String? value) =>
    value == null || value.trim().isEmpty ? 'Ingresá el apellido.' : null;

/// "02/07/2018" (o "2/7/2018") → fecha; `null` si no es una fecha real.
DateTime? parseDayMonthYear(String? text) {
  final match = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})$')
      .firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // DateTime(2018, 2, 31) pasa a marzo: no es una fecha real.
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Fecha de nacimiento escrita como dd/mm/aaaa: obligatoria, real y pasada.
String? validateBirthDate(String? text, DateTime today) {
  if (text == null || text.trim().isEmpty) {
    return 'Ingresá la fecha de nacimiento.';
  }
  final date = parseDayMonthYear(text);
  if (date == null) return 'Escribila como dd/mm/aaaa (ej. 02/07/2018).';
  if (!date.isBefore(today)) {
    return 'La fecha de nacimiento tiene que ser pasada.';
  }
  if (date.year < today.year - 100) return 'Revisá el año.';
  return null;
}

/// Documento obligatorio: hasta 20 caracteres, letras, números, puntos o guiones.
String? validateDocument(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Ingresá el número de documento.';
  if (text.length > 20 || !RegExp(r'^[\w.\-]+$').hasMatch(text)) {
    return 'Ingresá el número de documento, sin espacios.';
  }
  return null;
}

/// [group]: la palabra del club ("Elegí el grupo.").
String? validateGroup(int? groupId, [Word? group]) =>
    groupId == null ? 'Elegí ${(group ?? Word.of('Categoría')).the()}.' : null;

/// Motivo del rechazo, que le llega al tutor.
String? validateRequestRejection(String? value) =>
    value == null || value.trim().isEmpty
    ? 'Contale a la familia por qué no la aprobás.'
    : null;

/// [guardian]: la palabra del club ("Ingresá el nombre del encargado.").
/// [gender]: el del parentesco elegido ("Ingresá el nombre de la tutora").
String? validateGuardianName(String? value, [Word? guardian, Gender? gender]) =>
    value == null || value.trim().isEmpty
    ? 'Ingresá el nombre ${(guardian ?? Word.of('Tutor')).of(person: gender)}.'
    : null;
