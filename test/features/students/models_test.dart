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
    expect(student.groupsDescription(DateTime(2026, 9, 26)), 'Sub-10 · Fútbol');
    expect(student.guardians, isEmpty);
    expect(student.medical, isNull);
    expect(student.canViewMedical, isFalse);
  });

  test('en la lista, las vigentes primero y cuántas temporadas próximas', () {
    Map<String, Object?> enrollment(int id, String group, String startsOn) => {
      'id': id,
      'status': 'activo',
      'season': {
        'id': id,
        'name': 'T$id',
        'starts_on': startsOn,
        'ends_on': '2027-12-31',
      },
      'group': {
        'id': id,
        'name': group,
        'program': {'id': 1, 'name': 'Fútbol'},
      },
    };
    final today = DateTime(2026, 9, 26);
    final student = Student.fromJson({
      ...studentSummaryJson(),
      'enrollments': [
        enrollment(1, 'Sub-10', '2026-01-01'),
        enrollment(2, 'Sub-10', '2027-01-04'),
        enrollment(3, 'Sub-12', '2027-01-01'),
      ],
    });
    final upcomingOnly = Student.fromJson({
      ...studentSummaryJson(),
      'enrollments': [enrollment(3, 'Sub-12', '2027-01-01')],
    });

    expect(
      student.groupsDescription(today),
      'Sub-10 · Fútbol y 2 temporadas próximas',
    );
    expect(student.currentEnrollments(today).map((e) => e.id), [1]);
    expect(upcomingOnly.groupsDescription(today), 'Sub-12 · Fútbol');
  });
}
