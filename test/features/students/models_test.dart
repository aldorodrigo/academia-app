import 'package:academia_app/core/utils/format.dart';
import 'package:academia_app/features/students/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'student_json.dart';

void main() {
  test('estados de inscripción con sus etiquetas', () {
    expect(EnrollmentStatus.parse('activo'), EnrollmentStatus.active);
    expect(EnrollmentStatus.parse('becado').label, 'Becado');
    expect(EnrollmentStatus.parse('baja').isCurrent, isFalse);
    expect(EnrollmentStatus.parse('otro'), EnrollmentStatus.pending);
  });

  test('edad cumplida', () {
    final birth = DateTime(2016, 3, 14);
    expect(ageOn(birth, DateTime(2026, 3, 13)), 9);
    expect(ageOn(birth, DateTime(2026, 3, 14)), 10);
    expect(ageOn(birth, DateTime(2026, 12, 31)), 10);
  });

  test('horarios ordenados por día y con cancha', () {
    final student = Student.fromJson(studentDetailJson());
    final schedules = student.enrollments.single.group.schedules;

    expect(schedules.map((s) => s.description), [
      'Lun 17:00–18:30 · Cancha 1',
      'Mié 17:00–18:30',
    ]);
  });

  test('apto médico vencido', () {
    final medical = Student.fromJson(studentDetailJson()).medical!;

    expect(medical.isFitExpired(DateTime(2027, 3, 1)), isFalse);
    expect(medical.isFitExpired(DateTime(2027, 3, 2)), isTrue);
  });

  test('la lista trae solo los datos básicos', () {
    final student = Student.fromJson(studentSummaryJson());

    expect(student.initials, 'MB');
    expect(student.groupsDescription, 'Sub-10 · Fútbol');
    expect(student.guardians, isEmpty);
    expect(student.medical, isNull);
    expect(student.canViewMedical, isFalse);
  });
}
