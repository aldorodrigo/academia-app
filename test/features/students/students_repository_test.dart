import 'package:academia_app/features/students/data/models.dart';
import 'package:academia_app/features/students/data/students_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes.dart';
import 'student_json.dart';

void main() {
  InMemorySessionStorage storage() => InMemorySessionStorage()
    ..token = 't'
    ..organization = 'jakare';

  test('lista los hijos del usuario', () async {
    final requests = <RequestOptions>[];
    final repository = StudentsRepository(
      fakeDio({
        'GET /students': (_) => {
          'data': [
            studentSummaryJson(),
            studentSummaryJson(id: 13, firstName: 'Sofía', status: 'pendiente'),
          ],
        },
      }, requests: requests),
      storage(),
    );

    final students = await repository.list();

    expect(requests.single.path, '/students');
    expect(students.map((s) => s.fullName), ['Mateo Benítez', 'Sofía Benítez']);
    expect(students.last.enrollments.single.status, EnrollmentStatus.pending);
    expect(students.first.enrollments.single.group.program.name, 'Fútbol');
  });

  test('sin organización elegida no consulta la API', () async {
    final repository = StudentsRepository(
      fakeDio(const {}),
      InMemorySessionStorage()..token = 't',
    );

    expect(await repository.list(), isEmpty);
  });

  test('lee la ficha completa', () async {
    final repository = StudentsRepository(
      fakeDio({
        'GET /students/12': (_) => {'data': studentDetailJson()},
      }),
      storage(),
    );

    final student = await repository.find(12);

    expect(student.document, '6123456');
    expect(student.guardians.first.isMe, isTrue);
    expect(student.enrollments.single.status, EnrollmentStatus.scholarship);
    expect(student.enrollments.single.group.instructors, ['Carlos Gómez']);
    expect(student.medical!.bloodType, 'O+');
    expect(student.medical!.emergencyContactPhone, '0981 123 456');
    expect(student.medical!.fitUntil, DateTime(2027, 3, 1));
  });

  test('sin permiso la ficha médica no viene', () async {
    final repository = StudentsRepository(
      fakeDio({
        'GET /students/12': (_) => {
          'data': studentDetailJson(withMedical: false, canViewMedical: false),
        },
      }),
      storage(),
    );

    final student = await repository.find(12);

    expect(student.medical, isNull);
    expect(student.canViewMedical, isFalse);
  });

  test('un alumno ajeno responde 404', () async {
    final repository = StudentsRepository(
      fakeDio({
        'GET /students/99': (options) =>
            throw apiError(options, 404, {'message': 'No encontrado.'}),
      }),
      storage(),
    );

    expect(
      () => repository.find(99),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          404,
        ),
      ),
    );
  });
}
